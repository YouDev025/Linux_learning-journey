# Permissions and Modes

A complete reference for understanding Linux file permissions — how to read them, how to change them, and what each access bit actually controls.

---

## 🔎 Reading Permissions with `ls -l`

Running `ls -l` shows a permissions string at the start of each line:

```bash
ls -l
# -rwxr-xr-- 1 user group 4096 Jun 20 10:00 script.sh
```

That string breaks down into **four parts**:

```
-   rwx   r-x   r--
│    │     │     │
│    │     │     └── Other permissions
│    │     └──────── Group permissions
│    └────────────── User (owner) permissions
└─────────────────── File type
```

### File Type (1st character)

| Symbol | Meaning |
|---|---|
| `-` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |
| `c` | Character device |
| `b` | Block device |
| `p` | Named pipe (FIFO) |
| `s` | Socket |

### Permission Groups (next 9 characters)

The remaining 9 characters split into **three sets of three**, each representing **read (r)**, **write (w)**, and **execute (x)**:

| Positions | Applies to |
|---|---|
| 2–4 | **User** (the file's owner) |
| 5–7 | **Group** (the file's group) |
| 8–10 | **Other** (everyone else) |

A `-` in any position means that permission is **not granted**.

**Example:** `rwxr-xr--`
- `rwx` → owner can read, write, and execute
- `r-x` → group can read and execute, but not write
- `r--` → others can only read

---

## 📖 Permission Semantics

What read, write, and execute actually *do* differs slightly between files and directories.

### On Files

| Permission | Meaning |
|---|---|
| `r` (read) | Open and view the file's contents |
| `w` (write) | Modify or overwrite the file's contents |
| `x` (execute) | Run the file as a program or script |

### On Directories

| Permission | Meaning |
|---|---|
| `r` (read) | List the directory's contents (`ls`) |
| `w` (write) | Create, delete, or rename files inside the directory |
| `x` (execute) | Enter the directory (`cd`) and access files inside it |

> **Key insight:** Without execute (`x`) on a directory, you can't `cd` into it or access files inside — even if you have read access. And without write (`w`), you can't delete a file from that directory, *even if you own the file itself*. Directory permissions govern what happens to the listing; file permissions govern what happens to the file's content.

---

## 🔢 Numeric (Octal) Mode

Each permission has a numeric value. Add them together to represent a full set:

| Value | Permission | Symbol |
|---|---|---|
| `4` | Read | `r` |
| `2` | Write | `w` |
| `1` | Execute | `x` |
| `0` | None | `-` |

Sum the values for each of user/group/other to get a 3-digit mode:

| Combination | Sum | Symbolic |
|---|---|---|
| read + write + execute | `4+2+1=7` | `rwx` |
| read + write | `4+2=6` | `rw-` |
| read + execute | `4+1=5` | `r-x` |
| read only | `4` | `r--` |
| write + execute | `2+1=3` | `-wx` |
| execute only | `1` | `--x` |
| none | `0` | `---` |

### Common Modes

| Mode | Meaning | Typical Use |
|---|---|---|
| `755` | owner: rwx, group: r-x, other: r-x | Executable scripts, public directories |
| `644` | owner: rw-, group: r--, other: r-- | Regular files (no execute needed) |
| `700` | owner: rwx, group: ---, other: --- | Private scripts/directories |
| `600` | owner: rw-, group: ---, other: --- | Private files (e.g. SSH keys) |
| `777` | everyone: rwx | ⚠️ Full access for all — avoid unless required |
| `666` | everyone: rw- | ⚠️ Writable by all, not executable |

```bash
chmod 755 script.sh
chmod 644 notes.txt
chmod 600 ~/.ssh/id_rsa
```

---

## 🔤 Symbolic Mode

Symbolic mode lets you adjust permissions **relative to their current state**, without needing to know the full numeric value.

### Syntax

```
chmod [who][operator][permission] file
```

| Who | Meaning |
|---|---|
| `u` | User (owner) |
| `g` | Group |
| `o` | Other |
| `a` | All (user + group + other) |

| Operator | Meaning |
|---|---|
| `+` | Add a permission |
| `-` | Remove a permission |
| `=` | Set exactly (overwrites existing) |

### Examples

```bash
chmod u+x script.sh          # add execute for owner
chmod g-w file.txt           # remove write for group
chmod o=r file.txt           # set "other" to read-only exactly
chmod a+r file.txt           # add read for everyone
chmod u+rwx,g+rx,o-rwx file.txt   # combine multiple targets in one command
chmod +x script.sh           # shorthand: adds execute for all (when "who" omitted)
```

> **Tip:** Symbolic mode is great for *small adjustments* ("just add execute"). Numeric mode is faster when you want to set the *entire* permission set at once and already know the target value.

---

## 🌳 Recursive Changes

Apply permissions to a directory and everything inside it with `-R`:

```bash
chmod -R 755 project/        # apply to all files and subdirectories
chmod -R u+x scripts/        # add execute for owner, recursively
```

> ⚠️ **Caution:** Be careful with recursive numeric modes — `chmod -R 755` applied to a directory full of files will also make every *file* executable, which usually isn't desired. A common pattern is to set directories and files separately:
```bash
find project/ -type d -exec chmod 755 {} \;   # directories: rwxr-xr-x
find project/ -type f -exec chmod 644 {} \;   # files: rw-r--r--
```

---

## 🧩 Special Permission Bits

Beyond the standard `rwx`, three special bits modify behavior further:

| Bit | Numeric | Symbolic | Effect |
|---|---|---|---|
| **setuid** | `4000` | `u+s` | Executable runs with the **owner's** privileges, not the runner's |
| **setgid** | `2000` | `g+s` | On directories: new files inherit the directory's group |
| **sticky bit** | `1000` | `+t` | Only the file's owner (or root) can delete it, even if others have write access to the directory |

```bash
chmod 4755 program        # setuid + 755
chmod 2775 shared-folder/  # setgid + 775
chmod 1777 /tmp            # sticky bit, common on shared temp directories
```

When set, these appear in `ls -l` as a letter replacing the execute bit:

```
-rwsr-xr-x   → setuid (s in owner's execute position)
drwxrwsr-x   → setgid (s in group's execute position)
drwxrwxrwt   → sticky bit (t in other's execute position)
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View permissions | `ls -l` |
| Set exact numeric mode | `chmod 755 file` |
| Add a permission symbolically | `chmod u+x file` |
| Remove a permission symbolically | `chmod g-w file` |
| Set permission exactly (symbolic) | `chmod o=r file` |
| Apply recursively | `chmod -R 755 folder/` |
| Set setuid | `chmod u+s file` or `chmod 4755 file` |
| Set setgid | `chmod g+s dir/` or `chmod 2775 dir/` |
| Set sticky bit | `chmod +t dir/` or `chmod 1777 dir/` |

---

## 💡 Best Practices

- Default to `644` for files and `755` for directories unless you have a specific reason to deviate.
- Never use `777` — it grants full read/write/execute to everyone, including potential attackers on a shared system.
- Use `600` for sensitive files like SSH private keys, credentials, or config files containing secrets.
- When unsure what a mode change will do, check with `ls -l` immediately before and after.
- Prefer symbolic mode (`u+x`) for incremental tweaks; prefer numeric mode (`755`) when setting a permission set from scratch.
- Be deliberate with `-R`: separate directory and file permission changes when they need different modes (see Recursive Changes above).