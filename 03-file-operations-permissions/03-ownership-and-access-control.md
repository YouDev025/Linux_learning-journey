# Ownership and Access Control

A reference guide to Linux file ownership — how user and group ownership work, how to change them with `chown` and `chgrp`, and how Access Control Lists (ACLs) extend permissions beyond the basic owner/group/other model.

---

## 👤 User and Group Ownership

Every file and directory on a Linux system has exactly **two owners**:

- A **user owner** — typically whoever created the file
- A **group owner** — a set of users who share some level of access

You can see both in the output of `ls -l`:

```bash
ls -l report.txt
# -rw-r--r-- 1 alice developers 4096 Jun 20 10:00 report.txt
#             │     │
#             │     └── group owner
#             └──────── user owner
```

Here, `alice` owns the file, and the group `developers` is the group owner. Permissions are then evaluated in this order:

1. If you're the **user owner** → your access is determined by the **owner** permission bits.
2. Else, if you're a **member of the group owner** → your access is determined by the **group** permission bits.
3. Otherwise → your access is determined by the **other** permission bits.

> **Important:** only the first matching rule applies. Even if you're in the file's group, if you're *also* the owner, the group bits are irrelevant to you — the owner bits decide your access.

### Checking Your Own Identity

```bash
whoami          # current username
id              # current user, UID, group, GID, and all groups you belong to
groups          # list of groups you belong to
groups alice    # list of groups another user belongs to
```

---

## 🔄 Changing Ownership with `chown`

`chown` changes the **user owner**, the **group owner**, or both at once.

### Syntax

```bash
chown [user][:group] file
```

### Examples

```bash
chown alice file.txt              # change user owner only
chown alice:developers file.txt   # change user and group owner together
chown :developers file.txt        # change group owner only (note the leading colon)
chown alice: file.txt             # change user owner; set group to alice's default group
```

### Recursive Ownership Changes

Use `-R` to apply ownership to a directory and everything inside it:

```bash
chown -R alice:developers /shared/project/
```

> ⚠️ **Caution:** `chown -R` rewrites ownership on *every* file and subdirectory in the tree, with no per-item distinction. Double-check the path — running this on the wrong directory (e.g. `/` instead of `/home/alice/`) can break system file ownership and require significant recovery work.

### Who Can Run `chown`?

On most Linux systems, **only root** can change a file's user owner — regular users cannot give away files they own, even to themselves. This prevents users from circumventing disk quotas by transferring files to other accounts. Regular users *can* change a file's group, but only to a group they already belong to.

```bash
sudo chown alice:developers file.txt   # typically requires sudo/root
```

---

## 🔄 Changing Group Ownership with `chgrp`

`chgrp` changes only the **group owner**, leaving the user owner untouched. It's a more explicit alternative to `chown :group`.

```bash
chgrp developers file.txt
chgrp -R developers /shared/project/    # recursive
```

A regular user can run `chgrp` on files they own, as long as they're a member of the target group:

```bash
groups                          # confirm you belong to "developers"
chgrp developers report.txt     # works without sudo, since you're a member
```

---

## 🏗️ Practical Patterns

### Setting Up a Shared Team Directory

```bash
sudo mkdir /shared/team-project
sudo chown alice:developers /shared/team-project
sudo chmod 2775 /shared/team-project   # setgid ensures new files inherit "developers" group
```

After this:
- `alice` owns the directory.
- Anyone in `developers` can read/write inside it.
- New files created inside automatically belong to `developers` (thanks to setgid — see the *Special Permissions* guide for details).

### Fixing Ownership After a File Transfer

If you copy files from another user's directory (e.g. via `sudo cp`), ownership often needs correcting:

```bash
sudo chown -R $(whoami):$(whoami) ./migrated-files/
```

### Auditing Ownership

```bash
find /shared -not -user alice          # find files NOT owned by alice
find /shared -group developers         # find files owned by the developers group
```

---

## 🧱 Access Control Lists (ACLs)

Standard Linux permissions only support **one** user owner and **one** group owner per file. ACLs extend this, letting you grant specific permissions to **additional** users or groups beyond the standard owner/group/other model.

### Why ACLs Exist

Imagine a file owned by `alice` in group `developers`, but you also need `bob` (who isn't in `developers`) to have read access — without changing the file's group or making it world-readable. Standard permissions can't express "give bob read access specifically." ACLs can.

### Checking if ACLs Are Supported

Most modern filesystems (ext4, xfs, btrfs) support ACLs by default. Check with:

```bash
mount | grep acl     # look for "acl" in the mount options
```

### Viewing ACLs: `getfacl`

```bash
getfacl file.txt
```

```
# file: file.txt
# owner: alice
# group: developers
user::rw-
user:bob:r--
group::r--
mask::rw-
other::r--
```

The `user:bob:r--` line is an ACL entry — it grants `bob` read access specifically, on top of the standard permission bits.

### Setting ACLs: `setfacl`

```bash
setfacl -m u:bob:r file.txt          # grant user bob read access
setfacl -m g:designers:rw file.txt   # grant group designers read+write
setfacl -x u:bob file.txt            # remove bob's specific ACL entry
setfacl -b file.txt                  # remove ALL ACL entries (back to standard permissions)
```

| Flag | Meaning |
|---|---|
| `-m` | Modify — add or update an ACL entry |
| `-x` | Remove a specific ACL entry |
| `-b` | Remove all ACL entries |
| `-R` | Apply recursively |
| `-d` | Set a **default** ACL (auto-applies to new files created inside a directory) |

### Default ACLs for Directories

A **default ACL** on a directory automatically applies to any new file or subdirectory created inside it — similar in spirit to setgid, but far more granular:

```bash
setfacl -d -m u:bob:rw /shared/project/
```

Now, any new file created inside `/shared/project/` automatically grants `bob` read+write — without needing to set it manually each time.

### Indicator in `ls -l`

When a file has ACL entries beyond the standard permission bits, `ls -l` shows a `+` after the permission string:

```bash
ls -l file.txt
# -rw-r--r--+ 1 alice developers 4096 Jun 20 10:00 file.txt
#           ↑
#      "+" indicates ACL entries are present — check with getfacl for details
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View owner and group | `ls -l file` |
| Change user owner | `chown alice file` |
| Change group owner | `chown :developers file` or `chgrp developers file` |
| Change both at once | `chown alice:developers file` |
| Apply recursively | `chown -R alice:developers dir/` |
| List your groups | `groups` |
| List another user's groups | `groups username` |
| View ACLs | `getfacl file` |
| Add/modify an ACL entry | `setfacl -m u:user:rwx file` |
| Remove one ACL entry | `setfacl -x u:user file` |
| Remove all ACL entries | `setfacl -b file` |
| Set a default ACL on a directory | `setfacl -d -m u:user:rwx dir/` |

---

## 💡 Best Practices

- Use `chgrp` instead of `chown :group` when you only need to change the group — it's more explicit and self-documenting.
- Combine `chown` with setgid (`chmod 2775`) for shared team directories so new files consistently inherit the right group.
- Always confirm `groups` membership before running `chgrp` to a target group — it will fail (or require sudo) if you aren't a member.
- Treat `chown -R` and `setfacl -R` with the same caution as `rm -rf` — both make sweeping, hard-to-reverse changes across an entire directory tree.
- Reach for ACLs only when standard owner/group/other permissions genuinely can't express what you need (e.g. multiple unrelated users needing different access). For most cases, standard permissions plus thoughtful group design are simpler to reason about and maintain.
- Check for ACLs on a file with `ls -l` (look for the trailing `+`) before assuming permissions are fully explained by the standard `rwx` bits.