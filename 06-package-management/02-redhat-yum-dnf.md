# Red Hat Package Management with YUM and DNF

A reference guide to managing software on Red Hat-based distributions (RHEL, Fedora, CentOS, Rocky Linux, AlmaLinux) using DNF — including its relationship to YUM, repository configuration, and transaction history.

---

## 🧩 DNF vs. YUM vs. `rpm`

### The Layering

```
rpm   ←  low-level: installs/removes a SPECIFIC .rpm file, no dependency resolution
yum   ←  high-level (legacy): repos, dependency resolution, the original tool
dnf   ←  high-level (modern): YUM's successor — same job, better internals
```

`dnf` ("Dandified YUM") is the modern successor to `yum`, introduced as the default package manager starting with Fedora 22 and now standard across current RHEL, CentOS Stream, Rocky Linux, and AlmaLinux releases.

### Why DNF Replaced YUM

YUM's dependency resolver (historically) could be slow and occasionally inconsistent on complex dependency graphs. DNF rewrote the resolver on top of `libsolv` (a SAT-style constraint solver also used by other package systems), giving faster, more reliable resolution, along with a cleaner plugin API and better performance on large repositories.

### `yum` Still Works

On modern systems, `yum` is typically a **symlink or alias to `dnf`** — meaning your muscle memory and existing scripts using `yum` commands keep working, while actually running DNF underneath:

```bash
which yum
# /usr/bin/yum -> dnf (or similar, depending on distro)
```

```bash
yum install package-name    # works — transparently runs dnf
dnf install package-name    # equivalent, explicit
```

> **Tip:** On current systems there's no practical reason to specifically choose `yum` over `dnf` — they're functionally the same command. Older RHEL 7 and CentOS 7 systems use genuine standalone YUM (pre-DNF), where some flags and behavior differ slightly from modern DNF — check `man yum` on those systems specifically if something behaves unexpectedly.

---

## 🔄 Refreshing Metadata

```bash
sudo dnf check-update
```

Lists available updates without installing anything — DNF automatically refreshes its metadata cache as needed during normal operations, unlike APT where `update` is a distinct required step.

```bash
sudo dnf clean metadata    # force-clear cached repo metadata
sudo dnf makecache          # force a fresh metadata download
```

---

## ⬆️ Upgrading Packages

```bash
sudo dnf upgrade              # upgrade all installed packages to latest available
sudo dnf upgrade package-name  # upgrade just one package
sudo dnf update                # alias for "upgrade" — functionally identical in DNF
```

> **Note:** Unlike APT (where `upgrade` and `dist-upgrade`/`full-upgrade` are meaningfully different), DNF's `upgrade` already handles dependency changes, package replacements, and obsoletions as part of normal operation — there isn't a separate "full upgrade" concept to reach for.

### Checking What Would Change First

```bash
dnf upgrade --assumeno    # show the transaction plan, then decline — a "dry run"
```

---

## ➕ Installing Packages

```bash
sudo dnf install nginx
sudo dnf install nginx-1.24.0       # install a specific version, if available
sudo dnf install nginx curl git      # install multiple packages
sudo dnf install ./local-package.rpm # install directly from a local file, with dependency resolution
```

> **Tip:** Unlike plain `rpm -i`, installing a local `.rpm` file through `dnf install ./file.rpm` *does* resolve dependencies from configured repositories — making it almost always preferable to `rpm -i` for local files too.

### Reinstalling

```bash
sudo dnf reinstall package-name
```

### Installing Groups of Related Packages

RPM-based systems support **package groups** — curated bundles for common purposes:

```bash
dnf group list                          # list available groups
sudo dnf group install "Development Tools"
```

---

## ➖ Removing Packages

```bash
sudo dnf remove package-name
```

Unlike APT's `remove`/`purge` distinction, DNF's `remove` behavior around configuration files depends on how the individual package was built (its RPM spec) — there isn't a universal separate "purge" command.

### Removing Unused Dependencies

```bash
sudo dnf autoremove
```

Removes packages that were pulled in automatically as dependencies but are no longer required by anything currently installed — directly analogous to APT's `autoremove`.

---

## 🌐 Repository Configuration: `/etc/yum.repos.d/`

### Repository Files

Each repository is defined in its own `.repo` file:

```bash
ls /etc/yum.repos.d/
cat /etc/yum.repos.d/rocky-extras.repo
```

```ini
[rocky-extras]
name=Rocky Linux $releasever - Extras
baseurl=http://dl.rockylinux.org/pub/rocky/$releasever/extras/$basearch/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
```

### Anatomy of a Repo Entry

| Field | Meaning |
|---|---|
| `[repo-id]` | Unique internal identifier for the repository |
| `name` | Human-readable description |
| `baseurl` (or `mirrorlist`/`metalink`) | Where to fetch packages and metadata from |
| `enabled` | `1` to use this repo, `0` to disable without deleting the file |
| `gpgcheck` | Whether to verify package signatures (`1` strongly recommended) |
| `gpgkey` | Path or URL to the trusted signing key |

### Variables in Repo URLs

- `$releasever` — the distribution's release version (e.g. `9`)
- `$basearch` — system architecture (e.g. `x86_64`, `aarch64`)

These let one `.repo` file work correctly across different versions/architectures without hardcoding.

### Managing Repositories

```bash
dnf repolist                       # list enabled repositories
dnf repolist --all                  # include disabled ones too
sudo dnf config-manager --set-enabled repo-id
sudo dnf config-manager --set-disabled repo-id
sudo dnf config-manager --add-repo https://example.com/repo.repo
```

### Adding Third-Party Repositories

A common community add-on for RHEL-family systems:

```bash
sudo dnf install epel-release    # adds the EPEL (Extra Packages for Enterprise Linux) repo
```

> ⚠️ **Caution:** Always verify `gpgcheck=1` is set and the signing key is genuinely trustworthy before enabling a third-party repo — a malicious repo can serve packages with root-level install scripts. Inspect a `.repo` file's contents before adding it, especially from `add-repo` URLs you haven't independently verified.

---

## 📜 Transaction History: `dnf history`

One of DNF's most useful features is a **complete, reviewable log** of every transaction (install, remove, upgrade) ever performed — and the ability to **undo** them.

### Viewing History

```bash
dnf history list                 # show all past transactions, numbered
dnf history info 42               # show full detail of transaction #42
dnf history list package-name      # show transactions involving a specific package
```

```
ID  | Command line       | Date and time    | Action(s) | Altered
42  | install nginx      | 2026-06-20 09:15 | Install   | 3
41  | upgrade             | 2026-06-18 14:02 | Upgrade   | 12
```

### Undoing a Transaction

```bash
sudo dnf history undo 42       # reverse transaction #42 specifically
sudo dnf history rollback 40    # roll the system back to the state AFTER transaction 40
```

| Command | Effect |
|---|---|
| `undo ID` | Reverses just that one transaction |
| `rollback ID` | Reverses every transaction *after* the specified one, restoring that point in time |
| `redo ID` | Re-applies a previously undone transaction |

> **Tip:** This history-based undo is one of DNF's strongest advantages over many other package managers — if an upgrade causes a regression, `dnf history undo` is often faster and safer than manually trying to reinstall older versions by hand.

> ⚠️ **Caution:** Undo/rollback works by replaying the inverse operations, not by snapshotting the filesystem — it can fail or behave unexpectedly if intervening manual changes (e.g. direct `rpm` operations or manually edited config files) conflict with the transaction being reversed.

---

## 🔒 Version Locking

To prevent a specific package from being upgraded (similar to APT's `apt-mark hold`):

```bash
sudo dnf install python3-dnf-plugin-versionlock   # if not already present
sudo dnf versionlock add package-name
sudo dnf versionlock list
sudo dnf versionlock delete package-name
```

---

## 🔍 Package Audits

```bash
dnf list installed                     # list all installed packages
dnf list installed | grep nginx
rpm -qa | grep nginx                    # alternative, via rpm directly
dnf info package-name                    # detailed metadata
dnf repoquery --requires package-name     # what this package depends on
dnf repoquery --whatrequires package-name # what depends ON this package
```

### Finding Which Package Owns a File

```bash
rpm -qf /usr/bin/some-binary
dnf provides /usr/bin/some-binary
```

### Listing Files a Package Installed

```bash
rpm -ql package-name
```

### Checking Installed Package Integrity

```bash
rpm -V package-name      # verify checksums, permissions, ownership against package records
```

### Security Updates Specifically

```bash
dnf updateinfo list security
sudo dnf upgrade --security
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Check for updates | `dnf check-update` |
| Upgrade all packages | `sudo dnf upgrade` |
| Upgrade one package | `sudo dnf upgrade package-name` |
| Install a package | `sudo dnf install package-name` |
| Install a local RPM (with deps) | `sudo dnf install ./file.rpm` |
| Remove a package | `sudo dnf remove package-name` |
| Remove unused dependencies | `sudo dnf autoremove` |
| List repositories | `dnf repolist` |
| Add a repo file | `sudo dnf config-manager --add-repo URL` |
| Enable/disable a repo | `sudo dnf config-manager --set-enabled/--set-disabled repo-id` |
| View transaction history | `dnf history list` |
| Undo a specific transaction | `sudo dnf history undo ID` |
| Roll back to a point in time | `sudo dnf history rollback ID` |
| Lock a package's version | `sudo dnf versionlock add package-name` |
| Security updates only | `sudo dnf upgrade --security` |
| Find which package owns a file | `rpm -qf /path` or `dnf provides /path` |

---

## 💡 Best Practices

- Use `dnf` directly rather than `yum` on modern systems — they're functionally identical, but `dnf`'s documentation and flags are the current standard.
- Check `dnf history list` before troubleshooting a regression — it's often faster to `dnf history undo` a recent change than to debug it manually.
- Always confirm `gpgcheck=1` and a trustworthy signing key before enabling any third-party `.repo` file.
- Use `dnf versionlock` for the common case of holding one package at a known-good version, rather than disabling its repo entirely.
- Prefer `dnf install ./file.rpm` over `rpm -i file.rpm` for local files — DNF still resolves dependencies from your configured repos, which plain `rpm` does not.
- Run `dnf autoremove` periodically to clear orphaned dependency packages.
- Treat `dnf history rollback` with the same caution as any bulk system change — it can conflict with manual changes made outside DNF, so review `history info` for the target transaction first.
- Use `dnf upgrade --security` on a faster, separate cadence from full feature upgrades if you want to prioritize patching known vulnerabilities without taking on the risk of broader version changes.