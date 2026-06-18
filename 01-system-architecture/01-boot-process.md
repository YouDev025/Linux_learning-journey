# Linux Boot Process

> A complete reference tracking the Linux boot sequence — from the moment power is applied to the firmware, through the bootloader, kernel initialization, and finally the login prompt.

---

## Table of Contents

1. [Overview: The Boot Sequence at a Glance](#1-overview)
2. [Firmware Layer: BIOS vs UEFI](#2-firmware)
3. [Disk Partitioning: MBR vs GPT](#3-disk-partitioning)
4. [Bootloaders](#4-bootloaders)
5. [GRUB2 In Depth](#5-grub2)
6. [Kernel Loading](#6-kernel-loading)
7. [initramfs / initrd](#7-initramfs)
8. [The Init System](#8-init-system)
9. [systemd Targets](#9-systemd-targets)
10. [Login & Getty](#10-login)
11. [Boot Diagnostics & Troubleshooting](#11-diagnostics)
12. [Reference Summary](#12-reference)

---

## 1. Overview

The Linux boot sequence is a **layered pipeline**. Each stage hands off control to the next:

```
Power On
   │
   ▼
Firmware (BIOS / UEFI)        — hardware self-test, locate boot device
   │
   ▼
Bootloader Stage 1             — tiny code in MBR or EFI partition
   │
   ▼
Bootloader Stage 2 (GRUB)      — presents menu, loads kernel + initramfs
   │
   ▼
Kernel (vmlinuz)               — decompresses, initialises hardware
   │
   ▼
initramfs                      — temporary root FS, mounts real root
   │
   ▼
Init System (systemd / SysV)   — starts all services
   │
   ▼
Login (getty / display manager)
```

Each layer is independent and replaceable; understanding them separately is key to diagnosing failures.

---

## 2. Firmware Layer: BIOS vs UEFI

### 2.1 BIOS (Basic Input/Output System)

The original PC firmware standard, dating from the early 1980s.

**Boot flow:**
1. CPU executes the reset vector at physical address `0xFFFFFFF0`.
2. Firmware runs **POST** (Power-On Self Test) — checks RAM, CPU, and basic peripherals.
3. Scans configured boot devices in order (disk, USB, network…).
4. Reads the first 512 bytes of the chosen disk — the **MBR** (Master Boot Record).
5. Jumps to the 446-byte executable code inside the MBR.

**Key limitations:**
- 16-bit real-mode execution during POST.
- Maximum addressable disk size: **2 TiB** (due to 32-bit LBA in MBR).
- No native support for Secure Boot.
- No built-in network or filesystem drivers.
- Single-stage "read 512 bytes and jump" — very primitive handoff.

### 2.2 UEFI (Unified Extensible Firmware Interface)

Modern replacement for BIOS, standardised by the UEFI Forum.

**Boot flow:**
1. Security (SEC) phase — initial CPU and cache-as-RAM setup.
2. Pre-EFI Initialisation (PEI) — memory controller init.
3. Driver eXecution Environment (DXE) — loads EFI drivers.
4. Boot Device Selection (BDS) — reads **NVRAM boot entries** (not just disk order).
5. Loads an EFI application (e.g. `\EFI\ubuntu\grubx64.efi`) from the **ESP**.
6. That EFI application takes over (usually a bootloader).

**Key advantages over BIOS:**

| Feature | BIOS | UEFI |
|---|---|---|
| Disk size limit | 2 TiB (MBR) | 9.4 ZiB (GPT) |
| Boot mode | 16-bit real mode | 32/64-bit protected |
| Secure Boot | ✗ | ✓ |
| Network boot drivers | Vendor-specific | Standard (PXE via EFI) |
| Boot entries stored | Disk-scan order | NVRAM variables |
| Shell / diagnostics | ✗ | Built-in EFI shell |

**EFI System Partition (ESP):**

A FAT32 partition (typically 100–550 MiB) at the start of the disk, flagged with GUID `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`. UEFI firmware can read this natively. All bootloader EFI binaries live here.

```
/boot/efi/
├── EFI/
│   ├── BOOT/
│   │   └── BOOTX64.EFI        # fallback loader
│   ├── ubuntu/
│   │   ├── grubx64.efi        # GRUB EFI binary
│   │   └── shimx64.efi        # Secure Boot shim
│   └── Microsoft/             # may coexist on dual-boot
```

**Secure Boot:**

A UEFI feature that verifies digital signatures on EFI binaries before execution. The chain is:

```
UEFI firmware (Platform Key)
   └── Key Exchange Key (KEK)
         └── Signature Database (db)
               └── shim.efi (signed by Microsoft)
                     └── grub.efi (signed by distro)
                           └── kernel (signed by distro)
```

Secure Boot can be disabled in the UEFI setup utility; it must be disabled to boot unsigned kernels or custom builds.

---

## 3. Disk Partitioning: MBR vs GPT

The partition table format is tightly coupled to firmware type.

### 3.1 MBR (Master Boot Record)

Located in the first 512 bytes of a disk:

```
Offset 0–445   : Bootstrap code (executed by BIOS)
Offset 446–461 : Partition entry 1
Offset 462–477 : Partition entry 2
Offset 478–493 : Partition entry 3
Offset 494–509 : Partition entry 4
Offset 510–511 : Boot signature (0x55 0xAA)
```

Limitations: maximum 4 primary partitions, maximum disk size 2 TiB.

### 3.2 GPT (GUID Partition Table)

Used with UEFI. Stores the partition table in the first 34 sectors and mirrors it at the end of the disk (backup GPT). Supports up to 128 partitions by default, and disks up to 9.4 ZiB.

On GPT disks booted via BIOS, a small (1 MiB) **BIOS Boot Partition** (type `EF02`) is needed to hold GRUB stage 2, since there is no MBR gap.

---

## 4. Bootloaders

A bootloader bridges firmware and the operating system kernel.

**Two-stage concept:**

Stage 1 is small enough to fit in the MBR boot code (446 bytes) or an EFI binary. Its only job is to find and load Stage 2, which is a full-featured program capable of reading filesystems, presenting menus, and loading kernels.

**Common Linux bootloaders:**

| Bootloader | Use Case |
|---|---|
| **GRUB 2** | Universal; most Linux distributions |
| **systemd-boot** | Minimalist UEFI-only; popular on Arch, Fedora |
| **SYSLINUX / ISOLINUX** | USB/CD live images |
| **U-Boot** | Embedded systems (ARM, RISC-V) |
| **LILO** | Legacy; historically significant, now obsolete |

---

## 5. GRUB2 In Depth

GRUB 2 (GRand Unified Bootloader version 2) is the standard bootloader on most Linux distributions.

### 5.1 Directory Structure

```
/boot/grub/
├── grub.cfg              # generated config (do not edit manually)
├── grubenv               # persistent variables (saved entries, etc.)
├── fonts/
│   └── unicode.pf2
├── i386-pc/              # BIOS modules
│   ├── core.img
│   └── *.mod
└── x86_64-efi/           # EFI modules
    └── *.mod

/etc/grub.d/              # scripts that build grub.cfg
├── 00_header
├── 05_debian_theme
├── 10_linux             # detects installed kernels
├── 20_linux_xen
├── 30_os-prober         # detects other OSes
└── 40_custom            # user additions

/etc/default/grub         # user-facing configuration variables
```

### 5.2 Key Configuration Variables (`/etc/default/grub`)

```bash
# Timeout in seconds before default entry boots; -1 = wait forever
GRUB_TIMEOUT=5

# Default menu entry (0-indexed integer, or "saved", or entry title)
GRUB_DEFAULT=0

# Kernel parameters appended to every Linux entry
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"

# Kernel parameters for all entries (including recovery)
GRUB_CMDLINE_LINUX=""

# Disable os-prober (detects Windows etc.) for security or speed
GRUB_DISABLE_OS_PROBER=false

# Disable the graphical terminal
GRUB_TERMINAL=console

# Resolution for GRUB menu (UEFI GOP mode)
GRUB_GFXMODE=1920x1080x32
```

After editing, always regenerate:

```bash
sudo update-grub           # Debian/Ubuntu
sudo grub2-mkconfig -o /boot/grub2/grub.cfg   # RHEL/Fedora
```

### 5.3 Common Kernel Parameters

Parameters passed on the `linux` line control kernel behaviour:

| Parameter | Effect |
|---|---|
| `quiet` | Suppress most kernel log messages during boot |
| `splash` | Show graphical splash screen |
| `ro` | Mount root read-only initially (standard) |
| `rw` | Mount root read-write (emergency/rescue) |
| `single` / `1` | Boot into single-user (rescue) mode |
| `init=/bin/bash` | Use bash as PID 1 (emergency shell) |
| `nomodeset` | Disable kernel mode-setting (GPU fallback) |
| `systemd.unit=rescue.target` | Boot to rescue target |
| `rd.break` | Drop to initramfs shell before mounting root |
| `resume=/dev/sdX` | Specify swap partition for hibernate resume |
| `root=/dev/sda1` | Override root device |
| `rootflags=subvol=@` | Pass options to root filesystem (e.g. Btrfs) |

### 5.4 GRUB2 Shell

If the menu cannot find a configuration, GRUB drops to a rescue shell. Useful commands:

```grub
ls                          # list devices and partitions
ls (hd0,gpt2)/              # list files on a partition
set root=(hd0,gpt2)         # set root device
linux /boot/vmlinuz root=/dev/sda2 ro
initrd /boot/initrd.img
boot                        # boot with the above settings
```

### 5.5 GRUB Installation

```bash
# Install GRUB to MBR of /dev/sda (BIOS)
grub-install /dev/sda

# Install GRUB for UEFI (ESP must be mounted at /boot/efi)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
```

---

## 6. Kernel Loading

### 6.1 The Kernel Image

The kernel is stored as a compressed executable, typically at `/boot/vmlinuz-<version>`.

| Filename Convention | Meaning |
|---|---|
| `vmlinuz` | Compressed kernel (z = zlib/gzip/lzma/zstd) |
| `vmlinux` | Uncompressed ELF kernel (build artifact) |
| `bzImage` | "big zImage" — the standard x86 compressed format |
| `Image` / `Image.gz` | ARM / ARM64 kernel images |

The kernel image is **self-decompressing**: the first few hundred bytes are a small decompressor stub that unpacks the real kernel into RAM and jumps to its entry point.

### 6.2 Kernel Initialisation Steps

Once decompressed, the kernel executes in this order:

1. **Decompress** itself into high memory.
2. Initialise the **memory allocator** (early bootmem / memblock).
3. Set up **interrupt descriptor table** (IDT) and GDT.
4. Detect and initialise **CPUs** (SMP bringup for multi-core).
5. Initialise the **page allocator** (buddy system).
6. Mount the **initramfs** as the initial root filesystem.
7. Start **kernel threads** (kthreadd, migration, etc.).
8. Probe and initialise **devices** via driver subsystem.
9. Execute `/init` (or `/sbin/init`) inside the initramfs — becoming PID 1.

### 6.3 Kernel Ring Buffer

Boot messages are stored in the kernel ring buffer, readable with:

```bash
dmesg                        # full ring buffer
dmesg | grep -i error        # filter for errors
dmesg --level=err,warn       # only errors and warnings
journalctl -k                # kernel messages via systemd-journald
```

---

## 7. initramfs

### 7.1 What Is initramfs?

**initramfs** (initial RAM filesystem) is a small, temporary root filesystem loaded into memory by the bootloader alongside the kernel. It exists to solve a chicken-and-egg problem: the kernel needs drivers to mount the real root filesystem, but those drivers may themselves reside on the root filesystem.

It replaced the older **initrd** (initial RAM disk) format, which used a loop-mounted ext2 image. initramfs uses **cpio** archive format, decompressed directly into a `tmpfs`.

### 7.2 Contents

```
/
├── bin/                  # BusyBox or minimal utilities
├── dev/
│   ├── console
│   └── null
├── etc/
├── init -> /lib/systemd/systemd   # or a custom init script
├── lib/
│   └── modules/          # kernel modules (LUKS, LVM, RAID, filesystem drivers)
├── lib/udev/
├── scripts/              # hook scripts (Debian) or dracut modules (RHEL)
├── sbin/
└── sys/
```

### 7.3 The initramfs Boot Flow

1. Kernel mounts the initramfs as `/` (tmpfs).
2. Kernel spawns `/init` as PID 1.
3. `init` script (or systemd in initramfs mode):
   - Loads necessary kernel modules.
   - Assembles software RAID (`mdadm`), if needed.
   - Activates LVM volumes (`lvm vgchange`), if needed.
   - Unlocks LUKS encrypted volumes (`cryptsetup`), if needed.
   - Mounts the **real root filesystem**.
   - Performs `switch_root` or `pivot_root` — the new root becomes `/`, and initramfs memory is freed.
4. Kernel executes `/sbin/init` on the real root — PID 1 hands off.

### 7.4 Managing initramfs

```bash
# Rebuild for current kernel (Debian/Ubuntu)
update-initramfs -u

# Rebuild for specific kernel version
update-initramfs -u -k 6.5.0-27-generic

# Rebuild all kernels
update-initramfs -u -k all

# Inspect contents
lsinitramfs /boot/initrd.img-$(uname -r)

# Extract to directory
mkdir /tmp/initramfs-inspect
cd /tmp/initramfs-inspect
zcat /boot/initrd.img-$(uname -r) | cpio -idmv
```

**Dracut** (used on RHEL/Fedora):

```bash
dracut --force                            # rebuild for running kernel
dracut /boot/initramfs-$(uname -r).img $(uname -r)
lsinitrd /boot/initramfs-$(uname -r).img  # list contents
```

### 7.5 Dropping to an initramfs Shell

Add `rd.break` (dracut) or `break` (Debian initramfs-tools) to the kernel command line in GRUB. Useful for:

- Resetting a forgotten root password.
- Debugging mount failures.
- Unlocking encrypted volumes manually.

```bash
# After dropping to initramfs shell
mount -o remount,rw /sysroot   # re-mount future root as read-write
chroot /sysroot                # change root into the real system
passwd root                    # reset password
exit
```

---

## 8. The Init System

PID 1 is the first process on the real root filesystem. It is the ancestor of all other processes and is responsible for bringing the system to a usable state.

### 8.1 SysV init (Legacy)

The traditional Unix init, still used on some embedded systems.

- Configuration in `/etc/inittab`.
- Services managed by shell scripts in `/etc/init.d/`.
- Boot runlevels (0–6) control which services start.
- Sequential startup: services start one-by-one.

**Runlevels:**

| Runlevel | Meaning |
|---|---|
| 0 | Halt |
| 1 | Single-user / maintenance |
| 2 | Multi-user (no networking on some distros) |
| 3 | Multi-user with networking (no GUI) |
| 4 | Unused / user-defined |
| 5 | Multi-user with GUI |
| 6 | Reboot |

```bash
# Check runlevel
runlevel

# Change runlevel
telinit 3
```

### 8.2 Upstart (Deprecated)

Event-driven init used by Ubuntu 6.10–14.10 and RHEL 6. Replaced by systemd. Notable for parallel service startup based on events rather than a fixed sequence.

### 8.3 systemd (Modern Standard)

systemd is the dominant init system on all major Linux distributions since ~2014. It provides:

- **Parallel service startup** — all services without hard dependencies start simultaneously.
- **Socket activation** — services are started on-demand when a socket receives a connection.
- **D-Bus activation** — services started when a D-Bus name is requested.
- **Cgroups integration** — every service is placed in its own cgroup for resource control and clean shutdown.
- **Journal** (`journald`) — structured binary log, replacing syslog.
- **Declarative unit files** — replace shell scripts.

**Key directories:**

```
/lib/systemd/system/       # unit files shipped by packages (do not edit)
/etc/systemd/system/       # local overrides and custom units (edit here)
/run/systemd/system/       # runtime-generated units
~/.config/systemd/user/    # user-session units
```

**Unit types:**

| Suffix | Type | Purpose |
|---|---|---|
| `.service` | Service | A daemon or one-shot process |
| `.target` | Target | Grouping milestone (replaces runlevels) |
| `.socket` | Socket | Socket activation |
| `.timer` | Timer | Scheduled activation (replaces cron) |
| `.mount` | Mount | Filesystem mount point |
| `.automount` | Automount | Lazy mount on access |
| `.device` | Device | udev device node |
| `.slice` | Slice | cgroup resource hierarchy |
| `.path` | Path | File/directory watch activation |

---

## 9. systemd Targets

Targets are the systemd equivalent of SysV runlevels. They group units that should be active together.

### 9.1 Standard Targets

| Target | SysV Equivalent | Description |
|---|---|---|
| `poweroff.target` | 0 | Power off |
| `rescue.target` | 1 | Single-user rescue shell |
| `multi-user.target` | 3 | Multi-user, no GUI |
| `graphical.target` | 5 | Multi-user with GUI |
| `reboot.target` | 6 | Reboot |
| `emergency.target` | — | Minimal shell, root filesystem read-only |
| `default.target` | — | Symlink to the default (usually `graphical.target`) |

### 9.2 Boot Target Chain

```
sysinit.target
    │
    ▼
basic.target
    │
    ├── multi-user.target
    │       │
    │       └── graphical.target
    │
    └── rescue.target / emergency.target
```

`sysinit.target` handles: mounting `/proc`, `/sys`, `/dev`; loading kernel modules; starting `udev`; setting the system clock.

`basic.target` handles: socket setup, timers, and other basic infrastructure.

### 9.3 Essential systemctl Commands

```bash
# View boot status and target
systemctl get-default                   # show default target
systemctl set-default multi-user.target # change default

# Navigate targets
systemctl isolate rescue.target         # switch to rescue (now)
systemctl reboot
systemctl poweroff
systemctl suspend
systemctl hibernate

# Service management
systemctl status sshd
systemctl start sshd
systemctl stop sshd
systemctl restart sshd
systemctl enable sshd     # enable at boot
systemctl disable sshd
systemctl mask sshd       # prevent any start (even manual)

# Inspect boot
systemctl list-units --failed
systemctl list-units --type=service
systemd-analyze                         # total boot time
systemd-analyze blame                   # time per unit
systemd-analyze critical-chain          # critical path
```

### 9.4 Unit File Anatomy

```ini
# /etc/systemd/system/myapp.service

[Unit]
Description=My Application
Documentation=https://example.com/docs
After=network.target           # start after network is up
Requires=postgresql.service    # hard dependency
Wants=redis.service            # soft dependency

[Service]
Type=simple                    # simple | forking | oneshot | notify | dbus
ExecStart=/usr/bin/myapp --config /etc/myapp.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
User=myapp
Group=myapp
WorkingDirectory=/var/lib/myapp
EnvironmentFile=/etc/myapp/env

[Install]
WantedBy=multi-user.target     # pulled in by this target when enabled
```

**Service types:**

| Type | Behaviour |
|---|---|
| `simple` | PID in ExecStart is the main process |
| `forking` | Process forks; parent exits; child is the daemon |
| `oneshot` | Short-lived; systemd waits for it to exit |
| `notify` | Process sends `sd_notify()` when ready |
| `dbus` | Ready when D-Bus name acquired |
| `idle` | Like simple, but waits until job queue is empty |

---

## 10. Login & Getty

### 10.1 getty

**getty** ("get tty") is the process that manages a virtual console, prints a login prompt, and hands off to `login` after the user types their username.

```
systemd
   └── getty@tty1.service
         └── /sbin/agetty tty1
               └── /bin/login
                     └── /bin/bash (user shell)
```

The template unit `getty@.service` is instantiated for each virtual terminal (tty1–tty6 by default).

```bash
# Check getty status
systemctl status getty@tty1.service

# Activate more consoles
systemctl start getty@tty7.service
```

### 10.2 Display Managers (GUI Login)

For graphical systems, a **display manager** (DM) replaces getty on the primary display:

| Display Manager | Default On |
|---|---|
| GDM | GNOME / Fedora / Ubuntu |
| SDDM | KDE Plasma |
| LightDM | Ubuntu (older), Xubuntu, LXDE |
| ly | Minimal TUI DM |

```bash
systemctl status gdm           # check display manager
systemctl enable gdm           # set to start at boot
```

### 10.3 PAM (Pluggable Authentication Modules)

The `login` process uses PAM to authenticate users. PAM configuration is in `/etc/pam.d/`. It handles:

- Password verification (`pam_unix.so`).
- LDAP / AD authentication (`pam_ldap.so`).
- Account expiry, access restrictions.
- Session setup (home directory creation, environment).

---

## 11. Boot Diagnostics & Troubleshooting

### 11.1 Analysing Boot Time

```bash
systemd-analyze                         # wall time: firmware + loader + kernel + userspace
systemd-analyze blame                   # slowest units
systemd-analyze critical-chain          # bottleneck chain
systemd-analyze plot > boot.svg         # SVG timeline
```

### 11.2 Reading Boot Logs

```bash
journalctl -b                           # current boot
journalctl -b -1                        # previous boot
journalctl -b -2                        # two boots ago
journalctl -b --priority=err            # errors only
journalctl -k -b                        # kernel messages this boot
journalctl -u sshd -b                   # unit-specific
```

### 11.3 Common Boot Failure Scenarios

**Scenario 1: Dropped to emergency/rescue target**

Cause: Filesystem in `/etc/fstab` failed to mount.

```bash
journalctl -xb                          # look for mount errors
mount -o remount,rw /                   # remount root read-write
nano /etc/fstab                         # fix the bad entry
systemctl daemon-reload
exit                                    # retry boot
```

**Scenario 2: GRUB rescue prompt**

Cause: GRUB cannot find its files (broken install, moved partition).

```grub
ls                                      # find your partition
ls (hd0,gpt2)/boot/grub/               # confirm grub files
set prefix=(hd0,gpt2)/boot/grub
insmod normal
normal
```

After booting, reinstall GRUB:

```bash
grub-install /dev/sda
update-grub
```

**Scenario 3: Kernel panic — not syncing: VFS: Unable to mount root**

Cause: Root device not found, wrong UUID in GRUB, or missing driver in initramfs.

- Edit GRUB entry at boot: press `e`, correct `root=` parameter.
- After booting: verify `blkid` output matches `/etc/fstab` and `grub.cfg`.
- Rebuild initramfs with missing module.

**Scenario 4: systemd unit dependency cycle**

```bash
systemd-analyze verify /etc/systemd/system/myunit.service
journalctl -b | grep "Found ordering cycle"
```

### 11.4 Rescue Without Booting

Boot from a live USB, then chroot into the broken system:

```bash
mount /dev/sda2 /mnt                    # mount root partition
mount /dev/sda1 /mnt/boot/efi          # mount ESP (UEFI)
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt
# now you're inside the broken system
update-grub
update-initramfs -u
exit
umount -R /mnt
reboot
```

---

## 12. Reference Summary

### Boot Sequence Cheat Sheet

```
POST / UEFI SEC/PEI/DXE
  ↓
Read ESP / MBR
  ↓
GRUB Stage 1 (MBR or EFI binary)
  ↓
GRUB Stage 2 (reads /boot/grub/grub.cfg)
  ↓
Load vmlinuz + initrd.img into RAM
  ↓
Kernel decompresses, initialises hardware
  ↓
initramfs /init runs: modules, LUKS, LVM, RAID
  ↓
switch_root to real /
  ↓
systemd (PID 1) reads unit files
  ↓
sysinit.target → basic.target → multi-user.target → graphical.target
  ↓
getty / display manager → login → user shell
```

### Key Files

| File | Purpose |
|---|---|
| `/etc/default/grub` | GRUB user configuration |
| `/boot/grub/grub.cfg` | Generated GRUB menu (do not edit directly) |
| `/etc/grub.d/40_custom` | Custom GRUB menu entries |
| `/boot/vmlinuz-*` | Compressed kernel images |
| `/boot/initrd.img-*` | initramfs archives |
| `/etc/fstab` | Filesystem mount table |
| `/etc/systemd/system/` | Custom systemd unit files |
| `/lib/systemd/system/` | Package-provided unit files |
| `/etc/systemd/system/default.target` | Symlink to default boot target |

### Key Commands

```bash
# GRUB
update-grub                             # rebuild grub.cfg
grub-install /dev/sda                   # reinstall GRUB (BIOS)

# initramfs
update-initramfs -u                     # rebuild initramfs
lsinitramfs /boot/initrd.img-$(uname -r)

# systemd
systemd-analyze blame                   # boot performance
journalctl -b                           # this boot's logs
systemctl list-units --failed           # failed units
systemctl get-default                   # current default target

# Kernel / dmesg
dmesg | grep -i error
uname -r                                # running kernel version
ls /boot/vmlinuz-*                      # available kernels
```

---

*Document covers the x86/x86-64 platform unless noted. ARM boot flow differs at the firmware and bootloader stages but shares the kernel, initramfs, and init layers.*