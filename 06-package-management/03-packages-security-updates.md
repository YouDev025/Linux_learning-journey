# Package Security and Updates

A reference guide to keeping Linux systems secure through timely patching, package signature verification, and vulnerability scanning — across both Debian-based and Red Hat-based systems.

---

## 🎯 Why This Matters

The large majority of real-world breaches exploit vulnerabilities for which a patch **already exists** — not novel zero-days. The practical security question for most systems isn't "is this software perfectly secure," but **"how quickly does a known fix reach this machine after it's released."** Everything in this guide serves that single goal: shrinking the gap between patch availability and patch application.

---

## 🔄 The Security Patch Workflow

A complete patching workflow has four stages, regardless of distribution family:

```
1. DETECT  → 2. ASSESS  → 3. APPLY  → 4. VERIFY
   (what's        (how risky       (install the      (confirm it
   available?)     is it?)          fix)              took effect)
```

### 1. Detect — What Updates Are Available

```bash
# Debian/Ubuntu
sudo apt update
apt list --upgradable

# RHEL/Fedora
sudo dnf check-update
```

### 2. Assess — Which Updates Are Security-Relevant

Not every available update is a security fix — separating signal from routine version bumps lets you prioritize correctly.

```bash
# Debian/Ubuntu — filter the upgradable list for security-tagged entries
apt list --upgradable 2>/dev/null | grep -i security

# RHEL/Fedora — list only security advisories
dnf updateinfo list security
dnf updateinfo info CVE-2026-XXXXX    # details on a specific advisory
```

### 3. Apply — Install the Fix

```bash
# Debian/Ubuntu
sudo apt upgrade                          # all updates
sudo unattended-upgrade --dry-run          # preview what automated security upgrades would do

# RHEL/Fedora
sudo dnf upgrade --security                # security updates only
```

### 4. Verify — Confirm the Patch Is Active

Installing a package isn't always the same as the fix being *active* — some patches (kernel, core libraries, long-running daemons) only take effect after a restart.

```bash
# Debian/Ubuntu — check if a reboot is needed
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required

# RHEL/Fedora — check if a reboot is needed
needs-restarting -r

# Either system — check if a *running process* is still using an old library version
sudo needs-restarting    # (RHEL/Fedora) lists processes using since-updated files
```

---

## 🔐 Verifying Package Signatures

Every package from an official repository is cryptographically signed, letting your system confirm a package genuinely came from the maintainer and hasn't been tampered with in transit or storage.

### How Signature Verification Works

1. Each repository publishes packages signed with a **private key**.
2. Your system holds the corresponding **public key**, marked as trusted.
3. Before installing, the package manager checks the package's signature against that trusted public key.
4. If the signature doesn't match (wrong key, tampered package, or corrupted download), installation is **refused by default**.

### Debian/Ubuntu (APT)

```bash
apt-key list                                   # (legacy) list trusted keys
gpg --no-default-keyring --keyring /etc/apt/trusted.gpg --list-keys   # modern equivalent
ls /etc/apt/trusted.gpg.d/                      # individual trusted keyrings
```

Modern APT prefers per-repository keyrings referenced explicitly via `Signed-By` in `.sources` files, rather than one global trusted keyring — making it clearer which key authorizes which repository.

```bash
gpg --show-keys /path/to/downloaded-key.gpg     # inspect a key BEFORE trusting it
sudo apt-key --keyring /etc/apt/trusted.gpg.d/example.gpg add example-key.gpg   # (legacy approach)
```

> ⚠️ **Caution:** Never disable signature checking (`--allow-unauthenticated` in APT) to work around a verification failure — that failure usually means something is genuinely wrong (a stale mirror, a tampered package, or a misconfigured key), not a harmless technicality.

### RHEL/Fedora (RPM/DNF)

```bash
gpgcheck=1    # set in /etc/yum.repos.d/*.repo — verify signatures (do NOT disable this)
rpm --checksig package.rpm                      # check a specific local .rpm file's signature
rpm -qa gpg-pubkey                                # list installed/trusted GPG public keys
rpm -qi gpg-pubkey-<keyid>                         # show details on a specific trusted key
```

```bash
sudo rpm --import /path/to/RPM-GPG-KEY-vendor      # import and trust a new signing key
```

> **Tip:** Before importing a new key, verify its fingerprint through an independent channel (the vendor's official documentation, not just the file you're about to import) — importing a key is the trust decision; everything after that is automatic.

### Verifying Installed Package Integrity (Not Just at Install Time)

Signature checks happen at install time — but you can also verify that **already-installed** files still match what the package originally provided, catching tampering or accidental modification after the fact.

```bash
# Debian/Ubuntu (requires the debsums package)
sudo apt install debsums
debsums package-name
debsums -c                 # check ALL installed packages, list only mismatches

# RHEL/Fedora (built into rpm)
rpm -V package-name
rpm -Va                     # verify ALL installed packages
```

```
rpm -V output legend:
S  file Size differs
M  Mode (permissions) differs
5  MD5 checksum differs
T  modification Time differs
..  no discrepancy in that category
```

> **Tip:** A mismatch doesn't always mean compromise — config files are *expected* to differ once you've customized them. Focus suspicion on unexpected changes to binaries (`/usr/bin/`, `/usr/sbin/`) rather than `/etc/` config files, which legitimately change during normal use.

---

## 🛠️ OS-Specific Advisory and Scanning Tools

### Debian/Ubuntu

```bash
sudo apt install ubuntu-security-status     # Ubuntu Pro: summarized security status
ubuntu-security-status

sudo apt install debian-security-support     # Debian: check support status of installed packages
check-support-status
```

```bash
# Querying Debian's security tracker directly (web-based, but scriptable)
# https://security-tracker.debian.org/tracker/CVE-2026-XXXXX
```

### RHEL/Fedora

```bash
dnf updateinfo list security        # list pending security advisories
dnf updateinfo summary               # summarized counts by severity
sudo dnf install dnf-plugins-core
dnf updateinfo --advisory=RHSA-2026:XXXX info   # detail on a specific Red Hat Security Advisory
```

RHEL-family systems classify advisories by type:

| Prefix | Meaning |
|---|---|
| `RHSA` | Red Hat Security Advisory — a security fix |
| `RHBA` | Red Hat Bug Advisory — a non-security bugfix |
| `RHEA` | Red Hat Enhancement Advisory — a feature/enhancement |

### Cross-Distribution Vulnerability Scanners

Independent of the package manager, dedicated scanners can audit a whole system against known-vulnerability databases:

```bash
# OpenSCAP — standardized compliance/vulnerability scanning, used heavily in RHEL-family and government/enterprise environments
sudo oscap oval eval --results results.xml /path/to/vulnerability-feed.xml

# Lynis — general-purpose security auditing tool, works across distros
sudo lynis audit system
```

> **Note:** These tools scan for *known* vulnerable package versions against a maintained CVE feed — they're complementary to, not a replacement for, simply keeping the package manager's own security updates current.

---

## 🤖 Automating Security Updates

### Debian/Ubuntu: `unattended-upgrades`

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

Configuration lives in `/etc/apt/apt.conf.d/50unattended-upgrades` — by default it's scoped to security updates specifically, leaving feature upgrades for manual review.

```bash
sudo unattended-upgrade --dry-run --debug    # preview what it would do
cat /var/log/unattended-upgrades/unattended-upgrades.log   # review past automated runs
```

### RHEL/Fedora: `dnf-automatic`

```bash
sudo dnf install dnf-automatic
sudo systemctl enable --now dnf-automatic.timer
```

Configuration lives in `/etc/dnf/automatic.conf` — including whether to only *download* updates, only *notify*, or actually *apply* them automatically.

```ini
[commands]
upgrade_type = security
apply_updates = yes
```

### The Core Tradeoff

| | Fully automated updates | Manual review |
|---|---|---|
| Speed of patching | Fastest possible | Depends on admin attention |
| Risk of regression slipping through unreviewed | Higher | Lower (a human checks first) |
| Operational overhead | Low | Higher (requires ongoing attention) |

> **Common middle ground:** automate **security-only** updates (where the cost of delay generally outweighs the small risk of an automated regression) while keeping **feature/version** upgrades manual and scheduled — this is what both `unattended-upgrades` and `dnf-automatic` default toward.

---

## ⚡ Quick Reference

| Task | Debian/Ubuntu | RHEL/Fedora |
|---|---|---|
| Check for security updates | `apt list --upgradable \| grep security` | `dnf updateinfo list security` |
| Apply security updates only | (manual filtering, or `unattended-upgrade`) | `sudo dnf upgrade --security` |
| Check if reboot is required | `[ -f /var/run/reboot-required ]` | `needs-restarting -r` |
| Verify installed package integrity | `debsums -c` | `rpm -Va` |
| List trusted signing keys | `gpg --keyring /etc/apt/trusted.gpg --list-keys` | `rpm -qa gpg-pubkey` |
| Import a new trusted key | `cp key.gpg /etc/apt/trusted.gpg.d/` | `sudo rpm --import KEY` |
| Automate security updates | `unattended-upgrades` | `dnf-automatic` |
| Advisory detail by ID | (Debian Security Tracker, web) | `dnf updateinfo info RHSA-...` |

---

## 💡 Best Practices

- Never disable signature verification (`--allow-unauthenticated`, removing `gpgcheck=1`) to work around an error — investigate the actual cause instead.
- Verify a new signing key's fingerprint through an independent, official channel before importing/trusting it — don't trust a key just because the file claims to be from a vendor.
- Separate security-update cadence from feature-update cadence: automate the former, review the latter — this captures most of the speed benefit of automation while limiting regression risk.
- Periodically run an integrity check (`debsums -c` or `rpm -Va`) to catch unexpected modifications to installed binaries, not just at install time.
- Check for required reboots after kernel or core library updates — an installed patch isn't necessarily an *active* one until the affected component restarts.
- Use OS-native advisory tools (`updateinfo`, security-status checkers) to distinguish genuine security fixes from routine version bumps, so patching effort is prioritized correctly.
- Treat vulnerability scanners (OpenSCAP, Lynis) as a complement to, not a substitute for, keeping the package manager's own security updates current.