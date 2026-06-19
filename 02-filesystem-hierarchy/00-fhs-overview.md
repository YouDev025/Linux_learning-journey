# Filesystem Hierarchy Standard (FHS)

> A reference guide to the Linux directory layout — what lives where, and why.

The **Filesystem Hierarchy Standard** defines the directory structure and directory contents in Linux and Unix-like operating systems. It ensures that software developers, system administrators, and users can predict where files reside, regardless of the distribution.

---

## The Root Filesystem: `/`

Everything in Linux lives under a single unified tree rooted at `/`. Unlike Windows, there are no drive letters — all storage devices, network mounts, and virtual filesystems attach somewhere beneath this single root.

```
/
├── bin/
├── boot/
├── dev/
├── etc/
├── home/
├── lib/
├── media/
├── mnt/
├── opt/
├── proc/
├── root/
├── run/
├── sbin/
├── srv/
├── sys/
├── tmp/
├── usr/
│   ├── bin/
│   ├── include/
│   ├── lib/
│   ├── local/
│   └── sbin/
└── var/
    ├── cache/
    ├── log/
    ├── mail/
    └── spool/
```

---

## Core Directories

### `/bin` — Essential User Binaries

Contains the fundamental command-line programs required for the system to boot and for users to perform basic operations, even in single-user (recovery) mode.

**Key contents:** `ls`, `cp`, `mv`, `rm`, `cat`, `echo`, `bash`, `sh`

> On many modern distros, `/bin` is a symlink to `/usr/bin` as part of the *usrmerge* initiative.

---

### `/sbin` — System Binaries

Like `/bin`, but for system administration commands typically run only by root or during boot sequences.

**Key contents:** `fsck`, `mount`, `umount`, `iptables`, `fdisk`, `init`, `reboot`

> Also commonly symlinked to `/usr/sbin` on modern distributions.

---

### `/usr` — Unix System Resources

One of the largest directories — contains the majority of user-space programs, libraries, and documentation. It is designed to be shareable and read-only across hosts.

| Subdirectory | Purpose |
|---|---|
| `/usr/bin` | Non-essential user commands (`gcc`, `python`, `vim`) |
| `/usr/sbin` | Non-essential admin commands |
| `/usr/lib` | Libraries for `/usr/bin` and `/usr/sbin` |
| `/usr/include` | C/C++ header files |
| `/usr/share` | Architecture-independent data (docs, man pages) |
| `/usr/local` | Locally compiled/installed software (safe from package manager) |
| `/usr/src` | Kernel and software source code |

---

### `/var` — Variable Data

Holds data that is expected to change continuously during normal system operation. Never assumed to be static or sharable as read-only.

| Subdirectory | Contents |
|---|---|
| `/var/log` | System and application logs (`syslog`, `auth.log`, `kern.log`) |
| `/var/cache` | Cached application data (apt cache, browser cache) |
| `/var/spool` | Queued jobs — print queues, mail queues, cron jobs |
| `/var/tmp` | Temporary files that persist across reboots |
| `/var/mail` | User mailboxes |
| `/var/run` | Runtime PID files and sockets (often symlinked to `/run`) |
| `/var/lib` | Persistent application state (databases, package manager state) |

---

### `/etc` — Configuration Files

The system-wide configuration directory. Contains plain-text configuration files for virtually every installed service and system component. **No binaries live here.**

**Notable files:**

```
/etc/passwd        # User accounts
/etc/shadow        # Hashed passwords (root-readable only)
/etc/group         # Group definitions
/etc/hosts         # Static hostname resolution
/etc/fstab         # Filesystem mount table
/etc/hostname      # System hostname
/etc/resolv.conf   # DNS resolver configuration
/etc/crontab       # System-wide cron schedule
/etc/ssh/          # SSH daemon configuration
/etc/systemd/      # systemd unit files and targets
```

---

### `/home` — User Home Directories

Each user on the system gets a personal directory under `/home`, typically `/home/<username>`. This is where personal files, configurations (dotfiles), and user-specific data live.

```
/home/
├── alice/
│   ├── .bashrc
│   ├── .ssh/
│   └── Documents/
└── bob/
    ├── .config/
    └── Projects/
```

The root user's home is **not** under `/home` — it lives at `/root`.

---

## Virtual/Pseudo Filesystems

These directories do **not** exist on disk. They are dynamically generated in-memory by the kernel to expose system information as files. Reading them queries the kernel directly; writing to them can change kernel parameters at runtime.

---

### `/proc` — Process and Kernel Information

A virtual filesystem exposing the internal state of the kernel and all running processes.

```bash
/proc/cpuinfo          # CPU architecture, model, cores, features
/proc/meminfo          # Memory usage breakdown
/proc/loadavg          # System load average
/proc/uptime           # Time since last boot
/proc/version          # Kernel version string
/proc/mounts           # Currently mounted filesystems
/proc/net/             # Network stack statistics
/proc/<PID>/           # Per-process subtree
/proc/<PID>/status     # Process state, memory, UIDs
/proc/<PID>/cmdline    # Full command line used to launch the process
/proc/<PID>/fd/        # Open file descriptors
/proc/<PID>/maps       # Memory map of the process
```

**Example — inspect a running process:**
```bash
cat /proc/$$/status       # Current shell's status
ls -la /proc/$$/fd        # Open file descriptors
cat /proc/sys/kernel/hostname   # Read system hostname via /proc
```

---

### `/sys` — Kernel & Device Subsystem Interface

Exposes the kernel's device model — hardware devices, drivers, and kernel subsystems — as a structured file tree (the *sysfs* virtual filesystem). More structured and organized than `/proc`.

```bash
/sys/class/             # Devices organized by class (net, block, input…)
/sys/class/net/         # Network interfaces
/sys/block/             # Block devices (disks)
/sys/bus/               # Buses (PCI, USB, platform…)
/sys/devices/           # Device tree mirroring physical topology
/sys/module/            # Loaded kernel modules and their parameters
/sys/kernel/            # Kernel internal state
/sys/power/             # Power management controls
```

**Example — read/write kernel parameters:**
```bash
cat /sys/class/net/eth0/speed        # NIC link speed (Mbps)
cat /sys/class/backlight/*/brightness  # Screen brightness
echo 200 > /sys/class/backlight/intel_backlight/brightness  # Adjust brightness
```

---

### `/dev` — Device Files

Contains *device nodes* — special files that represent hardware devices and virtual devices. Programs interact with hardware by reading/writing these files via standard I/O.

| Type | Examples | Description |
|---|---|---|
| Block devices | `/dev/sda`, `/dev/nvme0n1`, `/dev/loop0` | Disks and partitions — buffered I/O |
| Character devices | `/dev/tty`, `/dev/ttyUSB0`, `/dev/urandom` | Serial, terminals — unbuffered I/O |
| Pseudo-devices | `/dev/null`, `/dev/zero`, `/dev/full` | Virtual devices with special behaviors |
| Terminals | `/dev/pts/0`, `/dev/tty1` | Terminal sessions |

**Special pseudo-devices:**

```bash
# /dev/null — silently discards all input; reads return EOF
command > /dev/null 2>&1

# /dev/zero — returns infinite stream of null bytes
dd if=/dev/zero of=empty.img bs=1M count=100

# /dev/urandom — non-blocking cryptographic random bytes
head -c 16 /dev/urandom | xxd

# /dev/full — returns ENOSPC on write (testing disk-full conditions)
echo test > /dev/full  # → bash: echo: write error: No space left on device
```

Modern Linux uses **udev**, which dynamically populates `/dev` at runtime based on detected hardware — nothing here is static on disk.

---

## Other Notable Directories

| Directory | Purpose |
|---|---|
| `/boot` | Kernel images (`vmlinuz`), initrd, bootloader config (GRUB) |
| `/lib` | Shared libraries for `/bin` and `/sbin`; kernel modules in `/lib/modules` |
| `/tmp` | Temporary files; cleared on reboot; world-writable |
| `/run` | Runtime data for daemons since last boot (PID files, sockets) |
| `/mnt` | Temporary manual mount point for sysadmin use |
| `/media` | Auto-mount point for removable media (USB drives, CDs) |
| `/opt` | Optional/third-party self-contained application packages |
| `/srv` | Data served by the system (web root, FTP data) |

---

## Key Design Principles

**Separation of static and variable data** — `/usr` is designed to be mountable read-only and shareable across machines. `/var` holds everything that must be writable. This split allows network-booting thin clients that share a single `/usr` over NFS.

**Root filesystem minimalism** — The root partition should contain only what is needed to boot the system and mount other partitions. Everything else lives on separate filesystems that are mounted later in the boot process.

**Predictability** — Any compliant program can locate its configuration in `/etc`, its logs in `/var/log`, and system binaries in `/usr/bin` without distribution-specific knowledge.

---

## Quick Reference Cheatsheet

```bash
# Navigation
ls /              # List all top-level directories
man hier          # Read the official FHS man page

# /proc quick reads
cat /proc/cpuinfo | grep "model name" | head -1
free -h && cat /proc/meminfo | grep -E "MemTotal|MemAvailable"

# /sys device queries
ls /sys/class/net/                    # List network interfaces
cat /sys/block/sda/size               # Disk size in 512-byte sectors

# /dev interactions
lsblk                                  # List block devices
ls -la /dev/disk/by-id/               # Persistent disk identifiers
```

---

*Based on the Filesystem Hierarchy Standard 3.0. Behavior may vary slightly between Linux distributions.*