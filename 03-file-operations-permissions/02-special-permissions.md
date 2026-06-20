# Special Permissions

A deep-dive reference on Linux's special permission bits — setuid, setgid, and the sticky bit — what they do, why they exist, and how to use them safely.

---

## 🧩 Overview

Standard permissions (`rwx` for user/group/other) control *who* can read, write, or execute a file. Special permissions go further: they change **how** a program executes or **how** a directory behaves for the files inside it.

| Bit | Numeric | Symbolic | Applies to | Purpose |
|---|---|---|---|---|
| **setuid** | `4000` | `u+s` | Executable files | Run as the file's **owner**, not the user who runs it |
| **setgid** | `2000` | `g+s` | Executables & directories | Run as the file's **group**, or make new files inherit a directory's group |
| **sticky bit** | `1000` | `+t` | Directories | Restrict deletion to the file's owner, even in shared directories |

These three bits sit in a fourth octal digit, **before** the usual three:

```
chmod 4755 file    →  setuid + rwxr-xr-x
chmod 2775 dir/    →  setgid + rwxrwxr-x
chmod 1777 dir/    →  sticky + rwxrwxrwx
```

---

## 🔑 setuid — Set User ID

### What it does
When set on an **executable file**, setuid makes the program run with the **privileges of the file's owner**, instead of the privileges of the user who launched it.

### Why it's needed
Some tasks require elevated privileges that ordinary users shouldn't have directly — for example, changing your own password modifies a system file (`/etc/shadow`) that only root can normally write to. setuid lets a trusted program bridge that gap.

### Classic example: `passwd`

```bash
ls -l /usr/bin/passwd
# -rwsr-xr-x 1 root root 68208 ... /usr/bin/passwd
```

The `s` in the owner's execute position means: when *any* user runs `passwd`, the program temporarily runs as `root`, so it can update `/etc/shadow` — but only to change that user's own password, because the program's own logic restricts what it allows.

### Setting setuid

```bash
chmod u+s program          # symbolic
chmod 4755 program         # numeric (4000 + 755)
```

### Viewing it

```bash
ls -l program
# -rwsr-xr-x   ← lowercase 's' = setuid + execute both set
# -rwSr-xr-x   ← uppercase 'S' = setuid set, but execute NOT set (unusual/invalid combo)
```

> ⚠️ **Security warning:** setuid is powerful and dangerous. A setuid program owned by `root` runs with full root privileges for *anyone* who executes it. If that program has a bug — like spawning a shell or executing user-controlled input — any user can exploit it to gain root access. Only apply setuid to programs that are deliberately designed and audited for this (like `passwd`, `sudo`, `ping`). Never set it on scripts (shebang scripts largely ignore setuid on Linux for this exact reason) or on arbitrary binaries.

---

## 👥 setgid — Set Group ID

setgid behaves differently depending on whether it's applied to a **file** or a **directory**.

### On Executable Files
Same idea as setuid, but for the group: the program runs with the privileges of the file's **group**, not the user's own group.

```bash
chmod g+s program
chmod 2755 program
```

This is less commonly used than setuid but follows the same logic — useful when a program needs group-level access (e.g. to a shared resource) regardless of who runs it.

### On Directories (the common case)
When set on a **directory**, setgid changes file creation behavior: any new file or subdirectory created inside automatically **inherits the directory's group**, instead of the creating user's default group.

```bash
chmod g+s /shared/team-folder
chmod 2775 /shared/team-folder
```

```bash
ls -ld /shared/team-folder
# drwxrwsr-x 2 alice developers 4096 Jun 20 10:00 team-folder
```

The `s` in the group's execute position confirms setgid is active.

### Why it matters
Without setgid, if Alice (primary group `alice`) creates a file inside a directory owned by group `developers`, that new file gets group `alice` — locking other `developers` members out of write access. With setgid set on the directory, every new file automatically belongs to `developers`, keeping permissions consistent for the whole team.

> **This is the standard pattern for shared team directories** — combine setgid with group write access so a whole team can collaborate without manually fixing group ownership on every new file.

---

## 📌 Sticky Bit

### What it does
When set on a **directory**, the sticky bit restricts file deletion: only the file's **owner** (or root) can delete or rename files inside that directory — even if other users have write access to the directory itself.

### Why it's needed
Normally, write permission on a directory lets *any* user with that permission delete *any* file inside it — regardless of who owns the file. In a world-writable shared directory, that means anyone could delete anyone else's files. The sticky bit closes that gap.

### Classic example: `/tmp`

```bash
ls -ld /tmp
# drwxrwxrwt 10 root root 4096 Jun 20 10:00 /tmp
```

The `t` at the end means: `/tmp` is writable by everyone (so any user can create files there), but the sticky bit ensures users can only delete their *own* files — not each other's.

### Setting the sticky bit

```bash
chmod +t /shared/dropbox
chmod 1777 /shared/dropbox
```

### Viewing it

```bash
ls -ld /shared/dropbox
# drwxrwxrwt   ← lowercase 't' = sticky bit + execute both set
# drwxrwxrw-T  ← uppercase 'T' = sticky bit set, but execute NOT set (unusual/invalid combo)
```

---

## 🛠️ Combining setgid + Sticky Bit for Secure Shared Directories

A common real-world pattern for a secure collaborative directory combines **setgid** (consistent group ownership) with the **sticky bit** (protection from accidental/malicious deletion):

```bash
mkdir /shared/project
chgrp developers /shared/project
chmod 2775 /shared/project      # setgid + rwxrwxr-x
chmod +t /shared/project        # add sticky bit on top
# or combine directly:
chmod 3775 /shared/project      # setgid (2000) + sticky (1000) = 3000, + 775
```

```bash
ls -ld /shared/project
# drwxrwsr-t 2 root developers 4096 Jun 20 10:00 project
```

Result:
- Anyone in `developers` can create files in the directory.
- New files automatically belong to the `developers` group (setgid).
- Users can only delete their *own* files, not teammates' files (sticky bit).

---

## ⚡ Quick Reference

| Bit | Set Symbolically | Set Numerically | `ls -l` Indicator | Effect |
|---|---|---|---|---|
| setuid | `chmod u+s file` | `chmod 4755 file` | `s` in owner's `x` position | Runs as file's owner |
| setgid (file) | `chmod g+s file` | `chmod 2755 file` | `s` in group's `x` position | Runs as file's group |
| setgid (dir) | `chmod g+s dir/` | `chmod 2775 dir/` | `s` in group's `x` position | New files inherit dir's group |
| sticky bit | `chmod +t dir/` | `chmod 1777 dir/` | `t` in other's `x` position | Only owner can delete their files |

| Numeric Prefix | Bits Set |
|---|---|
| `4000` | setuid only |
| `2000` | setgid only |
| `1000` | sticky only |
| `3000` | setgid + sticky |
| `6000` | setuid + setgid |
| `7000` | setuid + setgid + sticky |

---

## 💡 Best Practices

- **Audit setuid/setgid binaries regularly** — find all of them on a system with:
  ```bash
  find / -perm /6000 -type f 2>/dev/null
  ```
  Unexpected setuid programs are a common sign of a compromised system.
- **Never set setuid on scripts.** Most Linux kernels ignore the setuid bit on shebang (`#!`) scripts for security reasons — use a compiled wrapper if elevated execution is genuinely required.
- **Use setgid on shared team directories** as the default pattern for collaborative file storage — it avoids constant manual `chgrp` fixes.
- **Use the sticky bit on any world-writable directory** — anywhere users can create files but shouldn't be able to delete each other's, the sticky bit is essential (this is why `/tmp` always has it).
- **Combine setgid + sticky bit** for directories that need both consistent group ownership and deletion protection — this is the standard secure pattern for shared project folders.
- **Avoid `chmod -R` with special bits** unless you're certain every file in the tree should carry them — recursive setuid/setgid on the wrong files can create serious security holes.