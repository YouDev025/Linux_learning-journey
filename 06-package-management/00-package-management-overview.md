# Package Management Overview

A reference guide to how Linux distributions package, distribute, and update software — covering package formats, repositories, dependency resolution, and security patching.

---

## 📦 What a Package Manager Does

A **package manager** automates installing, updating, configuring, and removing software, replacing the old approach of manually downloading and compiling source code. It handles four core responsibilities:

1. **Fetching** software from trusted sources (repositories)
2. **Resolving dependencies** — ensuring everything a package needs is also installed
3. **Verifying integrity** — checking cryptographic signatures so packages haven't been tampered with
4. **Tracking installed state** — so packages can be cleanly updated or removed later

Without a package manager, you'd be responsible for manually tracking every shared library, version conflict, and configuration file a piece of software touches — across every program on the system.

---

## 🗂️ Package Formats: `.deb` vs `.rpm`

The two dominant package formats trace back to different Linux distribution families, and most distros use one or the other.

| | `.deb` | `.rpm` |
|---|---|---|
| **Origin** | Debian | Red Hat |
| **Used by** | Debian, Ubuntu, Linux Mint, and derivatives | RHEL, Fedora, CentOS, openSUSE, and derivatives |
| **Low-level tool** | `dpkg` | `rpm` |
| **High-level tool** | `apt` / `apt-get` | `dnf` (or older `yum`) |
| **Metadata format** | Control file embedded in the package | Spec file used at build time, metadata embedded in package |
| **Internal structure** | An `ar` archive containing control data + compressed payload | A cpio archive with an RPM-specific header |

### Why Two Formats Exist

Both formats solve the same problem — bundling a program, its metadata, and installation scripts into one file — but they emerged independently in the early-to-mid 1990s from different projects (Debian and Red Hat Linux) and were never unified, similar to how regional standards sometimes diverge and then persist due to inertia and ecosystem lock-in.

### Low-Level vs. High-Level Tools

Both ecosystems split functionality into two layers:

- **Low-level** (`dpkg`, `rpm`): installs/removes a *specific package file* you already have, but does **not** resolve dependencies or fetch anything from the internet.
- **High-level** (`apt`, `dnf`): manages **repositories**, resolves and installs dependencies automatically, and is what you should reach for in virtually all everyday use.

```bash
# Low-level: installing a specific local .deb file (dependencies NOT resolved automatically)
sudo dpkg -i package.deb

# High-level: installing by name, dependencies resolved automatically from repos
sudo apt install package-name
```

```bash
# Low-level: installing a specific local .rpm file
sudo rpm -i package.rpm

# High-level: installing by name, dependencies resolved automatically
sudo dnf install package-name
```

> **Tip:** If `dpkg -i` or `rpm -i` fails due to missing dependencies, you can usually recover with the high-level tool's "fix broken installs" mode rather than manually hunting down each dependency:
> ```bash
> sudo apt --fix-broken install     # Debian/Ubuntu
> sudo dnf check          # RPM-based: identify dependency issues
> ```

---

## 🌐 Repositories

A **repository** ("repo") is a server (or collection of servers) hosting packages along with an index describing what's available, what version, and how packages depend on each other.

### How Repos Are Configured

```bash
# Debian/Ubuntu — repo list
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/

# RPM-based — repo list
cat /etc/yum.repos.d/*.repo
dnf repolist
```

A typical APT source line:

```
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
```

### Refreshing Repository Metadata

Before installing or upgrading, the package manager needs an up-to-date picture of what's available — this is a separate step from actually installing anything:

```bash
sudo apt update      # Debian/Ubuntu: refresh package index (does NOT upgrade anything)
sudo dnf check-update # RPM-based: list available updates
```

> **Common confusion:** `apt update` sounds like it upgrades software, but it only refreshes the local index of what's *available*. Actually upgrading installed packages is a separate command (`apt upgrade`) — see below.

### Why Repository Trust Matters

Repositories are cryptographically signed, and your system maintains a set of trusted signing keys. Adding a third-party repository means trusting that maintainer's signing key to install software with system-level privileges — a meaningful trust decision, not just a configuration tweak.

```bash
apt-key list                      # (legacy) list trusted APT signing keys
gpg --show-keys /path/to/key.gpg   # inspect a key before trusting it
```

> ⚠️ **Caution:** Only add repositories from sources you genuinely trust. A malicious or compromised repository can serve packages with full root-level install scripts — effectively a direct path to system compromise.

---

## 🔗 Dependencies

Most software relies on shared libraries and other packages to function — a dependency graph the package manager must resolve before installation.

```bash
apt depends package-name        # show what a package depends on
apt rdepends package-name        # show what depends ON this package (reverse deps)
dnf repoquery --requires package-name   # RPM equivalent
```

### Dependency Resolution

When you ask to install a package, the package manager:
1. Looks up what it directly depends on.
2. Recursively resolves *those* dependencies' dependencies.
3. Computes a complete, consistent set of packages/versions to install — handling version constraints (e.g. "needs libfoo >= 2.1") along the way.
4. Presents the full set of additions before proceeding, so you can review what's about to change.

### "Dependency Hell"

Before modern resolvers matured, conflicting version requirements between packages could leave a system in an unresolvable state — colloquially "dependency hell." Modern `apt`/`dnf` largely avoid this through careful repository curation and robust constraint-solving, though it can still occur with third-party repos or mixing incompatible sources.

```bash
sudo apt install -f      # attempt to resolve a broken dependency state
sudo dnf distro-sync      # RPM equivalent for resolving version mismatches
```

---

## 🧾 Package Metadata

Every package carries structured metadata describing itself — separate from the actual program files it installs.

```bash
dpkg -s package-name          # show installed package's metadata (Debian/Ubuntu)
rpm -qi package-name            # show installed package's metadata (RPM-based)
```

### Typical Metadata Fields

| Field | Meaning |
|---|---|
| Name | Package identifier |
| Version | Specific version + revision |
| Architecture | `amd64`, `arm64`, `noarch`, etc. |
| Maintainer | Who packages/maintains this software |
| Dependencies | What else must be installed |
| Description | Human-readable summary |
| Installed size | Disk space required |
| Signature | Cryptographic proof of authenticity |

### Listing Files Installed by a Package

```bash
dpkg -L package-name      # list every file a .deb package installed
rpm -ql package-name       # list every file an .rpm package installed
```

### Finding Which Package Owns a File

```bash
dpkg -S /usr/bin/some-binary    # "which package installed this file?"
rpm -qf /usr/bin/some-binary
```

---

## 🛠️ Common Operations Cheat Sheet

| Task | Debian/Ubuntu (`apt`) | RPM-based (`dnf`) |
|---|---|---|
| Refresh package index | `sudo apt update` | `sudo dnf check-update` |
| Upgrade all packages | `sudo apt upgrade` | `sudo dnf upgrade` |
| Install a package | `sudo apt install name` | `sudo dnf install name` |
| Remove a package | `sudo apt remove name` | `sudo dnf remove name` |
| Remove + config files | `sudo apt purge name` | `sudo dnf remove name` (configs vary) |
| Search for a package | `apt search keyword` | `dnf search keyword` |
| Show package info | `apt show name` | `dnf info name` |
| List installed packages | `apt list --installed` | `dnf list installed` |
| Remove unused dependencies | `sudo apt autoremove` | `sudo dnf autoremove` |
| Clean cached package files | `sudo apt clean` | `sudo dnf clean all` |

---

## 🔐 Security Updates and Patch Management

### Why Timely Patching Matters

Most real-world system compromises exploit **known, already-patched** vulnerabilities — not novel zero-days. The gap between a patch being released and a system actually applying it is one of the most consequential windows in practical security.

### Distinguishing Security Updates from Regular Updates

Many distributions tag security-relevant updates separately so they can be prioritized or automated independently of general feature/version upgrades.

```bash
# Debian/Ubuntu: list available security updates specifically
apt list --upgradable | grep -i security

# RHEL/Fedora: list only security-related updates
dnf updateinfo list security
dnf upgrade --security
```

### Automating Security Updates

```bash
# Debian/Ubuntu
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# RHEL/Fedora
sudo dnf install dnf-automatic
sudo systemctl enable --now dnf-automatic.timer
```

> **Tradeoff to weigh:** fully automated updates close the patching gap fastest, but remove the human review step — an update could (rarely) introduce a regression on a system with no one watching. Many production environments compromise by **automating security-only updates** while keeping feature upgrades manual and scheduled.

### CVE Tracking

Security advisories typically reference **CVE** (Common Vulnerabilities and Exposures) identifiers. Distribution security teams backport fixes for specific CVEs into the current stable release, rather than requiring a full version upgrade — meaning a "security update" often doesn't change the software's version number much, just patches the specific flaw.

```bash
dnf updateinfo info CVE-2026-XXXXX   # RPM-based: details on a specific CVE patch
```

### Checking if a Reboot Is Required

Kernel and certain core library updates only take effect after a reboot — applying them doesn't necessarily mean protection is active yet.

```bash
# Debian/Ubuntu
[ -f /var/run/reboot-required ] && echo "Reboot required"

# RHEL/Fedora
needs-restarting -r
```

---

## ⚡ Quick Reference

| Concept | Debian/Ubuntu | RPM-based |
|---|---|---|
| Package format | `.deb` | `.rpm` |
| Low-level tool | `dpkg` | `rpm` |
| High-level tool | `apt` | `dnf` (or `yum`) |
| Repo config location | `/etc/apt/sources.list`, `sources.list.d/` | `/etc/yum.repos.d/` |
| Refresh index | `apt update` | `dnf check-update` |
| Upgrade all | `apt upgrade` | `dnf upgrade` |
| Security-only updates | `apt list --upgradable \| grep security` | `dnf upgrade --security` |
| Find file's owning package | `dpkg -S /path` | `rpm -qf /path` |
| Reboot-required check | `/var/run/reboot-required` | `needs-restarting -r` |

---

## 💡 Best Practices

- Use the high-level tool (`apt`, `dnf`) for everyday installs and removals — reserve `dpkg`/`rpm` for inspecting or manually fixing specific package files.
- Run the index refresh (`apt update` / `dnf check-update`) regularly, but understand it doesn't upgrade anything by itself.
- Only add third-party repositories from sources you trust — inspect signing keys before adding, since a malicious repo can install software with root privileges.
- Separate security patching cadence from feature-upgrade cadence — consider automating security-only updates while reviewing larger version upgrades manually.
- Check for required reboots after kernel/library updates — an applied patch isn't necessarily an *active* patch until the affected component restarts.
- Use `apt autoremove` / `dnf autoremove` periodically to clear out orphaned dependencies left behind after package removals.
- When troubleshooting "which package put this file here," reach for `dpkg -S` / `rpm -qf` before manually guessing.