# Linux

Free, open-source kernel by **Linus Torvalds** (1991). Runs ~96% of web servers, all major clouds (AWS, GCP, Azure), Android, and basically every pentest platform.

---

## Why it matters

- Backbone of cloud & server infra
- Required for security / sysadmin work
- Powers Android & IoT devices
- Free and open source

---

## Open source

- **GPL license** — derivatives must stay open source
- Stallman → GNU / Free Software Foundation
- Torvalds → Linux kernel
- Linux Foundation → stewardship of the ecosystem

---

## Distros

| Distro   | Good for              | Pkg mgr  | Notes               |
|----------|-----------------------|----------|---------------------|
| Ubuntu   | Beginners, general    | apt      | ★ start here        |
| Kali     | Pentesting / security | apt      | ★ start here        |
| Parrot   | Security, lighter     | apt      |                     |
| Fedora   | Developers            | dnf      |                     |
| Arch     | Advanced / DIY        | pacman   | hard                |
| Debian   | Servers, stability    | apt      | base for Ubuntu     |

---

## Terminal basics
---
```
user@hostname:~$
│    │         │└── $ = regular user, # = root
│    │         └─── ~ = current directory (home)
│    └─────────────── hostname (machine name)
└──────────────────── logged-in username
```
---
### Navigate

```bash
pwd          # where am I?
ls -la       # list all files (with hidden)
cd ~/folder  # go to folder
cd ..        # go up one level
```

### View files

```bash
cat f.txt    # print contents
less f.txt   # scrollable view
head -n 10 f # first 10 lines
tail -n 10 f # last 10 lines
```

### File ops

```bash
touch f.txt  # create empty file
mkdir dir    # create folder
cp src dest  # copy
mv src dest  # move / rename
rm f.txt     # delete file
rm -rf dir/  # ⚠ delete folder recursively
```

### System / permissions

```bash
whoami       # current user
uname -a     # kernel info
sudo cmd     # run as root
chmod +x f   # make file executable
man cmd      # help for any command
```

---

## Filesystem layout

| Path    | What's in there              |
|---------|------------------------------|
| `/`     | Root — top of everything     |
| `/bin`  | Core binaries (ls, cp…)      |
| `/etc`  | System config files          |
| `/home` | User home directories        |
| `/var`  | Logs, caches                 |
| `/tmp`  | Temp files (cleared on reboot) |
| `/usr`  | Installed programs           |
| `/root` | Root user's home             |

---

## Setup options

| Method             | Notes                            |
|--------------------|----------------------------------|
| VirtualBox + Ubuntu | Free, isolated, safe — recommended |
| WSL 2 (Windows)    | Native Linux inside Windows, easy |
| Live USB           | No install needed, boot from USB |
| Cloud VPS          | Real remote server, good for practice |

---

## Links

- [The Linux Command Line](https://linuxcommand.org/tlcl.php) — free book, very good
- [OverTheWire: Bandit](https://overthewire.org/wargames/bandit/) — CLI wargame to practice
- [Linux Journey](https://linuxjourney.com) — interactive learning
- [explainshell.com](https://explainshell.com) — paste any command, get an explanation