# The Linux Filesystem: A Directory-by-Directory Guide

Every Linux distribution organizes itself around the same basic skeleton: a single root directory (`/`) that branches into a standard set of subdirectories. This layout is formalized by the **Filesystem Hierarchy Standard (FHS)**, and once you understand it, any Linux system — from a Raspberry Pi to a data center server — becomes easy to navigate.

This guide walks through the major directories, what lives in each, and why.

---

## Quick Reference Table

| Directory | Purpose | Example Contents |
|---|---|---|
| `/etc` | System-wide configuration | `/etc/ssh/sshd_config`, `/etc/fstab` |
| `/var` | Variable, frequently changing data | Logs, mail spools, caches |
| `/usr` | Shared, read-only user programs and data | Installed apps, libraries, docs |
| `/bin`, `/sbin` | Essential binaries | `ls`, `cp`, `mount` |
| `/tmp` | Temporary files | Scratch space, cleared on reboot |
| `/boot` | Boot loader files | Kernel images, initrd |
| `/opt` | Optional/third-party software | Vendor-packaged apps |
| `/root` | Root user's home directory | Root's personal files |
| `/home` | Regular users' home directories | `/home/alice`, `/home/bob` |
| `/dev` | Device nodes | `/dev/sda`, `/dev/null` |
| `/proc`, `/sys` | Kernel and process info (virtual) | CPU info, running process data |
| `/lib` | Shared libraries | `.so` files needed by `/bin`, `/sbin` |
| `/mnt`, `/media` | Mount points | External drives, network shares |
| `/srv` | Service data | Web server files, FTP data |

---

## `/etc` — Configuration Files

`/etc` (commonly read as "et cetera," though many treat it as "editable text configuration") is where the **system-wide configuration files** live. If a program needs settings that apply to the whole machine rather than a single user, they belong here.

**What you'll find:**
- `/etc/passwd` and `/etc/shadow` — user account definitions
- `/etc/fstab` — filesystem mount definitions
- `/etc/hosts` — static hostname-to-IP mappings
- `/etc/ssh/sshd_config` — SSH daemon configuration
- `/etc/nginx/`, `/etc/apache2/` — web server configs

**Key trait:** Files here are almost always plain text and meant to be hand-edited (with appropriate privileges). Nothing in `/etc` should be a binary or an executable — it's purely configuration.

> **Rule of thumb:** If you're tweaking *how* a program behaves system-wide, you're probably editing something in `/etc`.

---

## `/var` — Variable Data

`/var` holds data that's expected to **grow, shrink, or change** while the system runs. Unlike `/etc`, which is mostly static, `/var` is in constant flux.

**What you'll find:**
- `/var/log/` — system and application logs (`syslog`, `auth.log`, `nginx/access.log`)
- `/var/cache/` — cached data from applications (e.g., package manager caches)
- `/var/spool/` — queued data awaiting processing (print jobs, mail)
- `/var/lib/` — persistent application state (databases like MySQL often store data here)
- `/var/tmp/` — temporary files that should *survive* a reboot, unlike `/tmp`

**Key trait:** If a directory's contents are actively written to during normal operation — especially logs and caches — it almost certainly lives under `/var`.

> **Rule of thumb:** Disk space disappearing mysteriously? Check `/var/log` first; runaway logs are a classic culprit.

---

## `/usr` — User System Resources

Despite the name, `/usr` doesn't mean "user" in the personal sense — historically it stood for **"Unix System Resources."** It's the largest directory on most systems and contains the bulk of installed software, libraries, and documentation.

**What you'll find:**
- `/usr/bin/` — non-essential user command binaries (most installed programs)
- `/usr/sbin/` — non-essential system administration binaries
- `/usr/lib/` — libraries for programs in `/usr/bin` and `/usr/sbin`
- `/usr/share/` — architecture-independent data: docs, icons, man pages
- `/usr/local/` — software compiled/installed manually by the admin, kept separate from package-manager-installed software

**Key trait:** `/usr` is meant to be **shareable and read-only** in principle — on some setups it can even be mounted read-only or shared over a network between multiple machines, since it doesn't contain host-specific configuration.

> **Rule of thumb:** When you `apt install` or `dnf install` a typical application, most of its files land somewhere under `/usr`.

---

## `/tmp` — Temporary Files

`/tmp` is shared scratch space for any program or user that needs to write short-lived files. Many distributions clear `/tmp` on every reboot (some clear it on a timer, like every few days), so **nothing important should be stored here long-term**.

**What you'll find:**
- Lock files
- Session data
- Temporary downloads or extraction folders used by installers

**Key trait:** World-writable (with sticky-bit protections so users can't delete each other's files) and explicitly impermanent.

---

## `/boot` — Boot Loader Files

`/boot` contains everything the system needs in the earliest moments of startup, **before** the full filesystem and OS are loaded.

**What you'll find:**
- The Linux kernel image (`vmlinuz-*`)
- The initial RAM disk (`initrd.img-*` or `initramfs-*`)
- Boot loader configuration (e.g., GRUB's `grub.cfg`)

**Key trait:** This directory is often placed on its own small partition, especially on systems with specific boot requirements (like UEFI). Tampering here can render a system unbootable, so changes are typically made through dedicated tools (`update-grub`, `grub-mkconfig`) rather than by hand.

---

## `/opt` — Optional Software

`/opt` is reserved for **self-contained, third-party software packages** that don't follow the standard distribution-managed layout. Think large commercial applications or vendor-provided software bundles.

**What you'll find:**
- `/opt/google/chrome/`
- `/opt/vendor-app/` with its own `bin/`, `lib/`, and `etc/` subfolders bundled together

**Key trait:** Software in `/opt` is usually installed as a single self-sufficient directory tree, making it easy to add or remove without touching the rest of the system.

---

## `/root` — The Root User's Home

Not to be confused with the root directory `/`, this is simply the **home directory for the root (superuser) account** — the equivalent of `/home/username` for a regular user.

**What you'll find:**
- Root's personal shell config (`.bashrc`, `.profile`)
- Any files root has downloaded or created directly

**Key trait:** It's kept separate from `/home` so that the root account remains accessible even if `/home` is on a separate partition that fails to mount.

---

## Honorable Mentions

A few other directories worth knowing:

- **`/home`** — Home directories for regular (non-root) users; each user gets a subdirectory like `/home/maria`.
- **`/dev`** — Device nodes representing hardware and virtual devices (`/dev/sda` for a disk, `/dev/null` for discarding output).
- **`/proc`** and **`/sys`** — Virtual filesystems generated by the kernel on the fly, exposing live information about processes, hardware, and kernel parameters. Nothing here is stored on disk.
- **`/lib`** (and `/lib64`) — Essential shared libraries needed by binaries in `/bin` and `/sbin`, used during early boot before `/usr` may be available.
- **`/mnt`** and **`/media`** — Conventional mount points; `/mnt` for temporary manual mounts, `/media` for removable media like USB drives.
- **`/srv`** — Data served by the system, such as files for a web server or FTP service.

---

## Putting It All Together

A simple way to remember the philosophy behind this layout:

- **Static vs. variable:** `/etc` (static config) vs. `/var` (changing data)
- **Essential vs. optional:** `/bin`/`/sbin` (must-have for boot) vs. `/usr/bin` (everything else) vs. `/opt` (third-party extras)
- **System vs. personal:** `/root` and `/home` (people's files) vs. everything else (the OS itself)
- **Real vs. virtual:** `/dev`, `/proc`, `/sys` (kernel-generated views) vs. actual stored files elsewhere

Once these distinctions click, the Linux directory tree stops looking arbitrary and starts looking like what it is: a carefully organized system where every file has a logical home.