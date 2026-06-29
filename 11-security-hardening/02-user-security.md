# User Security

A practical reference for hardening user accounts on Linux — password policy and account lockout, SSH key management, and restricting `sudo`/shell access to limit the blast radius of a compromised account.

---

## 🔒 Password Policies and Account Locking

### Enforcing Password Complexity

PAM's `pam_pwquality` module (covered conceptually in the *Authentication and Passwords* guide) enforces minimum standards at the point a password is actually set:

```bash
sudo nano /etc/security/pwquality.conf
```

```ini
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
retry = 3
```

| Setting | Meaning |
|---|---|
| `minlen` | Minimum password length |
| `dcredit` | Require at least one digit (`-1` = require, positive number = optional credit toward length) |
| `ucredit` | Require at least one uppercase letter |
| `lcredit` | Require at least one lowercase letter |
| `ocredit` | Require at least one special/other character |
| `retry` | Number of attempts before failing the password-change prompt entirely |

```bash
sudo authselect current        # check which PAM profile is active, on systems using authselect (RHEL-family)
```

> **Note:** these PAM-enforced rules apply when a password is **set or changed** — they don't retroactively invalidate existing passwords that predate the policy. Pair complexity requirements with a maximum password age (below) to ensure non-compliant legacy passwords eventually get rotated.

### Password Aging

```bash
sudo chage -M 90 username        # max 90 days before a password must be changed
sudo chage -m 7 username           # min 7 days before it can be changed again (prevents rapid cycling to dodge history)
sudo chage -W 14 username            # warn 14 days before expiry
sudo chage -l username                 # view a user's current aging settings
```

See the *Authentication and Passwords* guide for the full breakdown of `chage` and the `/etc/shadow` fields it manages.

### Locking Out After Failed Login Attempts

`pam_faillock` (the modern replacement for the older `pam_tally2`) automatically locks an account after repeated failed authentication attempts — a critical defense against online brute-force/credential-guessing, distinct from the offline brute-force resistance discussed for disk encryption passphrases in the *Storage Encryption* guide.

```bash
sudo nano /etc/security/faillock.conf
```

```ini
deny = 5
unlock_time = 900
fail_interval = 900
```

| Setting | Meaning |
|---|---|
| `deny` | Number of failed attempts before locking the account |
| `unlock_time` | Seconds the account stays locked before automatically unlocking (`0` = requires manual unlock) |
| `fail_interval` | Time window in which failed attempts are counted toward the `deny` threshold |

### Checking and Manually Managing Lockouts

```bash
sudo faillock --user alice              # view alice's current failure count and lock status
sudo faillock --user alice --reset        # manually clear failures and unlock immediately
sudo faillock                                 # view ALL users' current lockout status at once
```

### Locking an Account Directly (Administrative Action)

Distinct from automatic lockout due to failed attempts — this is a deliberate admin action to disable login entirely, e.g. for an employee who's left, or an account under investigation:

```bash
sudo passwd -l username        # lock — prepends a "!" to the password hash, preventing password-based login
sudo passwd -u username          # unlock — reverses the above
sudo usermod -L username           # equivalent to passwd -l
sudo usermod -U username             # equivalent to passwd -u
```

> **Important caveat:** `passwd -l`/`usermod -L` blocks **password-based** login specifically — it does **not** block SSH key-based login if the account still has authorized keys configured (see below) or other authentication methods (see the *Authentication and Passwords* guide for how PAM mediates different auth types). For a genuinely complete lockout, also consider expiring the account entirely:

```bash
sudo chage -E 0 username        # set the account's expiration date to "already expired" — blocks ALL login methods
sudo usermod -e $(date -d "yesterday" +%Y-%m-%d) username    # equivalent, more explicit about intent
```

> **Tip:** For offboarding (an account that should never log in again, by any method), prefer `chage -E 0` or removing/disabling SSH keys explicitly, rather than relying on `passwd -l` alone — it's a common, dangerous gap to assume a "locked" account is fully blocked when SSH keys still work.

---

## 🔑 SSH Key Management

### Why Keys Are Preferred Over Passwords for SSH

SSH key-based authentication relies on possessing a private key file rather than knowing/guessing a shared secret — it's effectively immune to the online brute-force/credential-guessing attacks that `pam_faillock` defends against for password auth, since there's no password to guess at all. This is why `PasswordAuthentication no` (covered in the *Firewall Hardening* guide's SSH section) is a standard hardening recommendation once keys are properly set up.

### Generating a Key Pair

```bash
ssh-keygen -t ed25519 -C "alice@workstation"
```

```
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/alice/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
```

| Flag | Meaning |
|---|---|
| `-t ed25519` | Key type — Ed25519 is the current recommended default: strong, fast, short keys |
| `-t rsa -b 4096` | The traditional alternative — use if connecting to older systems lacking Ed25519 support |
| `-C` | A comment, typically identifying the key's purpose/owner — shown when the key is listed, not used cryptographically |

> **Always set a passphrase on the private key** unless you have a specific, deliberate reason not to (e.g. fully automated, non-interactive use with compensating controls). An unencrypted private key file is equivalent to a master password stored in plaintext — anyone who copies the file can use it immediately, with no additional barrier.

### Installing a Public Key for Authentication

```bash
ssh-copy-id alice@remote-host                          # the easy way — copies your public key over automatically
cat ~/.ssh/id_ed25519.pub | ssh alice@remote-host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"   # manual equivalent
```

```bash
chmod 700 ~/.ssh                       # the .ssh directory itself must be private
chmod 600 ~/.ssh/authorized_keys         # and the authorized_keys file specifically
```

> **Note:** SSH is deliberately strict about permissions on `~/.ssh` and its contents — if these are too permissive, `sshd` will silently refuse to use them, which is a common source of "why isn't my key working" confusion. See the *Permissions and Modes* guide for the underlying `chmod` mechanics.

### Managing Multiple Authorized Keys

`~/.ssh/authorized_keys` can contain multiple keys, one per line — useful for one person with multiple devices, or (less ideally, see below) multiple people sharing one account:

```
ssh-ed25519 AAAA...key1... alice@laptop
ssh-ed25519 AAAA...key2... alice@workstation
```

> **Best practice:** prefer one account per person, each with their own key(s), over multiple people sharing a single account's `authorized_keys` — shared accounts destroy the per-user accountability that's one of the core arguments for `sudo` over shared root (see the *sudo and Privilege Management* guide) for exactly the same underlying reason.

### Revoking Access

Removing a key is as simple as deleting its line from `authorized_keys` — there's no separate "revocation" mechanism needed for basic cases, since the key only grants access by being present in that file:

```bash
sudo nano /home/alice/.ssh/authorized_keys    # remove the specific line for the device/key being revoked
```

For centrally-managed environments with many hosts, consider a configuration management tool or centralized `authorized_keys` distribution (e.g. via LDAP, or a tool like Ansible) rather than manually editing files on every host individually — manual per-host editing doesn't scale and is easy to miss a host during revocation.

### Restricting What a Specific Key Can Do

`authorized_keys` supports per-key restrictions, useful for limited-purpose keys (e.g. an automated backup script that only needs to run one specific command):

```
command="/opt/scripts/backup-receiver.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
```

| Restriction | Effect |
|---|---|
| `command="..."` | Forces this key to ONLY run the specified command, ignoring whatever the client requests |
| `no-port-forwarding` | Disables SSH port forwarding for this key |
| `no-X11-forwarding` | Disables X11 forwarding for this key |
| `no-agent-forwarding` | Disables SSH agent forwarding for this key |
| `from="IP/CIDR"` | Restricts this key to connections originating from specific source(s) |

> **Tip:** This is directly analogous to scoping `sudo` access to a specific command rather than full root (see the *sudo and Privilege Management* guide) — apply the same least-privilege thinking to SSH keys used for automation as you would to any other credential.

---

## 🛡️ Restricting `sudo` and Shell Access

### Scoping `sudo`, Revisited

The *sudo and Privilege Management* guide covers `/etc/sudoers` syntax in depth — the security-focused summary here: **default to no `sudo` access at all**, and grant the narrowest scope that accomplishes the actual need, rather than defaulting new accounts to broad admin rights "to be safe" or "in case they need it."

```bash
# A new account, deliberately WITHOUT broad sudo by default:
sudo useradd -m -s /bin/bash newuser
# NOT automatically added to the sudo/wheel group

# Only when a specific, justified need exists:
sudo usermod -aG sudo newuser              # Debian/Ubuntu wheel-equivalent group
# or a scoped sudoers rule for one specific command, per the sudo guide
```

### Restricting Shell Access Entirely

For accounts that need to exist (e.g. for file ownership, running a specific service) but should **never** provide an interactive login at all:

```bash
sudo usermod -s /usr/sbin/nologin serviceaccount
sudo usermod -s /bin/false serviceaccount       # equivalent in effect, slightly less informative messaging
```

See the *User Account Basics* guide for the full rationale behind `nologin`/`/bin/false` and why service accounts shouldn't have a normal interactive shell at all.

### Restricting Accounts to Specific Commands Only

For accounts that need *some* shell-like access but shouldn't have a general-purpose shell — e.g. an SFTP-only file transfer account, or a tightly scoped support account:

```bash
sudo usermod -s /sbin/rbash limiteduser    # "restricted bash" — disables cd, setting PATH, and several other escape vectors
```

> ⚠️ **Caution:** `rbash` and similar restricted shells are a relatively weak control on their own — there are well-documented techniques to escape a restricted shell if the user also has access to other programs (text editors, scripting languages) that can spawn an unrestricted shell. Treat restricted shells as one layer in a broader defense-in-depth approach (see the *Linux Security Principles* guide), not a complete containment guarantee by themselves.

### SFTP-Only Access (A More Robust Restriction)

For the common specific case of "this account should only transfer files, never get a shell," SSH's built-in `ForceCommand` with the internal SFTP subsystem is more robust than a restricted shell:

```
# /etc/ssh/sshd_config
Match User sftpuser
    ForceCommand internal-sftp
    ChrootDirectory /home/sftpuser
    AllowTcpForwarding no
    X11Forwarding no
```

```bash
sudo systemctl restart sshd
```

This confines the user to SFTP file operations within a chrooted directory, with no general command execution available at all — a substantially stronger guarantee than a restricted shell.

### Auditing Who Has Elevated Access

```bash
getent group sudo          # Debian/Ubuntu — who's in the sudo group?
getent group wheel           # RHEL/Fedora — who's in the wheel group?
sudo grep -E '^[^#]' /etc/sudoers /etc/sudoers.d/*    # review explicit sudoers rules directly
```

```bash
sudo journalctl _COMM=sudo --since "7 days ago"     # review recent sudo usage (see the Logs and journald guide)
```

> **Tip:** Periodically auditing group membership and sudoers rules — not just when initially granted — catches privilege that's accumulated or been forgotten over time. This is the same "baseline drift" concern raised in the *Linux Security Principles* guide, applied specifically to privilege escalation paths.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Set password complexity rules | edit `/etc/security/pwquality.conf` |
| Set password max/min age | `sudo chage -M 90 / -m 7 username` |
| Configure lockout after failed attempts | edit `/etc/security/faillock.conf` |
| Check/reset a user's lockout status | `sudo faillock --user username [--reset]` |
| Lock an account (password auth only) | `sudo passwd -l username` |
| Fully expire/disable an account | `sudo chage -E 0 username` |
| Generate an SSH key pair | `ssh-keygen -t ed25519 -C "comment"` |
| Install a public key for login | `ssh-copy-id user@host` |
| Restrict a specific authorized key | edit `~/.ssh/authorized_keys` with `command=`, `from=`, etc. |
| Grant scoped sudo access | edit `/etc/sudoers.d/` (see the sudo guide) |
| Block interactive shell entirely | `sudo usermod -s /usr/sbin/nologin username` |
| Restrict to SFTP only | `ForceCommand internal-sftp` in `sshd_config` |
| Audit elevated-access group membership | `getent group sudo` (or `wheel`) |

---

## 💡 Best Practices

- Pair password complexity rules (`pwquality`) with maximum password age (`chage -M`) — complexity rules alone don't retroactively fix existing weak/old passwords.
- Use `pam_faillock` to defend against online brute-force attempts — this is a different threat model from the offline brute-force resistance covered for disk encryption in the *Storage Encryption* guide, and needs its own dedicated control.
- Remember `passwd -l` only blocks password authentication — for genuine, complete offboarding, also expire the account (`chage -E 0`) and remove/revoke any SSH keys.
- Always set a passphrase on SSH private keys, and prefer key-based authentication with `PasswordAuthentication no` once keys are properly distributed.
- Apply least-privilege thinking to SSH keys themselves, not just to user/sudo permissions — scope automation keys with `command=` and `from=` restrictions in `authorized_keys`.
- Default new accounts to no `sudo` access; grant it deliberately and as narrowly as the actual need requires, per the *sudo and Privilege Management* guide.
- Prefer SSH's `ForceCommand internal-sftp` over a restricted shell (`rbash`) for genuine file-transfer-only access — restricted shells have well-known escape techniques and shouldn't be relied on as a sole control.
- Periodically audit `sudo`/`wheel` group membership and sudoers rules — privilege tends to accumulate quietly over time without active review.