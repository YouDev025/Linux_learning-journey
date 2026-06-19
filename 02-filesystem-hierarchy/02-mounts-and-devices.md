# Mounts and Device Files

In Linux, storage doesn't work the way it does on some other operating systems — there's no `C:` drive or `D:` drive. Instead, every disk, partition, USB stick, and even certain kernel data structures get **attached** ("mounted") onto a single unified directory tree. To understand Linux storage, you need to understand two things: how the kernel represents physical devices (`/dev`), and how those devices get woven into the filesystem you actually navigate (mounting).

---

## Quick Reference Table

| Concept | Purpose | Example |
|---|---|---|
| `/dev` | Device nodes representing hardware | `/dev/sda1`, `/dev/null` |
| `mount` | Attach a filesystem to a directory | `mount /dev/sdb1 /mnt/usb` |
| `umount` | Detach a mounted filesystem | `umount /mnt/usb` |
| `/etc/fstab` | Table of filesystems to mount at boot | Defines disk → mount point mappings |
| `proc` | Virtual filesystem exposing process/kernel info | `/proc/cpuinfo` |
| `sysfs` | Virtual filesystem exposing kernel device info | `/sys/class/net` |
| `tmpfs` | RAM-backed temporary filesystem | Often mounted at `/tmp` |

---

## `/dev` — How Linux Represents Devices

Linux follows the philosophy "everything is a file," and devices are no exception. Every piece of hardware the kernel knows about — disks, terminals, sound cards, even randomness generators — shows up as a special file in `/dev`.

**What you'll find:**
- `/dev/sda`, `/dev/sda1` — a disk and its first partition (SATA/SCSI naming)
- `/dev/nvme0n1` — an NVMe SSD
- `/dev/null` — a "black hole" that discards anything written to it
- `/dev/zero` — produces an endless stream of zero bytes
- `/dev/tty` — the current terminal
- `/dev/random`, `/dev/urandom` — sources of random data

**Two flavors of device files:**
- **Block devices** (`b` in `ls -l` output) — devices that handle data in fixed-size chunks and support random access, like disks (`/dev/sda`).
- **Character devices** (`c` in `ls -l` output) — devices that handle data as a continuous stream, like keyboards or `/dev/null`.

```bash
$ ls -l /dev/sda /dev/null
brw-rw---- 1 root disk  8,   0 Jun 19 10:00 /dev/sda
crw-rw-rw- 1 root root  1,   3 Jun 19 10:00 /dev/null
```

> **Key trait:** A device file in `/dev` is just a *handle* the kernel uses to talk to hardware — it's not the data itself. Having `/dev/sda1` doesn't mean you can browse its files yet; for that, it needs to be **mounted**.

---

## Mounting: Attaching a Filesystem to a Directory

"Mounting" means taking a filesystem (on a disk partition, USB drive, ISO image, or even a virtual source) and making its contents appear at a specific directory — called the **mount point** — within the existing filesystem tree.

### The `mount` command

```bash
# Mount a USB drive's first partition at /mnt/usb
sudo mount /dev/sdb1 /mnt/usb

# Mount with a specific filesystem type
sudo mount -t ext4 /dev/sdb1 /mnt/usb

# Mount an ISO file as if it were a disk
sudo mount -o loop ubuntu.iso /mnt/iso

# View everything currently mounted
mount
# or, more readably:
findmnt
```

Once mounted, files on `/dev/sdb1` appear seamlessly under `/mnt/usb` — `cd /mnt/usb` and `ls` behave exactly as if those files had always lived there.

### The `umount` command

Before physically removing a drive, it must be unmounted, or you risk data corruption from unwritten cache buffers.

```bash
sudo umount /mnt/usb
# or by device:
sudo umount /dev/sdb1
```

If you get a "target is busy" error, something (a shell session, an open file, a running process) still has a file open on that mount — `lsof +D /mnt/usb` or `fuser -m /mnt/usb` can help track it down.

> **Rule of thumb:** Mounting doesn't move or copy data — it makes existing data on a device *visible* at a chosen location in the directory tree.

---

## `/etc/fstab` — The Filesystem Table

Manually running `mount` after every reboot would be tedious, so Linux uses `/etc/fstab` ("filesystem table") to define which filesystems should be mounted automatically at boot, and where.

### Anatomy of an `/etc/fstab` line

```
# <device>          <mount point>   <fs type>   <options>       <dump>  <pass>
UUID=1a2b3c4d...     /               ext4        defaults        0       1
UUID=5e6f7g8h...     /home           ext4        defaults        0       2
/dev/sdb1            /mnt/data       ext4        defaults,noatime 0      2
tmpfs                /tmp            tmpfs       defaults,size=2G 0      0
```

| Field | Meaning |
|---|---|
| Device | The partition, by UUID (preferred, stable across reboots), label, or device path |
| Mount point | Where it gets attached in the directory tree |
| Filesystem type | `ext4`, `xfs`, `btrfs`, `vfat`, `tmpfs`, etc. |
| Options | Mount behavior — `defaults`, `ro` (read-only), `noatime` (skip access-time updates for speed), etc. |
| Dump | Legacy field for the `dump` backup utility (almost always `0` today) |
| Pass | Order for `fsck` filesystem checks at boot (`0` = skip, `1` = root first, `2` = after root) |

**Why UUIDs instead of `/dev/sda1`?** Device names like `/dev/sda1` can shift between boots depending on detection order, especially with multiple drives. UUIDs are generated when the filesystem is created and never change, making them far more reliable for `/etc/fstab` entries.

```bash
# Find a partition's UUID
sudo blkid /dev/sda1
```

> **Caution:** A typo in `/etc/fstab` can prevent a system from booting cleanly. Test new entries with `sudo mount -a` (which mounts everything listed but not yet mounted) before rebooting.

---

## Virtual Filesystems: Mounted, But Not on a Disk

Not everything mounted in Linux corresponds to a physical device. Several filesystems are generated entirely by the kernel in memory, used to expose live system information or provide fast temporary storage.

### `proc` — Process and Kernel Information

Mounted at `/proc`, this filesystem doesn't store anything on disk — its contents are generated on the fly, representing the live state of the kernel and running processes.

```bash
cat /proc/cpuinfo      # CPU details
cat /proc/meminfo       # Memory usage
ls /proc/1234/          # Info about process with PID 1234
cat /proc/uptime        # System uptime
```

**Key trait:** File sizes shown for `/proc` entries are often `0` even though `cat`-ing them produces output — the kernel generates the content at the moment you read it.

### `sysfs` — Kernel Device Information

Mounted at `/sys`, `sysfs` exposes a structured view of devices, drivers, and kernel subsystems — more organized and modern than `/proc` for device-related data.

```bash
cat /sys/class/net/eth0/address     # MAC address of a network interface
cat /sys/class/thermal/thermal_zone0/temp  # CPU temperature
```

### `tmpfs` — RAM-Backed Temporary Storage

`tmpfs` is a filesystem that lives entirely in RAM (and swap, if needed), rather than on a physical disk. It's commonly used for `/tmp` or `/dev/shm` because RAM is dramatically faster than disk, and the data is expected to be temporary anyway.

```bash
mount -t tmpfs -o size=512M tmpfs /mnt/ramdisk
```

**Key trait:** Anything stored in a `tmpfs` mount vanishes on reboot (or unmount) because it never touched persistent storage in the first place.

> **Rule of thumb:** If a filesystem's size in `df -h` looks suspiciously tied to your RAM size, or its contents disappear on reboot, it's probably `tmpfs`, `proc`, or `sysfs` — not a real disk.

---

## Putting It All Together

A mental model that ties this together:

1. **The kernel detects hardware** and creates device files in `/dev` (`/dev/sda1`, etc.) — these are just handles, not yet accessible as folders of files.
2. **Mounting** takes a device (or a virtual source like `tmpfs`) and attaches its filesystem to a directory, making its contents browsable.
3. **`/etc/fstab`** automates this process at boot so you don't have to mount everything by hand every time.
4. **Virtual filesystems** (`proc`, `sysfs`, `tmpfs`) extend the same mounting mechanism to things that aren't physical disks at all — letting the kernel expose live data or fast memory-backed storage using the exact same `/` tree you already navigate.

Once you see `/dev`, mounting, and `/etc/fstab` as three connected pieces of the same system, Linux storage stops feeling like a black box — every directory you `cd` into is either a real device or virtual data that's been deliberately attached there.