# Block Devices

A reference guide to how Linux represents disks and storage hardware — device naming conventions, partition layout, identifying device attributes, and safe handling practices.

---

## 🧱 What a Block Device Is

A **block device** is hardware (or a virtual equivalent) that the kernel accesses in fixed-size chunks ("blocks"), rather than as a continuous stream — disks, SSDs, USB drives, and even virtual disks inside a VM all fall into this category. This is distinct from a **character device** (like a keyboard or serial port), which is accessed as a stream of individual bytes.

All block devices appear as special files under `/dev/`:

```bash
ls -l /dev/sda
# brw-rw---- 1 root disk 8, 0 Jun 20 10:00 /dev/sda
#  │
#  └── "b" = block device (see the Permissions guides for the rest of this output)
```

---

## 🏷️ Device Naming Conventions

### `/dev/sd*` — SCSI/SATA Devices

Traditional spinning hard drives and SATA SSDs (and USB drives, which present themselves over the same SCSI subsystem) appear as `/dev/sdX`, where the letter increments per physical device, in the order the kernel discovers them.

```
/dev/sda     ← first detected disk
/dev/sdb     ← second detected disk
/dev/sdc     ← third detected disk
```

| Pattern | Meaning |
|---|---|
| `/dev/sda` | The whole disk |
| `/dev/sda1` | The first partition on that disk |
| `/dev/sda2` | The second partition on that disk |

> **Note:** Like the older `eth0`/`eth1` network interface naming (see the *Networking Basics* guide), `/dev/sdX` letters are assigned in detection order, which **can change** across reboots if drives are added, removed, or initialize in a different sequence — especially with multiple USB devices. For anything requiring a stable reference (fstab entries, scripts), prefer UUIDs or labels over raw device names — see below.

### `/dev/nvme*` — NVMe Devices

Modern NVMe SSDs (connected via PCIe rather than SATA) use a different, more structured naming scheme reflecting the NVMe protocol's own addressing concepts:

```
/dev/nvme0n1       ← controller 0, namespace 1 (the "whole disk" equivalent)
/dev/nvme0n1p1     ← controller 0, namespace 1, partition 1
/dev/nvme0n1p2     ← controller 0, namespace 1, partition 2
/dev/nvme1n1       ← a second physical NVMe controller/drive
```

```
nvme 0  n 1  p 1
  │   │  │ │  │ │
  │   │  │ │  │ └── partition number
  │   │  │ │  └── "p" separator (needed because the namespace is already numeric)
  │   │  │ └── namespace number
  │   │  └── "n" separator
  │   └── controller index
  └── protocol prefix
```

> **Why the extra "p":** unlike `/dev/sda1`, NVMe device names already end in a number (the namespace), so a `p` separator is needed before the partition number to avoid ambiguity — `/dev/nvme0n11` would otherwise be unreadable as "namespace 1, partition 1" vs. "namespace 11."

### Other Common Prefixes

| Prefix | Device type |
|---|---|
| `/dev/sd*` | SATA/SCSI/USB disks |
| `/dev/nvme*` | NVMe SSDs |
| `/dev/vd*` | Virtio virtual disks (common in KVM/QEMU virtual machines) |
| `/dev/xvd*` | Xen virtual disks (older AWS EC2 instance types) |
| `/dev/mmcblk*` | SD cards / eMMC storage (common on embedded systems, Raspberry Pi) |
| `/dev/loop*` | Loopback devices — a regular file mounted as if it were a block device |

---

## 🔍 `lsblk` — Listing Block Devices

`lsblk` shows all block devices and their partition/mount hierarchy in an easy-to-read tree.

```bash
lsblk
```

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0   500G  0 disk
├─sda1        8:1    0     1G  0 part /boot
├─sda2        8:2    0    16G  0 part [SWAP]
└─sda3        8:3    0   483G  0 part /
nvme0n1     259:0    0     1T  0 disk
└─nvme0n1p1 259:1    0     1T  0 part /data
```

### Useful Flags

```bash
lsblk -f              # include filesystem type, label, and UUID
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,UUID    # choose exactly which columns to show
lsblk -d               # show only whole disks, not their partitions
lsblk -p                # show full /dev/ paths instead of bare names
lsblk -J                # output as JSON, useful for scripting
```

```bash
lsblk -f
```

```
NAME        FSTYPE   LABEL    UUID                                 MOUNTPOINTS
sda1        ext4      boot     1234abcd-...                         /boot
sda3        ext4      root     5678efgh-...                         /
nvme0n1p1   xfs       data      90ab-cdef-...                        /data
```

---

## 🧾 `blkid` — Identifying Device Attributes

`blkid` reports detailed low-level attributes for block devices — most importantly the **UUID** and **filesystem type**, which are essential for stable mounting configuration.

```bash
sudo blkid                       # show attributes for ALL detected block devices
sudo blkid /dev/sda1               # show attributes for one specific device
```

```
/dev/sda1: UUID="1234abcd-5678-90ef-ghij-klmnopqrstuv" TYPE="ext4" PARTUUID="..."
/dev/nvme0n1p1: UUID="90ab-cdef" TYPE="xfs" PARTUUID="..."
```

| Field | Meaning |
|---|---|
| `UUID` | A unique identifier generated when the filesystem was created — stable across reboots and even across moving the disk to a different controller/port |
| `TYPE` | The filesystem format (`ext4`, `xfs`, `btrfs`, `vfat`, etc.) |
| `PARTUUID` | A UUID identifying the **partition itself**, independent of whatever filesystem is on it |
| `LABEL` | A human-assigned name, if one was set when the filesystem was created |

### Why UUIDs Matter for Stable Configuration

Device names like `/dev/sda1` can shift between boots if hardware detection order changes. UUIDs are generated once, embedded in the filesystem itself, and remain stable regardless of which `/dev/sdX` letter the kernel happens to assign this time.

```bash
# /etc/fstab — referencing by UUID instead of device name
UUID=1234abcd-5678-90ef-ghij-klmnopqrstuv  /boot  ext4  defaults  0  2
```

> **Tip:** Always use `UUID=` (or `LABEL=`, if you've set one) in `/etc/fstab` rather than raw device paths like `/dev/sda1` — this is one of the most common sources of a system failing to boot after adding/removing a drive, since the "same" partition can suddenly be `/dev/sdb1` instead of `/dev/sda1`.

---

## 🧩 Partitions and Partition Tables

### Partition Table Formats

| Format | Notes |
|---|---|
| **MBR** (Master Boot Record) | Legacy, limited to 4 primary partitions and 2TB per disk |
| **GPT** (GUID Partition Table) | Modern standard, supports many more partitions and much larger disks |

```bash
sudo fdisk -l /dev/sda          # show partition table (works with both MBR and GPT)
sudo parted /dev/sda print        # alternative, often clearer GPT-aware output
sudo gdisk -l /dev/sda             # GPT-specific inspection tool
```

### Viewing Partition Layout

```bash
lsblk /dev/sda
sudo fdisk -l /dev/sda
sudo parted -l
```

> ⚠️ **Caution:** Tools like `fdisk`, `parted`, and `gdisk` can modify partition tables, not just view them — running them with write subcommands on the wrong device can destroy data instantly. Always double-check the target device path (`/dev/sda` vs `/dev/sdb`) before issuing any write/modify command, and prefer the explicit `-l`/`print`/`list`-style read-only invocations shown above when you only intend to inspect.

---

## 🔧 Raw Device Handling

### Reading/Writing Raw Devices Directly

```bash
sudo dd if=/dev/sda of=disk-image.img bs=4M status=progress    # image an entire disk
sudo dd if=disk-image.img of=/dev/sdb bs=4M status=progress     # restore an image to a disk
```

| Flag | Meaning |
|---|---|
| `if=` | Input file (source) |
| `of=` | Output file (destination) |
| `bs=` | Block size — larger values are generally faster, up to a point |
| `status=progress` | Show live progress (not available in all `dd` versions) |

> ⚠️ **Extreme caution with `dd`:** `dd` operates at the raw block level with **no confirmation prompts and no undo**. Swapping `if=` and `of=`, or pointing `of=` at the wrong device, can silently and irreversibly destroy an entire disk's contents in seconds. This is precisely why `dd` has the (only half-joking) nickname "disk destroyer" among Linux admins. Always triple-check device paths with `lsblk`/`blkid` immediately before running it, and consider unmounting the target device first as an extra safety measure.

### Checking for Errors at the Block Level

```bash
sudo smartctl -a /dev/sda          # view SMART health/diagnostic data (install smartmontools if missing)
sudo badblocks -v /dev/sda1          # scan for bad blocks (read-only mode by default; can be destructive in write-test modes)
```

---

## 🗂️ Device Management Best Practices

### Identifying a Device Before Acting On It

```bash
lsblk -f                  # see all devices, filesystems, and mount points at a glance
sudo blkid                 # confirm UUID/filesystem type for the specific device in question
df -h                       # cross-check what's actually mounted where right now
mount | grep /dev/sdb1       # confirm a specific device's current mount state
```

> **Tip:** Before running any destructive command (`dd`, `mkfs`, `parted` write operations, `fdisk` write operations), run all four commands above first. The few extra seconds of confirmation is far cheaper than recovering from acting on the wrong device.

### Safely Removing/Unmounting External Devices

```bash
sudo umount /dev/sdb1            # unmount before physical removal
sudo eject /dev/sdb                # some removable media also supports explicit eject
udisksctl power-off -b /dev/sdb     # power down a USB device cleanly, if supported
```

> ⚠️ **Caution:** Removing a USB/external drive without unmounting it first risks data loss or filesystem corruption — the kernel may still have buffered writes that haven't actually reached the device yet. Always unmount (and ideally `sync` first) before physical disconnection.

```bash
sync               # flush any pending writes to disk before unmounting/removing media
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| List all block devices (tree view) | `lsblk` |
| List with filesystem info | `lsblk -f` |
| Show full /dev/ paths | `lsblk -p` |
| Show device attributes (UUID, type) | `sudo blkid` |
| Show one device's attributes | `sudo blkid /dev/sda1` |
| View partition table | `sudo fdisk -l /dev/sda` |
| Alternative partition view | `sudo parted -l` |
| Image an entire disk | `sudo dd if=/dev/sda of=image.img bs=4M status=progress` |
| Check disk health (SMART) | `sudo smartctl -a /dev/sda` |
| Flush pending writes | `sync` |
| Unmount before removal | `sudo umount /dev/sdb1` |

---

## 💡 Best Practices

- Use `UUID=` (or `LABEL=`) in `/etc/fstab` rather than raw `/dev/sdX` paths — device letters can shift across reboots, but UUIDs stay stable.
- Cross-check `lsblk -f`, `blkid`, and `df -h` together before running any destructive command — confirming from multiple angles catches mistakes a single check might miss.
- Treat `dd` with extreme care: verify `if=`/`of=` device paths immediately before execution, every single time, with no exceptions for "I'm sure this time."
- Always `sync` and unmount external devices before physical removal — buffered writes that haven't hit the disk yet are a common, avoidable cause of corruption.
- Prefer read-only inspection commands (`fdisk -l`, `parted print`, `blkid`) to confirm a device's identity before reaching for any tool capable of modifying it.
- Periodically check `smartctl -a` on physical drives to catch early signs of hardware failure before it causes data loss.
- Remember NVMe naming's extra `p` separator (`nvme0n1p1`) exists specifically to avoid ambiguity with the numeric namespace — don't mentally pattern-match it to `/dev/sdaX` naming.