# Authentication and Passwords

A reference guide to how Linux authenticates users — password storage and hashing, password aging policy with `chage`, and the Pluggable Authentication Modules (PAM) framework that ties it all together.

---

## 🔒 `/etc/shadow` — Secure Password Storage

Password hashes are never stored in `/etc/passwd` (which is world-readable). Instead, they live in `/etc/shadow`, readable only by root.

```bash
sudo cat /etc/shadow
# alice:$6$rounds=656000$abc123...:19500:0:90:7:14:19700:
```

### Field Breakdown

```
alice : $6$rounds=656000$abc123... : 19500 : 0 : 90 : 7 : 14 : 19700 :
  │              │                     │     │   │   │   │     │     │
  │              │                     │     │   │   │   │     │     └── account expiration date
  │              │                     │     │   │   │   │     └── inactivity period before lock
  │              │                     │     │   │   │   └── warning days before expiry
  │              │                     │     │   │   └── max days password is valid
  │              │                     │     │   └── min days before password can be changed
  │              │                     │     └── date of last password change (days since epoch)
  │              │                     └── (see above)
  │              └── encrypted password hash
  └── username
```

| Field | Meaning |
|---|---|
| 1 | Username |
| 2 | Encrypted password hash (format explained below) |
| 3 | Date of last password change (days since Jan 1, 1970) |
| 4 | Minimum days before the password can be changed again |
| 5 | Maximum days the password is valid before requiring a change |
| 6 | Warning period (days) before expiry that the user is notified |
| 7 | Inactivity period (days) after expiry before the account is locked |
| 8 | Account expiration date (days since epoch) |
| 9 | Reserved (unused) |

### Special Password Field Values

| Value | Meaning |
|---|---|
| `$6$...` (or `$y$`, `$2b$`, etc.) | A valid hash — see hashing formats below |
| `!` or `!!` | Account is **locked** — no password will match |
| `*` | Account **cannot log in via password** at all (common for system accounts) |
| *(empty)* | **No password required** — a serious security risk if unintentional |

---

## 🔐 Password Hashing

Linux never stores passwords in plaintext or with simple, unsalted hashes. The hash field follows a structured format:

```
$id$salt$hash
```

```
$6$rounds=656000$abc123xyz...$longhashstring...
 │      │              │
 │      │              └── the resulting hash
 │      └── random salt (prevents identical passwords from producing identical hashes)
 └── algorithm identifier
```

### Common Algorithm IDs

| ID | Algorithm | Notes |
|---|---|---|
| `$1$` | MD5 | Legacy, weak — avoid on modern systems |
| `$2a$` / `$2b$` | bcrypt | Strong, adjustable work factor |
| `$5$` | SHA-256 | Common default on many distros |
| `$6$` | SHA-512 | Current default on most modern Linux distributions |
| `$y$` | yescrypt | Newer default on recent distros (e.g. current Debian/Ubuntu/Fedora) — more resistant to GPU-based cracking |

### Why Salting Matters

The **salt** is random data mixed into the password before hashing. Without it, two users with the same password would produce identical hashes — making precomputed "rainbow table" attacks trivial. With a unique salt per password, each hash is unique even for identical passwords, and precomputed tables become useless.

### Setting Passwords

```bash
sudo passwd alice          # interactively prompt and set alice's password
passwd                     # change your own password (no sudo needed)
echo "alice:NewPass123" | sudo chpasswd   # set non-interactively (use cautiously — visible in shell history/process list)
```

> ⚠️ **Caution:** Avoid putting plaintext passwords directly in commands or scripts — they can be captured in shell history, process listings (`ps aux`), or logs. Prefer interactive `passwd` whenever possible.

---

## 📅 Password Aging with `chage`

`chage` ("change age") manages the password-aging fields in `/etc/shadow` without needing to edit it directly.

### Viewing Current Policy

```bash
chage -l alice
```

```
Last password change                    : Jun 15, 2026
Password expires                        : Sep 13, 2026
Password inactive                       : Sep 27, 2026
Account expires                         : never
Minimum number of days between changes  : 0
Maximum number of days between changes  : 90
Number of days of warning before expiry : 7
```

### Setting Policy

```bash
sudo chage -M 90 alice     # max 90 days before password must change
sudo chage -m 7 alice      # min 7 days before it can be changed again
sudo chage -W 14 alice     # warn 14 days before expiry
sudo chage -I 30 alice     # lock account 30 days after expiry if unchanged
sudo chage -E 2026-12-31 alice    # set an account expiration date
sudo chage -E -1 alice     # remove an account expiration date
```

| Flag | Meaning |
|---|---|
| `-l` | List current aging settings for a user |
| `-M` | Maximum days password is valid |
| `-m` | Minimum days before password can be changed again |
| `-W` | Warning days before expiry |
| `-I` | Inactive days after expiry before the account locks |
| `-E` | Account expiration date (`YYYY-MM-DD`, or `-1` to remove) |
| `-d` | Manually set the "last changed" date |

### Forcing an Immediate Password Change

A common pattern when provisioning a new account: force the user to set their own password on first login.

```bash
sudo chage -d 0 alice
```

Setting the last-changed date to `0` immediately expires the current password, prompting a forced change at next login.

---

## 🧱 PAM — Pluggable Authentication Modules

### What PAM Is

PAM is a framework that decouples **applications** (login, sudo, sshd, su) from the **authentication logic** itself. Instead of each program implementing its own password-checking, fingerprint-checking, or token-checking code, they all call into PAM, which runs a configurable stack of modules to decide whether to allow access.

This is why you can add things like two-factor authentication, account lockout after failed attempts, or LDAP-based login to a Linux system **without modifying any application** — you just reconfigure PAM.

### Where PAM Configuration Lives

```bash
ls /etc/pam.d/
# login  sudo  sshd  su  common-auth  common-password  ...
```

Each service (e.g. `sshd`, `sudo`) has its own config file, often including shared files like `common-auth` for consistency across services.

### The Four Module Types

| Type | Purpose |
|---|---|
| `auth` | Verifies identity (e.g. checks the password) |
| `account` | Checks account validity (expired? locked? allowed at this time?) |
| `password` | Handles updating credentials (e.g. password change rules) |
| `session` | Sets up/tears down the session (e.g. mounting home dir, logging) |

### Anatomy of a PAM Rule

```
auth    required    pam_unix.so
```

```
type   control   module                arguments
auth   required  pam_unix.so
```

| Control Flag | Behavior |
|---|---|
| `required` | Must succeed; on failure, continues processing the stack but the overall result will be failure |
| `requisite` | Must succeed; on failure, **immediately** stops the whole stack |
| `sufficient` | If it succeeds (and no prior `required` module failed), authentication succeeds immediately |
| `optional` | Result mostly ignored unless it's the only module of its type |

### Common Modules

| Module | Purpose |
|---|---|
| `pam_unix.so` | Standard Unix password authentication via `/etc/shadow` |
| `pam_tally2.so` / `pam_faillock.so` | Lock accounts after repeated failed login attempts |
| `pam_cracklib.so` / `pam_pwquality.so` | Enforce password strength rules |
| `pam_google_authenticator.so` | Add TOTP-based two-factor authentication |
| `pam_ldap.so` | Authenticate against an LDAP directory |
| `pam_limits.so` | Enforce resource limits (file descriptors, processes) per session |

### Example: Enforcing Password Complexity

A line in `/etc/pam.d/common-password` might look like:

```
password requisite pam_pwquality.so retry=3 minlen=12 ucredit=-1 lcredit=-1 dcredit=-1
```

This requires passwords to be at least 12 characters, include at least one uppercase letter, one lowercase letter, and one digit — enforced at the PAM layer, before `chage`'s expiration rules even come into play.

> ⚠️ **Caution:** PAM configuration errors can lock you out of a system entirely, including via `sudo` and even root login. Always keep a second root shell open (or console/recovery access) while editing PAM files, and test changes in a non-critical session before closing your existing one.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View password aging info | `chage -l username` |
| Set max password age | `sudo chage -M days username` |
| Set min days between changes | `sudo chage -m days username` |
| Force password change at next login | `sudo chage -d 0 username` |
| Set account expiration date | `sudo chage -E YYYY-MM-DD username` |
| Change a password | `passwd` (self) or `sudo passwd username` |
| Lock an account | `sudo passwd -l username` or `sudo usermod -L username` |
| Unlock an account | `sudo passwd -u username` or `sudo usermod -U username` |
| View raw shadow entry | `sudo cat /etc/shadow` (or `grep username /etc/shadow`) |
| View PAM config for a service | `cat /etc/pam.d/sshd` (or relevant service) |

---

## 💡 Best Practices

- Never store or transmit passwords in plaintext — always rely on the system's hashing (`$6$`, `$y$`) rather than custom schemes.
- Use `chage -M` and `-W` together so users get adequate warning before a forced password expiration, rather than being locked out unexpectedly.
- Use `chage -d 0` when provisioning new accounts so users set their own password on first login instead of keeping an admin-chosen default.
- Prefer `usermod -L` / `-U` or `passwd -l` / `-u` for locking and unlocking accounts rather than manually editing `/etc/shadow`.
- When editing PAM configuration, keep a second authenticated session open until you've verified the change works — a misconfigured `auth` stack can lock out everyone, including root.
- Layer defenses: use PAM modules like `pam_faillock` for failed-login lockout and `pam_pwquality` for strength rules, rather than relying on password aging (`chage`) alone.
- Periodically audit `/etc/shadow` for accounts with empty password fields or unexpectedly unlocked status — both indicate a security misconfiguration.