# Group Management

A reference guide to Linux groups — how they enforce access boundaries, the difference between primary and secondary groups, and how to create, modify, and manage group membership.

---

## 🧩 Why Groups Exist

Permissions in Linux are evaluated for **user**, **group**, and **other** (see *Permissions and Modes*). Groups exist so that **access can be granted to a set of users at once**, without listing individuals one by one or relying solely on the broad "other" category.

This enables **privilege separation**: a `developers` group can read/write source code, a `deployers` group can push to production, and a `finance` group can access accounting files — all without overlapping access, and all manageable by adding or removing users from the relevant group rather than editing permissions on every file.

---

## 🧾 `/etc/group` — The Group Database

Every group is recorded as one line in `/etc/group`:

```bash
cat /etc/group
# developers:x:1002:alice,bob,carol
```

Fields (colon-separated):

```
developers : x : 1002 : alice,bob,carol
     │        │    │           │
     │        │    │           └── member list (secondary members)
     │        │    └── GID (group ID)
     │        └── password placeholder (rarely used — see "Group Passwords" below)
     └── group name
```

| Field | Name | Meaning |
|---|---|---|
| 1 | Group name | Name used in commands and `ls -l` output |
| 2 | Password | Legacy field, almost always unused (`x` or blank) |
| 3 | GID | Numeric group ID |
| 4 | Member list | Comma-separated usernames who belong as a **secondary** group |

> **Note:** Members listed in `/etc/group` are the group's **secondary** members. Users whose **primary** group is this one (set in `/etc/passwd`) belong too, but won't necessarily appear in this list — see below.

---

## 🥇 Primary vs. 🥈 Secondary Groups

Every user has exactly **one primary group** and can belong to **any number of secondary (supplementary) groups**.

### Primary Group

- Recorded in the **GID field of `/etc/passwd`**.
- Used as the default group owner for any new file the user creates.
- A user always has exactly one.

```bash
id alice
# uid=1001(alice) gid=1001(alice) groups=1001(alice),1002(developers),27(sudo)
#                  └── primary       └── all groups, including primary and secondary
```

### Secondary Groups

- Recorded in the **member list of `/etc/group`**.
- Grant *additional* access without changing what group owns new files.
- A user can belong to as many as needed.

```bash
groups alice
# alice : alice developers sudo
```

### Why the Distinction Matters

If `alice`'s primary group is `alice` (a common default — many distros give each user their own private primary group) and she's a secondary member of `developers`:

- Files she creates default to group **`alice`** (her primary group), keeping her personal files private by default.
- She still gets `developers`-level access to shared resources via her secondary membership.

This pattern — one private primary group per user, shared access granted via secondary groups — is the standard modern convention on most distributions (notably Debian/Ubuntu's "user private group" scheme).

---

## ➕ Creating Groups: `groupadd`

```bash
sudo groupadd developers
```

### Common Flags

```bash
sudo groupadd -g 2000 developers
```

| Flag | Meaning |
|---|---|
| `-g GID` | Specify a custom GID instead of letting the system assign the next available one |
| `-r` | Create a **system** group (uses a lower GID range reserved for services) |

```bash
sudo groupadd -r serviceaccounts   # system group, e.g. for a daemon
```

---

## ➖ Deleting Groups: `groupdel`

```bash
sudo groupdel developers
```

> ⚠️ **Caution:** You cannot delete a group that is still set as any user's **primary** group — `groupdel` will fail with an error until you reassign those users to a different primary group first (see `usermod -g` below).

```bash
groupdel developers
# groupdel: cannot remove the primary group of user 'alice'
```

Check what files are still owned by the group before deleting it, since they'll become orphaned:

```bash
find / -group developers 2>/dev/null
```

---

## ✏️ Modifying Groups: `groupmod`

```bash
sudo groupmod -n newname oldname    # rename a group
sudo groupmod -g 2050 developers    # change a group's GID
```

| Flag | Meaning |
|---|---|
| `-n newname` | Rename the group |
| `-g GID` | Change the group's GID |

> ⚠️ Changing a GID with `groupmod -g` does **not** retroactively update ownership on files that already reference the old GID — they'll now show as owned by "an unrecognized group" until you run `chgrp` or `find ... -exec chgrp` to fix them.

---

## 👤 Adding and Removing Users from Groups

### Adding a User to a Secondary Group

```bash
sudo usermod -aG developers alice
```

> ⚠️ **Always use `-aG` (append), never just `-G`.** Plain `-G` **replaces** the user's entire secondary group list with whatever you specify — accidentally removing them from every other group they belonged to.

```bash
# WRONG — wipes out all of alice's other secondary groups:
sudo usermod -G developers alice

# RIGHT — adds developers, keeps existing memberships:
sudo usermod -aG developers alice
```

### Adding a User Directly via `gpasswd`

An alternative, more explicit tool for managing group membership:

```bash
sudo gpasswd -a alice developers    # add alice to developers
sudo gpasswd -d alice developers    # remove alice from developers
```

### Changing a User's Primary Group

```bash
sudo usermod -g developers alice
```

This changes which group new files default to, but does not affect secondary memberships.

### Removing a User from a Secondary Group

There's no single flag to remove one group cleanly with `usermod` — `gpasswd -d` is the simplest way:

```bash
sudo gpasswd -d alice developers
```

Alternatively, rebuild the full list with `usermod -G` (replacing, intentionally this time):

```bash
sudo usermod -G developers,sudo alice   # sets the FULL list, omitting "olddept" removes it
```

---

## 🔍 Inspecting Group Membership

```bash
groups alice                  # list all groups alice belongs to
id alice                      # show UID, primary GID, and all group memberships
getent group developers       # show a single group's full entry (works with NIS/LDAP too)
grep developers /etc/group     # raw lookup directly in the file
```

> **Tip:** Prefer `getent` over directly `cat`-ing `/etc/group` or `/etc/passwd` on systems that use centralized authentication (LDAP, NIS, SSSD) — `getent` queries whichever backend is actually configured, while the flat files may not reflect remote-managed accounts at all.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View all groups | `cat /etc/group` |
| View a specific group | `getent group developers` |
| View a user's groups | `groups alice` or `id alice` |
| Create a group | `sudo groupadd developers` |
| Create a group with custom GID | `sudo groupadd -g 2000 developers` |
| Create a system group | `sudo groupadd -r servicegroup` |
| Delete a group | `sudo groupdel developers` |
| Rename a group | `sudo groupmod -n newname oldname` |
| Change a group's GID | `sudo groupmod -g 2050 developers` |
| Add user to group (safe) | `sudo usermod -aG developers alice` |
| Add user to group (alt.) | `sudo gpasswd -a alice developers` |
| Remove user from group | `sudo gpasswd -d alice developers` |
| Change a user's primary group | `sudo usermod -g developers alice` |
| Find files owned by a group | `find / -group developers` |

---

## 💡 Best Practices

- Always use `usermod -aG` (append) instead of `usermod -G` (overwrite) when adding someone to a group — this is the single most common group-management mistake.
- Use `gpasswd -a` / `gpasswd -d` when you want unambiguous single-group add/remove operations without worrying about `-a` flags.
- Follow the "user private group" convention — give each user their own primary group, and grant shared access exclusively through secondary groups. It keeps personal file ownership clean and shared access explicit.
- Before deleting a group, check for files it still owns (`find / -group name`) and reassign or clean them up — otherwise they become orphaned.
- Reassign any user's primary group (`usermod -g`) away from a group **before** trying to delete that group — `groupdel` will refuse otherwise.
- On systems using LDAP/NIS/SSSD, use `getent` rather than reading `/etc/group` directly, to ensure you're seeing the full, authoritative membership list.
- Design groups around **roles and access boundaries** (e.g. `developers`, `deployers`, `finance`) rather than around individual projects or one-off needs — it keeps the permission model easy to reason about as the system grows.