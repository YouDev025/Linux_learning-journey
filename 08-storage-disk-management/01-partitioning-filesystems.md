# Partitioning and Filesystems

A reference guide to creating partitions, formatting them with a filesystem, and mounting storage on Linux — covering `fdisk`/`parted`/`gdisk`, common filesystem types, and persistent mount configuration via `/etc/fstab`.

---

## 🧱 The Storage Stack, Conceptually

Before touching any tool, it helps to see the layers involved in turning a raw disk into usable storage:

```
Physical disk  (/dev/sdb)
     │
     ▼
Partition table (MBR or GPT) — divides the disk into partitions
     │
     ▼
Partition  (/dev/sdb1) — a defined slice of the disk
     │
     ▼
Filesystem (ext4, XFS, Btrfs, ...) — formatted onto the partition
     │
     ▼
Mount point (/mnt/data) — where the filesystem becomes accessible in the directory tree
```

Each layer is configured by a different tool: partitioning tools create the table and partitions, `mkfs` formats a filesystem onto a partition, and `mount` (plus `/etc/fstab` for persistence) attaches that filesystem somewhere in the directory tree.

---

## 🧩 Partitioning Tools: `fdisk`, `parted`, `gdisk`

### `fdisk` — The Traditional Tool

```bash
sudo fdisk /dev/sdb
```

This opens an interactive prompt:

```
Command (m for help): m

Command       Action
  a            toggle a bootable flag
  d            delete a partition
  g            create a new empty GPT partition table
  n            add a new partition
  p            print the partition table
  w            write table to disk and exit
  q            quit without saving changes
```

A typical workflow inside `fdisk`:

```
n        → new partition
p        → primary (MBR only; GPT doesn't have this concept)
[Enter]  → accept default partition number
[Enter]  → accept default first sector
+50G      → set size (or accept default for "rest of disk")
w        → WRITE changes and exit
```

> **Tip:** Nothing is written to disk until you press `w`. You can experiment freely and press `q` to quit without saving if you change your mind — this makes `fdisk` considerably safer to explore than it might seem.

### `gdisk` — GPT-Specific

`gdisk` mirrors `fdisk`'s interactive style but is purpose-built for **GPT** partition tables specifically, with clearer handling of GPT-only concepts (partition GUIDs, more partition slots, no "primary/extended" distinction).

```bash
sudo gdisk /dev/sdb
```

The interactive commands are nearly identical to `fdisk` (`n` for new, `d` for delete, `p` for print, `w` for write) — if you already know `fdisk`, `gdisk` should feel immediately familiar.

### `parted` — Scriptable and GPT-Aware

`parted` supports both interactive and direct command-line (non-interactive) use, and natively understands both MBR and GPT without needing a separate tool.

```bash
sudo parted /dev/sdb
```

```
(parted) print                          # show current partition table
(parted) mklabel gpt                     # create a new GPT partition table (DESTROYS existing data)
(parted) mkpart primary ext4 0% 50%       # create a partition spanning the first half of the disk
(parted) print
(parted) quit
```

Non-interactive, scriptable form:

```bash
sudo parted /dev/sdb --script mklabel gpt
sudo parted /dev/sdb --script mkpart primary ext4 0% 100%
```

| Tool | Best for |
|---|---|
| `fdisk` | Quick interactive partitioning, MBR or GPT, most universally familiar |
| `gdisk` | GPT-specific work where you want GPT-native terminology/commands |
| `parted` | Scripting, automation, or when you want one tool for both MBR and GPT |

> ⚠️ **Caution:** `mklabel` (in `parted`) and creating a **new** partition table with any of these tools destroys the existing partition table and, practically speaking, all data on the disk — there's no "are you sure" beyond the explicit commands themselves. Always confirm the target device with `lsblk`/`blkid` first (see the *Block Devices* guide), and back up anything you can't afford to lose before partitioning an existing disk.

---

## 🗃️ Filesystem Types

A **filesystem** defines how data is actually organized, indexed, and retrieved on a partition. Linux supports many; three are worth knowing well.

### ext4

The long-standing default for most Linux distributions — mature, well-understood, broadly compatible with recovery/diagnostic tooling.

| Characteristic | Detail |
|---|---|
| Max file size | 16 TiB |
| Max volume size | 1 EiB |
| Journaling | Yes (protects against corruption from unclean shutdowns) |
| Best for | General-purpose use; the safe, well-tested default choice |

### XFS

A high-performance filesystem, the default on RHEL/CentOS/Fedora for many years, particularly strong with large files and high-throughput workloads.

| Characteristic | Detail |
|---|---|
| Max file size | 8 EiB |
| Max volume size | 8 EiB |
| Journaling | Yes |
| Best for | Large files, high-throughput I/O, large storage arrays |
| Notable limitation | Cannot be shrunk once created (can only grow) — plan sizing carefully upfront |

### Btrfs

A newer, feature-rich filesystem with built-in capabilities that traditionally required separate tools (LVM, RAID) layered on top of a simpler filesystem.

| Characteristic | Detail |
|---|---|
| Built-in snapshots | Yes — point-in-time, space-efficient copies |
| Built-in volume management | Yes — can span/manage multiple devices natively |
| Built-in RAID-like redundancy | Yes (though Btrfs's RAID 5/6 modes have known historical caveats — research current status before relying on them) |
| Best for | Systems wanting snapshots/rollback (e.g. before updates), flexible storage pooling |

### Choosing Between Them

| Need | Reasonable choice |
|---|---|
| General-purpose root filesystem, maximum compatibility | ext4 |
| Large media files, high-throughput storage, enterprise SAN/NAS backing | XFS |
| Snapshot-based rollback (e.g. pre-upgrade safety net), flexible multi-device pooling | Btrfs |
| Uncertain / no strong reason to deviate | ext4 — the safest, most universally supported default |

---

## 🛠️ Creating a Filesystem: `mkfs`

`mkfs` ("make filesystem") formats a partition (or whole disk, less commonly) with the filesystem type of your choice.

```bash
sudo mkfs.ext4 /dev/sdb1
sudo mkfs.xfs /dev/sdb1
sudo mkfs.btrfs /dev/sdb1
```

```bash
sudo mkfs -t ext4 /dev/sdb1      # equivalent generic syntax
```

### Useful Options

```bash
sudo mkfs.ext4 -L mydata /dev/sdb1        # set a volume LABEL at creation time
sudo mkfs.ext4 -b 4096 /dev/sdb1            # specify block size explicitly
sudo mkfs.xfs -f /dev/sdb1                   # force, overwriting an existing filesystem signature
```

> ⚠️ **Caution:** `mkfs` is **destructive** — it overwrites whatever filesystem (and data) currently exists on the target partition, with no recovery beyond backups. Always confirm the target device with `lsblk -f`/`blkid` immediately beforehand, and make sure nothing important is mounted from it.

### Verifying the Result

```bash
sudo blkid /dev/sdb1            # confirm the new TYPE and UUID
lsblk -f                          # confirm it shows up correctly in the device tree
```

---

## 📌 Mounting: `mount`

`mount` attaches a filesystem to a directory (the **mount point**), making its contents accessible at that path.

```bash
sudo mkdir -p /mnt/data              # the mount point must already exist as a directory
sudo mount /dev/sdb1 /mnt/data        # mount it (temporary — see fstab below for persistence)
```

```bash
mount                                  # list all currently mounted filesystems
mount | grep /dev/sdb1                   # check a specific device's mount status
df -h                                    # disk usage of all mounted filesystems
findmnt /mnt/data                         # detailed info about one specific mount point
```

### Common Mount Options

```bash
sudo mount -o ro /dev/sdb1 /mnt/data           # mount read-only
sudo mount -o noexec /dev/sdb1 /mnt/data         # disallow executing binaries from this mount
sudo mount -t ext4 /dev/sdb1 /mnt/data            # explicitly specify filesystem type (usually auto-detected)
```

| Option | Meaning |
|---|---|
| `ro` | Read-only |
| `rw` | Read-write (default) |
| `noexec` | Prevent executing programs from this filesystem |
| `nosuid` | Ignore setuid/setgid bits on this filesystem (see *Special Permissions* guide) |
| `nodev` | Don't interpret device files on this filesystem |
| `defaults` | Shorthand for the standard set: `rw, suid, dev, exec, auto, nouser, async` |

### Unmounting

```bash
sudo umount /mnt/data            # unmount by mount point
sudo umount /dev/sdb1              # or by device — either works
```

```bash
# If umount reports "target is busy":
sudo lsof +D /mnt/data            # find what's still using files on that mount
sudo fuser -v /mnt/data            # alternative way to find processes using the mount
```

> **Note:** A mount created with plain `mount` is **temporary** — it disappears on reboot unless also added to `/etc/fstab`.

---

## 🗂️ Persistent Mounts: `/etc/fstab`

`/etc/fstab` defines filesystems that should be mounted **automatically at boot** (and lets `mount`/`umount` reference them by mount point alone, without repeating all the options each time).

### Anatomy of an fstab Line

```
UUID=1234abcd-5678-90ef-ghij  /mnt/data  ext4  defaults  0  2
       │                          │         │      │      │  │
       │                          │         │      │      │  └── fsck order (0 = skip; 1 = root; 2 = check after root)
       │                          │         │      │      └── dump flag (legacy; 0 = don't back up with `dump`)
       │                          │         │      └── mount options
       │                          │         └── filesystem type
       │                          └── mount point
       └── device identifier
```

| Field | Meaning |
|---|---|
| 1 | Device — **always prefer `UUID=`** over `/dev/sdX` (see *Block Devices* guide for why) |
| 2 | Mount point — the directory it attaches to |
| 3 | Filesystem type (`ext4`, `xfs`, `btrfs`, `swap`, etc.) |
| 4 | Mount options, comma-separated, no spaces |
| 5 | Dump flag — almost always `0` on modern systems (the `dump` utility is rarely used now) |
| 6 | fsck pass number — `0` to skip, `1` for the root filesystem, `2` for others checked after root |

### Finding the UUID to Use

```bash
sudo blkid /dev/sdb1
# /dev/sdb1: UUID="1234abcd-5678-90ef-ghij" TYPE="ext4"
```

### A Complete Example

```
# /etc/fstab
UUID=1234abcd-5678-90ef-ghij-klmnop  /            ext4    defaults        0  1
UUID=90ab-cdef-1234-5678              /boot        ext4    defaults        0  2
UUID=fedc-ba98-7654-3210              /mnt/data    xfs     defaults,noatime 0  2
UUID=11223344-5566-7788-99aa          none         swap    sw              0  0
```

### Testing fstab Changes Safely

Editing `/etc/fstab` incorrectly can prevent a system from booting cleanly. Test changes **before** rebooting:

```bash
sudo mount -a              # attempt to mount everything in fstab right now, without rebooting
echo $?                     # 0 = success; non-zero = something in fstab failed
```

> ⚠️ **Caution:** `mount -a` catches most syntax and device errors immediately, in a recoverable way. Skipping this check and going straight to a reboot risks landing in an emergency/rescue shell if there's a typo — recoverable, but disruptive, especially on a remote/headless machine. Always run `mount -a` after any `/etc/fstab` edit, before rebooting.

### The `nofail` Option

For removable or non-critical media, add `nofail` so the boot process doesn't hang or drop to an emergency shell if that particular device isn't present at boot time:

```
UUID=aabb-ccdd  /mnt/external  ext4  defaults,nofail  0  2
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Partition interactively (universal) | `sudo fdisk /dev/sdb` |
| Partition interactively (GPT-specific) | `sudo gdisk /dev/sdb` |
| Partition non-interactively/scriptable | `sudo parted /dev/sdb --script ...` |
| Format as ext4 | `sudo mkfs.ext4 /dev/sdb1` |
| Format as XFS | `sudo mkfs.xfs /dev/sdb1` |
| Format as Btrfs | `sudo mkfs.btrfs /dev/sdb1` |
| Mount temporarily | `sudo mount /dev/sdb1 /mnt/data` |
| Unmount | `sudo umount /mnt/data` |
| List current mounts | `mount` or `findmnt` |
| Check disk usage of mounts | `df -h` |
| Test fstab without rebooting | `sudo mount -a` |
| Find a device's UUID | `sudo blkid /dev/sdb1` |

---

## 💡 Best Practices

- Always confirm the target device with `lsblk -f`/`blkid` before partitioning or formatting — both operations are destructive and irreversible without a backup.
- Default to ext4 unless you have a specific reason to choose XFS (large-file/high-throughput workloads) or Btrfs (snapshots, multi-device pooling).
- Use `UUID=` in `/etc/fstab`, never raw `/dev/sdX` paths — device letters can shift across reboots.
- Always run `sudo mount -a` after editing `/etc/fstab`, before rebooting — it catches errors in a recoverable way that a reboot-and-hope approach doesn't.
- Add `nofail` to fstab entries for removable or non-essential media, so a missing device doesn't block the entire boot process.
- Remember XFS volumes cannot be shrunk after creation — size generously upfront if there's any chance you'll need more room later without recreating the filesystem.
- When `umount` reports "target is busy," use `lsof +D` or `fuser -v` to find what's still using the mount before forcing anything.