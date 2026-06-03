# Linux Distributions

A **Linux distribution (distro)** is a complete operating system built around the Linux kernel.

> **Formula:** Distro = Linux kernel + system tools + package manager + default software + configuration + release model

The kernel is the same across all distros, but everything around it defines the user experience, stability, and purpose of the system.

### Formula — Term Definitions

| Term | Definition | Example |
|---|---|---|
| **Linux kernel** | The core of the OS. Manages hardware (CPU, RAM, storage, devices), process scheduling, memory, and system calls. It's the bridge between software and hardware. Every distro shares the same kernel codebase, though versions differ. | Kernel 6.9 handles your Wi-Fi card, allocates RAM to Firefox, schedules processes |
| **System tools** | Essential low-level utilities that make the system usable: shell, init system, filesystem tools, network utilities, user management. Without these, the kernel has no interface. Usually sourced from GNU, BusyBox, or systemd projects. | `bash`, `systemd`, `coreutils` (ls, cp, cat…), `iproute2`, `util-linux` |
| **Package manager** | Software that installs, updates, removes, and resolves dependencies for programs. It fetches packages from remote repositories and keeps the system consistent. This is one of the biggest differentiators between distro families. | `apt` (Debian), `dnf` (Red Hat), `pacman` (Arch), `zypper` (SUSE) |
| **Default software** | The pre-installed applications that come with the distro: desktop environment, browser, text editor, file manager, terminal. Defines the out-of-the-box experience. Can always be changed after install. | GNOME + Firefox + Nautilus (Ubuntu), KDE Plasma + Dolphin (Manjaro) |
| **Configuration** | The set of default settings, file layouts, security policies, and system behavior choices made by the distro maintainers. Same software configured differently = very different systems. | SELinux enforcing mode (Fedora), `/etc/apt/sources.list` repos (Debian), default runlevel, firewall rules |
| **Release model** | The strategy for *when and how* updates are delivered. Determines how stable, current, or long-lived a system is. Affects whether you get the latest features immediately or tested, stable packages only. | Rolling (Arch — always latest), LTS (Ubuntu — stable for 5 years), Fixed (Fedora — new version every 6 months) |

---

## Key Idea: Why Distros Exist

Distros exist because:
- The Linux kernel alone is not usable directly by end users
- Different users need different goals:
  - **Stability** → servers, enterprise environments
  - **Cutting-edge features** → developers, early adopters
  - **Security tools** → pentesting, forensics
  - **Lightweight systems** → old hardware, embedded devices
  - **Privacy** → anonymity-focused workflows

So each distro is a different *packaging philosophy* of Linux.

---

## Distribution Families

Linux distros are grouped into families that share:
- Package manager
- System structure
- Configuration style
- Command patterns

Knowing the family helps you **transfer knowledge between distros** — learn one, understand many.

---

## 🟦 Debian Family

**Lineage:** Debian → Ubuntu → Linux Mint, Kali, Parrot OS, Pop!_OS, Elementary OS…

### Characteristics
| Property | Detail |
|---|---|
| Package manager | `apt` / `dpkg` |
| Package format | `.deb` |
| Release model | Stable (frozen) or rolling (Ubuntu LTS) |
| Init system | `systemd` |
| Focus | Stability, simplicity, large community |

### Why It Matters
- Most beginner tutorials use this family
- Huge documentation and community support
- Very large software repositories (50,000+ packages in Debian)
- Ubuntu is the most widely used Linux on cloud servers (AWS, GCP, Azure)

### Common Commands
```bash
sudo apt update               # Refresh package list
sudo apt upgrade -y           # Upgrade all installed packages
sudo apt install nginx        # Install a package
sudo apt remove nginx         # Remove a package
sudo apt autoremove           # Clean unused dependencies
sudo dpkg -i package.deb      # Install a local .deb file
sudo apt search keyword       # Search for packages
sudo apt show nginx           # Show package details
```

### Notable Distros
- **Debian** — The "grandfather"; rock-solid, used in servers and embedded systems
- **Ubuntu** — Most popular desktop/server Linux; backed by Canonical
- **Linux Mint** — Beginner-friendly; Windows-like feel; great for desktops
- **Kali Linux** — Penetration testing toolkit; pre-loaded with 600+ security tools
- **Parrot OS** — Lightweight alternative to Kali; also privacy-focused
- **Pop!_OS** — Made by System76; great GPU/developer support

---

## 🔴 Red Hat Family

**Lineage:** Red Hat Enterprise Linux (RHEL) → Fedora → CentOS, AlmaLinux, Rocky Linux…

### Characteristics
| Property | Detail |
|---|---|
| Package manager | `dnf` / `yum` (legacy) / `rpm` |
| Package format | `.rpm` |
| Release model | Stable (RHEL/Rocky) or semi-rolling (Fedora) |
| Init system | `systemd` |
| Focus | Enterprise, stability, long-term support |

### Why It Matters
- RHEL is the dominant enterprise Linux (banks, hospitals, government)
- Fedora is Red Hat's testing ground — innovations appear here first
- AlmaLinux/Rocky Linux are free RHEL rebuilds after CentOS was discontinued (2021)
- SELinux (Security-Enhanced Linux) is default — stronger security model

### Common Commands
```bash
sudo dnf update               # Update all packages
sudo dnf install nginx        # Install a package
sudo dnf remove nginx         # Remove a package
sudo dnf search keyword       # Search for packages
sudo rpm -ivh package.rpm     # Install a local .rpm file
sudo dnf group install "Development Tools"  # Install a package group
```

### Notable Distros
- **RHEL** — Gold standard for enterprise; paid support from Red Hat (IBM)
- **Fedora** — Cutting-edge; ships latest kernel and GNOME; 6-month release cycle
- **CentOS Stream** — Rolling preview of RHEL; upstream to RHEL
- **AlmaLinux** — Free, community RHEL clone; drop-in replacement
- **Rocky Linux** — Another RHEL clone; founded by CentOS co-founder

---

## 🟢 Arch Family

**Lineage:** Arch Linux → Manjaro, EndeavourOS, Garuda Linux…

### Characteristics
| Property | Detail |
|---|---|
| Package manager | `pacman` + `AUR helpers` (yay, paru) |
| Package format | `.pkg.tar.zst` |
| Release model | Rolling release (always up to date) |
| Init system | `systemd` |
| Focus | DIY, minimalism, cutting-edge, customization |

### Why It Matters
- You build the system from scratch — you control *everything*
- AUR (Arch User Repository) has 85,000+ community packages — widest selection
- The **Arch Wiki** is the best Linux documentation on the internet (used by all distro users)
- Rolling release = no major version upgrades, always current

### Common Commands
```bash
sudo pacman -Syu              # Full system upgrade
sudo pacman -S nginx          # Install a package
sudo pacman -R nginx          # Remove a package
sudo pacman -Ss keyword       # Search for packages
sudo pacman -Qi nginx         # Show installed package info
yay -S package-from-aur      # Install from AUR (requires yay)
```

### Notable Distros
- **Arch Linux** — Pure DIY; install from scratch via command line; maximum control
- **Manjaro** — Arch made easy; beginner-friendly; hardware detection built-in
- **EndeavourOS** — Near-pure Arch with a simple GUI installer
- **Garuda Linux** — Gaming/performance focused; beautiful BTRFS setup by default

---

## 🟡 SUSE Family

**Lineage:** SUSE → openSUSE Leap / openSUSE Tumbleweed → SLES…

### Characteristics
| Property | Detail |
|---|---|
| Package manager | `zypper` / `rpm` |
| Package format | `.rpm` |
| Release model | Stable (Leap) or rolling (Tumbleweed) |
| Init system | `systemd` |
| Focus | Enterprise, desktop, YaST configuration |

### Why It Matters
- **YaST** (Yet Another Setup Tool) — powerful GUI/TUI configuration center unique to SUSE
- Strong in European enterprise markets
- Tumbleweed is one of the most stable rolling-release distros

### Common Commands
```bash
sudo zypper refresh           # Refresh repositories
sudo zypper update            # Update all packages
sudo zypper install nginx     # Install a package
sudo zypper remove nginx      # Remove a package
sudo zypper search keyword    # Search for packages
```

---

## 🔵 Independent / Other Notable Distros

### Gentoo
- **Build from source** — every package is compiled on your machine
- Maximum optimization and control
- Package manager: `portage` (`emerge`)
- For advanced users; extremely educational

### Slackware
- Oldest actively maintained distro (1993)
- Minimal, UNIX-philosophy design
- No dependency resolution — pure simplicity

### Alpine Linux
- Ultra-lightweight (~5 MB base image)
- Used heavily in **Docker containers** and embedded systems
- Package manager: `apk`
- Uses `musl libc` instead of `glibc` — not compatible with all binaries

### NixOS
- Entirely declarative configuration (`/etc/nixos/configuration.nix`)
- Reproducible builds — same config = same system, always
- Atomic upgrades and rollbacks
- Steep learning curve; very powerful for DevOps/infra work

---

## Choosing a Distro: Quick Reference

| Use Case | Recommended Distro |
|---|---|
| First-time Linux user | Linux Mint, Ubuntu |
| Developer workstation | Fedora, Pop!_OS, Ubuntu |
| Penetration testing | Kali Linux, Parrot OS |
| Home server / NAS | Debian, Ubuntu Server |
| Enterprise server | RHEL, AlmaLinux, Rocky Linux |
| Maximum customization | Arch Linux |
| Gaming | Manjaro, Garuda, Pop!_OS |
| Old/low-spec hardware | Debian, Alpine, antiX |
| Docker/containers | Alpine Linux |
| Reproducible infra | NixOS |
| Learning Linux deeply | Arch, Gentoo, LFS |

---

## Release Models Explained

| Model | Description | Examples |
|---|---|---|
| **Fixed / Point release** | New version every X months; stable snapshot | Ubuntu LTS, Debian, Fedora |
| **Long-Term Support (LTS)** | Extended security updates (5–10 years) | Ubuntu LTS, RHEL, Debian |
| **Rolling release** | Continuous updates; no "versions" | Arch, Tumbleweed, Gentoo |
| **Semi-rolling** | Rolling with some stability checkpoints | Fedora, CentOS Stream |

---

## Init Systems

The **init system** is the first process started by the kernel (PID 1). It manages system startup and services.

| Init System | Used By | Commands |
|---|---|---|
| `systemd` | Most modern distros | `systemctl start/stop/enable nginx` |
| `OpenRC` | Alpine, Gentoo | `rc-service nginx start` |
| `SysVinit` | Slackware, Devuan | `service nginx start` |
| `runit` | Void Linux | `sv start nginx` |

---

## Filesystem Hierarchy (Universal Across Distros)

```
/           Root of the filesystem
├── bin/    Essential binaries (ls, cp, cat…)
├── boot/   Kernel and bootloader files
├── dev/    Device files
├── etc/    System configuration files
├── home/   User home directories
├── lib/    Shared libraries
├── media/  Mounted removable media
├── mnt/    Temporary mount points
├── opt/    Optional/third-party software
├── proc/   Virtual filesystem for process info
├── root/   Root user's home directory
├── run/    Runtime data (since last boot)
├── srv/    Data for services (web, FTP…)
├── sys/    Virtual filesystem for kernel/hardware info
├── tmp/    Temporary files (cleared on reboot)
├── usr/    User programs and data
└── var/    Variable data (logs, databases, mail…)
```

---

## Summary

```
Linux Ecosystem
│
├── Debian Family     → apt/dpkg    → stability, beginners, cloud
├── Red Hat Family    → dnf/rpm     → enterprise, SELinux, Fedora innovation
├── Arch Family       → pacman/AUR  → rolling, DIY, cutting-edge
├── SUSE Family       → zypper      → enterprise EU, YaST
└── Independents      → varies      → specialized use cases
```

> **Key takeaway:** The kernel is universal. What differs is philosophy — how software is packaged, updated, configured, and who the target user is. Master one family and you can adapt to any distro.