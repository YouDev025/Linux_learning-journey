# Debian Package Management with APT

A reference guide to managing software on Debian-based distributions (Debian, Ubuntu, Mint, and derivatives) using APT — installing, updating, removing, configuring sources, and auditing packages.

---

## 🧩 APT vs. `dpkg`

APT (Advanced Package Tool) is the high-level layer on top of `dpkg`. `dpkg` installs and removes individual `.deb` files but has no concept of repositories or dependency resolution; APT adds both, plus version comparison, conflict resolution, and a friendlier interface.

```bash
# dpkg: installs a specific local file, no dependency resolution
sudo dpkg -i package.deb

# apt: installs by name, resolves and fetches dependencies automatically
sudo apt install package-name
```

> **Tip:** Reach for `apt` for virtually all everyday tasks. Drop to `dpkg` only when you have a specific local `.deb` file to inspect or install directly.

---

## 🔄 Refreshing the Package Index: `apt update`

```bash
sudo apt update
```

This re-downloads the **index** of available packages and their versions from every configured repository — it does **not** install or upgrade anything by itself.

```
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Get:2 http://archive.ubuntu.com/ubuntu noble-updates InRelease [...]
Reading package lists... Done
```

> **Common confusion:** running `apt update` alone doesn't change any installed software — it only refreshes what APT *knows* is available. You still need `apt upgrade` (or `apt install`) to actually change anything on disk.

---

## ⬆️ Upgrading Packages: `apt upgrade` vs. `apt full-upgrade`

### `apt upgrade`

```bash
sudo apt upgrade
```

Upgrades all currently installed packages to their latest available version — but will **not** remove any currently installed package, even if doing so would be required to satisfy a new dependency. If an upgrade would require a removal, that specific package is simply held back.

### `apt full-upgrade` (formerly `dist-upgrade`)

```bash
sudo apt full-upgrade
```

Upgrades everything `apt upgrade` does, **and** will install new packages or remove existing ones if needed to resolve dependency changes — for example, when a major version bump restructures how a package's dependencies work.

| | `apt upgrade` | `apt full-upgrade` |
|---|---|---|
| Upgrades installed packages | ✅ | ✅ |
| Installs new packages if required | ❌ | ✅ |
| Removes packages if required | ❌ | ✅ |
| Risk level | Lower | Slightly higher (more changes possible) |

> **Tip:** Run plain `apt upgrade` for routine maintenance. Use `full-upgrade` when moving between major distribution releases or when `apt upgrade` reports packages being "kept back."

---

## ➕ Installing Packages: `apt install`

```bash
sudo apt install nginx
sudo apt install nginx=1.24.0-1   # install a specific version, if available in the repo
sudo apt install nginx curl git    # install multiple packages at once
```

### Simulating an Install First

```bash
apt install --dry-run package-name      # show what WOULD happen, without changing anything
```

This is especially useful before a `full-upgrade` or before installing something with a deep dependency tree, so you can review the full list of additions/removals first.

### Reinstalling a Package

```bash
sudo apt install --reinstall package-name
```

---

## ➖ Removing Packages: `apt remove` vs. `apt purge`

```bash
sudo apt remove package-name     # removes the package, KEEPS configuration files
sudo apt purge package-name      # removes the package AND its configuration files
```

| | `apt remove` | `apt purge` |
|---|---|---|
| Removes binaries | ✅ | ✅ |
| Removes config files (`/etc/...`) | ❌ | ✅ |
| Good for | Temporary removal, planning to reinstall later with same config | Fully cleaning up a package you won't use again |

### Cleaning Up Leftover Dependencies

```bash
sudo apt autoremove          # remove packages that were installed as dependencies but are no longer needed
sudo apt autoremove --purge   # same, but also purge their config files
```

> **Tip:** Run `apt autoremove` periodically — dependencies that were only needed by a now-removed package tend to accumulate as harmless but unnecessary disk clutter otherwise.

---

## 🌐 Repository Configuration: `/etc/apt/sources.list`

### The Main Sources File

```bash
cat /etc/apt/sources.list
```

```
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
```

### Anatomy of a Source Line

```
deb  http://archive.ubuntu.com/ubuntu  noble  main restricted universe multiverse
 │              │                        │              │
 │              │                        │              └── components (which sections to include)
 │              │                        └── release/suite codename
 │              └── repository base URL
 └── "deb" = binary packages ("deb-src" = source packages)
```

| Component | Meaning |
|---|---|
| `main` | Officially supported, free/open-source software |
| `restricted` | Officially supported, but with restrictive licensing |
| `universe` | Community-maintained, free/open-source |
| `multiverse` | Community-maintained, with non-free or legally restricted software |

### Drop-In Repository Files

Modern systems organize additional repositories as individual files rather than appending to the main list:

```bash
ls /etc/apt/sources.list.d/
cat /etc/apt/sources.list.d/some-ppa.list
```

This keeps third-party additions (like a PPA — Personal Package Archive — or a vendor's own repo) easy to review and remove individually.

### Adding a Repository

```bash
sudo add-apt-repository ppa:some/ppa     # Ubuntu PPA helper
echo "deb https://example.com/repo stable main" | sudo tee /etc/apt/sources.list.d/example.list
```

### Newer Format: DEB822 (`.sources` files)

Recent versions of APT support a more structured, key-value format (`.sources` files) as an alternative to the traditional one-line syntax:

```
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

> ⚠️ **Caution:** Only add repositories you genuinely trust — adding a repo means trusting its signing key to install software with root privileges. Inspect a key before trusting it, and remove repositories you no longer actively use.

---

## 📌 Pinning Packages

**Pinning** controls which version or repository APT prefers when multiple sources offer the same package — useful for holding a package at a specific version or preferring one repo over another.

### Configuration Location

```bash
cat /etc/apt/preferences
ls /etc/apt/preferences.d/
```

### Pinning Syntax

```
Package: nginx
Pin: version 1.24.0-1
Pin-Priority: 1001
```

```
Package: *
Pin: release a=noble-backports
Pin-Priority: 100
```

### Pin Priority Reference

| Priority | Effect |
|---|---|
| `1001` | Install even if it's a downgrade from the currently installed version |
| `990` | Prefer over the default target release |
| `500` | Default priority for packages not otherwise pinned |
| `100` | Prefer, but won't override an already-installed newer version |
| `-1` or below | Never install this version |

### Holding a Specific Package at Its Current Version

A simpler, more common alternative to full pin syntax — preventing a single package from being upgraded at all:

```bash
sudo apt-mark hold package-name      # prevent upgrades to this package
sudo apt-mark unhold package-name    # allow upgrades again
apt-mark showhold                     # list all currently held packages
```

> **Tip:** Use `apt-mark hold` for the common case of "don't touch this one package's version." Reach for full pinning syntax only when you need more nuanced control — like preferring an entire repository's versions over another's.

---

## 🗄️ Caching

### Where Downloaded Packages Are Cached

APT caches every downloaded `.deb` file before installing, so reinstalling doesn't require re-downloading:

```bash
ls /var/cache/apt/archives/
```

### Managing Cache Size

```bash
sudo apt clean        # remove ALL cached package files
sudo apt autoclean     # remove only cached files for packages no longer available in any repo (e.g. old versions)
du -sh /var/cache/apt/archives/    # check current cache size
```

| Command | Removes |
|---|---|
| `apt clean` | Every cached `.deb`, regardless of whether it's still installable |
| `apt autoclean` | Only outdated cached `.deb` files no longer obtainable from configured repos |

> **Tip:** `autoclean` is safer for routine maintenance since it preserves the ability to reinstall current versions without re-downloading. `clean` is useful when you specifically need to reclaim disk space and don't mind re-fetching packages later.

---

## 🔍 Package Audits

### Listing Installed Packages

```bash
apt list --installed
apt list --installed | grep nginx
dpkg -l | grep ^ii      # alternative via dpkg; "ii" = fully installed
```

### Inspecting a Specific Package

```bash
apt show package-name           # description, version, dependencies, size
apt depends package-name         # what this package depends on
apt rdepends package-name        # what depends ON this package
```

### Finding Manually vs. Automatically Installed Packages

```bash
apt-mark showmanual      # packages YOU explicitly installed
apt-mark showauto        # packages installed automatically as dependencies
```

This distinction matters for `autoremove` — only auto-installed packages with no remaining dependents are candidates for automatic removal.

### Checking for Available Security Updates

```bash
apt list --upgradable
apt list --upgradable 2>/dev/null | grep -i security
```

### Verifying Installed Package Integrity

```bash
debsums package-name      # check installed files against the package's recorded checksums (install debsums if missing)
```

### Listing Files Owned by a Package

```bash
dpkg -L package-name              # list every file installed by a package
dpkg -S /usr/bin/some-binary       # find which package installed a specific file
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Refresh package index | `sudo apt update` |
| Upgrade installed packages | `sudo apt upgrade` |
| Upgrade + resolve major changes | `sudo apt full-upgrade` |
| Install a package | `sudo apt install name` |
| Preview an install/upgrade | `apt install --dry-run name` |
| Remove a package (keep config) | `sudo apt remove name` |
| Remove a package + config | `sudo apt purge name` |
| Remove unused dependencies | `sudo apt autoremove` |
| Add a repository | `sudo add-apt-repository ppa:name` |
| Hold a package at current version | `sudo apt-mark hold name` |
| Unhold a package | `sudo apt-mark unhold name` |
| List held packages | `apt-mark showhold` |
| Clear all cached packages | `sudo apt clean` |
| Clear only stale cached packages | `sudo apt autoclean` |
| List installed packages | `apt list --installed` |
| Show package details | `apt show name` |
| Find which package owns a file | `dpkg -S /path/to/file` |

---

## 💡 Best Practices

- Run `apt update` before `apt install` or `apt upgrade` so you're working from current repository metadata.
- Use `apt upgrade` for routine maintenance; reserve `full-upgrade` for major version transitions or when packages are reported as "kept back."
- Preview significant changes with `--dry-run` before a `full-upgrade` or a large multi-package install.
- Use `apt purge` instead of `apt remove` when you're certain you won't reinstall a package and want its configuration fully cleaned up too.
- Run `apt autoremove` periodically to clear orphaned dependencies, but check `apt-mark showmanual` first if you're unsure what's actually still needed.
- Prefer `apt-mark hold` for pinning a single package's version; reserve full `/etc/apt/preferences` pinning for repo-level or more nuanced version preferences.
- Only add repositories from sources you trust, and periodically review `/etc/apt/sources.list.d/` to remove ones you no longer need.
- Use `autoclean` rather than `clean` for routine cache maintenance, to avoid unnecessary re-downloads of still-current packages.