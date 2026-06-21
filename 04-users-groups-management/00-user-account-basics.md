# User Account Basics

A reference guide to how Linux user accounts work — where they're defined, how they're created and removed, and what role UIDs, GIDs, home directories, and login shells play.

---

## 🧾 `/etc/passwd` — The User Database

Every user account on a Linux system is recorded as a single line in `/etc/passwd`. Despite the name, it does **not** store actual passwords (that's `/etc/shadow` — see below).

```bash
cat /etc/passwd
# alice:x:1001:1001:Alice Smith,,,:/home/alice:/bin/bash
```

Each line has **7 colon-separated fields**:

```
alice : x : 1001 : 1001 : Alice Smith,,, : /home/alice : /bin/bash
  │     │     │      │          │              │              │
  │     │     │      │          │              │              └── login shell
  │     │     │      │          │              └── home directory
  │     │     │      │          └── GECOS field (full name / contact info)
  │     │     │      └── GID (primary group ID)
  │     │     └── UID (user ID)
  │     └── password placeholder ("x" = stored in /etc/shadow)
  └── username
```

| Field | Name | Meaning |
|---|---|---|
| 1 | Username | Login name |
| 2 | Password | Always `x` on modern systems — real hash lives in `/etc/shadow` |
| 3 | UID | Numeric user ID |
| 4 | GID | Numeric ID of the user's **primary** group |
| 5 | GECOS | Comment field — usually full name, sometimes phone/room info |
| 6 | Home directory | Path to the user's home, e.g. `/home/alice` |
| 7 | Login shell | Program launched on login, e.g. `/bin/bash` |

### UID Ranges

| Range | Typically used for |
|---|---|
| `0` | Always reserved for `root` |
| `1`–`999` (or `1`–`499` on older systems) | System/service accounts (e.g. `www-data`, `sshd`) |
| `1000+` (or `500+`) | Regular human user accounts |

```bash
id alice
# uid=1001(alice) gid=1001(alice) groups=1001(alice),27(sudo),1002(developers)
```

---

## 🔒 `/etc/shadow` — Password & Aging Data

Actual password hashes and password-aging policy live in `/etc/shadow`, which is readable only by root for security.

```bash
sudo cat /etc/shadow
# alice:$6$rounds=...hash...:19500:0:90:7:::
```

Fields (colon-separated):

```
alice : $6$...hash... : 19500 : 0 : 90 : 7 : : :
  │          │             │     │   │   │  │ │
  │          │             │     │   │   │  │ └── account expiration date
  │          │             │     │   │   │  └── inactivity period before lock
  │          │             │     │   │   └── warning days before expiry
  │          │             │     │   └── max days password is valid
  │          │             │     └── min days before password can be changed again
  │          │             └── date of last password change (days since Jan 1, 1970)
  │          └── encrypted password hash (or !, * for locked/disabled accounts)
  └── username
```

> **Note:** A `!` or `*` in the password field means the account has **no valid password** — typically used for system accounts that shouldn't allow direct password login at all.

---

## 🐚 Login Shells

The login shell (last field in `/etc/passwd`) is the program that starts when the user logs in — usually a command interpreter like `bash`, but it doesn't have to be.

### Common Shells

```bash
cat /etc/shells
# /bin/sh
# /bin/bash
# /bin/zsh
# /usr/bin/fish
```

| Shell | Notes |
|---|---|
| `/bin/bash` | Most common default on Linux distributions |
| `/bin/sh` | POSIX-compliant shell, often a symlink to `bash` or `dash` |
| `/bin/zsh` | Popular alternative with richer interactive features |
| `/usr/sbin/nologin` | Blocks interactive login entirely — used for service accounts |
| `/bin/false` | Also blocks login — any login attempt simply exits immediately |

### Checking and Changing Your Shell

```bash
echo $SHELL              # currently active shell
chsh -l                  # list valid shells (or cat /etc/shells)
chsh -s /bin/zsh          # change your own login shell
sudo chsh -s /bin/zsh alice   # change another user's shell (requires root)
```

> **Why service accounts get `/usr/sbin/nologin`:** A service account (like `www-data`, used by a web server) needs a UID to own files and run processes, but should never be used for an interactive login. Setting its shell to `nologin` blocks anyone from logging in as that account via SSH or `su`, while it still functions normally for the service itself.

---

## ➕ Creating Users: `useradd`

### Basic Usage

```bash
sudo useradd alice
```

⚠️ By default, plain `useradd` on many distributions does **not** create a home directory or set a password — always check flags.

### Common Flags

```bash
sudo useradd -m -s /bin/bash -c "Alice Smith" alice
```

| Flag | Meaning |
|---|---|
| `-m` | Create the home directory (e.g. `/home/alice`) |
| `-d /path` | Specify a custom home directory path |
| `-s /bin/bash` | Set the login shell |
| `-c "Full Name"` | Set the GECOS comment field |
| `-g groupname` | Set the primary group |
| `-G group1,group2` | Add to additional (supplementary) groups |
| `-u 1050` | Specify a custom UID |
| `-e YYYY-MM-DD` | Set an account expiration date |

### Full Example

```bash
sudo useradd -m -s /bin/bash -c "Alice Smith" -G developers,sudo alice
sudo passwd alice    # set the password (prompts interactively)
```

> **Tip:** `adduser` (on Debian/Ubuntu) is a friendlier, interactive wrapper around `useradd` that walks you through each field and creates the home directory automatically. `useradd` is the lower-level, more universal command available across distributions.

---

## ➖ Deleting Users: `userdel`

### Basic Usage

```bash
sudo userdel alice
```

This removes the user's entry from `/etc/passwd` and `/etc/shadow`, but **leaves the home directory and mail spool intact** by default.

### Removing the Home Directory Too

```bash
sudo userdel -r alice
```

The `-r` flag also deletes the user's home directory and mail spool.

> ⚠️ **Caution:** `userdel -r` permanently deletes the user's home directory and everything in it. If the account owns files elsewhere on the system (outside the home directory), those files aren't removed — they become orphaned, owned by a now-nonexistent UID. Use `find / -nouser` afterward to locate them.

### Checking for Orphaned Files After Deletion

```bash
find / -nouser -o -nogroup 2>/dev/null
```

---

## ✏️ Modifying Existing Users: `usermod`

Not in the original scope, but essential alongside `useradd`/`userdel` for managing accounts day-to-day:

```bash
sudo usermod -aG developers alice   # add alice to the developers group (note: -aG, not -G, to avoid removing existing groups)
sudo usermod -s /bin/zsh alice      # change login shell
sudo usermod -l newname alice       # rename the login (username)
sudo usermod -L alice               # lock the account (disable password login)
sudo usermod -U alice               # unlock the account
```

> ⚠️ **Common mistake:** `usermod -G developers alice` (without `-a`) **replaces** alice's entire supplementary group list with just `developers`, removing her from every other group. Always use `-aG` ("append, then set Groups") when adding to a group, unless you genuinely intend to overwrite the whole list.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View all users | `cat /etc/passwd` |
| View a specific user's UID/GID/groups | `id username` |
| View your own identity | `id`, `whoami` |
| View password aging policy | `sudo cat /etc/shadow` |
| List valid shells | `cat /etc/shells` |
| Check current shell | `echo $SHELL` |
| Change your shell | `chsh -s /bin/zsh` |
| Create a user (with home dir) | `sudo useradd -m -s /bin/bash username` |
| Set/change a password | `sudo passwd username` |
| Add user to a group (safely) | `sudo usermod -aG groupname username` |
| Delete a user (keep home dir) | `sudo userdel username` |
| Delete a user and home dir | `sudo userdel -r username` |
| Find orphaned files after deletion | `find / -nouser -o -nogroup` |

---

## 💡 Best Practices

- Always use `-m` with `useradd` unless you specifically don't want a home directory created.
- Set an explicit shell (`-s`) when creating service accounts — use `/usr/sbin/nologin` rather than leaving it to default.
- Use `usermod -aG` (append) instead of `usermod -G` (overwrite) when adding someone to a group — the missing `-a` is one of the most common Linux sysadmin mistakes.
- Run `find / -nouser -o -nogroup` after deleting a user to catch orphaned files left outside their home directory.
- Never edit `/etc/passwd` or `/etc/shadow` directly with a text editor — use `vipw` and `vipw -s` if manual editing is truly necessary, since they lock the files and validate syntax on save.
- Reserve UIDs below 1000 for system accounts; let regular human users start at 1000+ to avoid ID collisions with system services.