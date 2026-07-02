# 🐧 Linux Commands Cheat Sheet

> A professional quick-reference guide to essential Linux commands — file operations, system management, networking, package management, shell utilities, and more — with syntax, explanations, and real examples.

---

## Table of Contents

- [File and Directory Operations](#-file-and-directory-operations)
- [File Viewing and Editing](#-file-viewing-and-editing)
- [Permissions and Ownership](#-permissions-and-ownership)
- [Process and Job Management](#-process-and-job-management)
- [Disk and Filesystem](#-disk-and-filesystem)
- [Networking](#-networking)
- [Package Management](#-package-management)
- [System Information](#-system-information)
- [Archive and Compression](#-archive-and-compression)
- [Text Processing and Shell Utilities](#-text-processing-and-shell-utilities)
- [User and Group Management](#-user-and-group-management)
- [System Services and Logs](#-system-services-and-logs)
- [Access Control Lists](#-access-control-lists)
- [Helpful Shell Shortcuts](#-helpful-shell-shortcuts)
- [Quick Reference Table](#-quick-reference-table)

---

## 📁 File and Directory Operations

| Command | Description | Example |
|---|---|---|
| `ls` | List directory contents | `ls -la` — long format, including hidden files |
| `cd` | Change directory | `cd /var/log` — move into `/var/log` |
| `pwd` | Print current directory | `pwd` — outputs `/home/user` |
| `mkdir` | Create a directory | `mkdir -p project/src` — create nested dirs |
| `rmdir` | Remove an empty directory | `rmdir old_folder` |
| `rm` | Remove files or directories | `rm -rf build/` — force-delete recursively |
| `cp` | Copy files and directories | `cp -r src/ backup/` — copy a directory tree |
| `mv` | Move or rename files | `mv notes.txt notes_old.txt` |
| `touch` | Create empty file / update timestamp | `touch newfile.txt` |
| `find` | Search for files and directories | `find . -name "*.log" -mtime -7` — logs modified in last 7 days |
| `locate` | Find files by name via database | `locate nginx.conf` |
| `tree` | Display directory structure as a tree | `tree -L 2` — limit to 2 levels deep |
| `stat` | Display file/filesystem status | `stat file.txt` |
| `file` | Determine file type | `file archive.tar.gz` |
| `ln` | Create hard/symbolic links | `ln -s /opt/app/config.yml config.yml` — symlink |

---

## 📖 File Viewing and Editing

| Command | Description | Example |
|---|---|---|
| `cat` | Concatenate and display file contents | `cat file1.txt file2.txt` |
| `tac` | Display file contents in reverse | `tac access.log` |
| `more` | View file page by page | `more longfile.txt` |
| `less` | View file with navigation | `less /var/log/syslog` |
| `head` | Display first lines of a file | `head -n 20 file.log` |
| `tail` | Display last lines of a file | `tail -f /var/log/syslog` — follow live updates |
| `nano` | Simple CLI text editor | `nano config.yml` |
| `vi` / `vim` | Modal text editor | `vim script.sh` |
| `sed` | Stream editor for filtering/transforming text | `sed 's/foo/bar/g' file.txt` — replace all `foo` with `bar` |
| `awk` | Pattern scanning and processing language | `awk '{print $1}' access.log` — print first column |
| `grep` | Search text using patterns | `grep -rn "TODO" ./src` — recursive, line numbers |
| `cut` | Remove sections from each line | `cut -d',' -f2 data.csv` — extract 2nd CSV field |
| `sort` | Sort lines of text | `sort -nr numbers.txt` — numeric, reverse |
| `uniq` | Report or omit repeated lines | `sort file.txt \| uniq -c` — count duplicates |
| `wc` | Count lines, words, and bytes | `wc -l file.txt` — count lines |

---

## 🔐 Permissions and Ownership

| Command | Description | Example |
|---|---|---|
| `chmod` | Change file mode/permissions | `chmod 755 script.sh` — rwxr-xr-x |
| `chown` | Change file owner and group | `sudo chown alice:devs file.txt` |
| `chgrp` | Change group ownership | `sudo chgrp devs file.txt` |
| `umask` | Set default file creation permissions | `umask 022` |
| `sudo` | Execute command as superuser | `sudo systemctl restart nginx` |
| `su` | Switch user identity | `su - alice` — switch and load alice's env |

---

## ⚙️ Process and Job Management

| Command | Description | Example |
|---|---|---|
| `ps` | Report process status | `ps aux \| grep nginx` |
| `top` | Real-time process viewer | `top` |
| `htop` | Interactive process viewer (if installed) | `htop` |
| `pstree` | Display process tree | `pstree -p` — show PIDs |
| `kill` | Send signal to a process | `kill -9 1234` — force kill PID 1234 |
| `killall` | Kill processes by name | `killall firefox` |
| `pkill` | Kill processes by pattern | `pkill -f "node server.js"` |
| `nice` | Run command with modified priority | `nice -n 10 ./build.sh` |
| `renice` | Alter priority of running process | `renice -n 5 -p 1234` |
| `bg` | Resume job in background | `bg %1` |
| `fg` | Bring job to foreground | `fg %1` |
| `jobs` | List active jobs | `jobs -l` |
| `nohup` | Run command immune to hangups | `nohup ./long_task.sh &` |

---

## 💾 Disk and Filesystem

| Command | Description | Example |
|---|---|---|
| `df` | Report filesystem disk space usage | `df -h` — human-readable sizes |
| `du` | Estimate file/directory space usage | `du -sh ./project` — summary, human-readable |
| `mount` | Mount a filesystem | `sudo mount /dev/sdb1 /mnt/data` |
| `umount` | Unmount a filesystem | `sudo umount /mnt/data` |
| `lsblk` | List block devices | `lsblk` |
| `blkid` | Locate/print block device attributes | `sudo blkid /dev/sda1` |
| `fdisk` | Partition table manipulator | `sudo fdisk -l` — list partitions |
| `parted` | GNU partition editor | `sudo parted /dev/sda print` |
| `mkfs` | Build a Linux filesystem | `sudo mkfs.ext4 /dev/sdb1` |
| `fsck` | Filesystem consistency check/repair | `sudo fsck /dev/sdb1` |
| `dd` | Convert and copy files/disks | `sudo dd if=image.iso of=/dev/sdb bs=4M status=progress` |
| `sync` | Flush filesystem buffers | `sync` |

---

## 🌐 Networking

| Command | Description | Example |
|---|---|---|
| `ip` | Show/manipulate routing, devices, tunnels | `ip a` — shorthand for `ip addr` |
| `ifconfig` | Configure network interfaces (legacy) | `ifconfig eth0` |
| `ip addr` | Display IP addresses | `ip addr show eth0` |
| `ip route` | Show/manipulate route table | `ip route show` |
| `ping` | Send ICMP ECHO requests | `ping -c 4 8.8.8.8` |
| `traceroute` / `tracepath` | Trace network path to host | `traceroute example.com` |
| `netstat` | Network statistics (legacy) | `netstat -tuln` |
| `ss` | Socket statistics | `ss -tulnp` |
| `curl` | Transfer data from/to a server | `curl -I https://example.com` |
| `wget` | Download files from the web | `wget -c https://example.com/file.zip` |
| `scp` | Secure copy over SSH | `scp file.txt user@host:/remote/path/` |
| `rsync` | Fast incremental file transfer | `rsync -avz src/ user@host:/backup/` |
| `ssh` | OpenSSH remote login client | `ssh -i key.pem user@192.168.1.10` |
| `hostname` | Show or set system hostname | `hostname -I` — show IP addresses |
| `nmcli` | NetworkManager CLI tool | `nmcli device status` |

---

## 📦 Package Management

| Command | Description | Example |
|---|---|---|
| `apt` / `apt-get` | Debian/Ubuntu package manager | `sudo apt update && sudo apt upgrade` |
| `dpkg` | Debian package manager | `dpkg -l \| grep nginx` |
| `yum` | RPM package manager (older CentOS/RHEL) | `sudo yum install httpd` |
| `dnf` | Modern Fedora/CentOS/RHEL manager | `sudo dnf update` |
| `rpm` | RPM package manager | `rpm -qa \| grep openssl` |
| `zypper` | Package manager for openSUSE | `sudo zypper install vim` |
| `pacman` | Package manager for Arch Linux | `sudo pacman -Syu` |

---

## 🖥️ System Information

| Command | Description | Example |
|---|---|---|
| `uname` | Print system information | `uname -a` — all info |
| `hostnamectl` | Control the system hostname | `hostnamectl status` |
| `dmesg` | Print kernel ring buffer messages | `dmesg \| tail -20` |
| `uptime` | Show system uptime | `uptime` |
| `free` | Display memory usage | `free -h` |
| `vmstat` | Report virtual memory statistics | `vmstat 2 5` — every 2s, 5 times |
| `lscpu` | Display CPU architecture info | `lscpu` |
| `lsusb` | List USB devices | `lsusb` |
| `lspci` | List PCI devices | `lspci -v` |
| `who` | Show who is logged on | `who` |
| `w` | Show who is logged on and doing what | `w` |
| `last` | Show last logins | `last -n 10` |

---

## 🗜️ Archive and Compression

| Command | Description | Example |
|---|---|---|
| `tar` | Archive files | `tar -czvf backup.tar.gz ./project` — create gzip archive |
| `gzip` | Compress files | `gzip file.txt` |
| `gunzip` | Decompress gzipped files | `gunzip file.txt.gz` |
| `bzip2` | Compress with Burrows-Wheeler algorithm | `bzip2 file.txt` |
| `bunzip2` | Decompress bzip2 files | `bunzip2 file.txt.bz2` |
| `zip` | Package and compress files | `zip -r archive.zip ./folder` |
| `unzip` | Extract zip archives | `unzip archive.zip -d ./output` |
| `xz` | Compress with LZMA | `xz file.txt` |
| `unxz` | Decompress xz files | `unxz file.txt.xz` |
| `7z` | Archive with 7-Zip format (if installed) | `7z x archive.7z` |

---

## 🧰 Text Processing and Shell Utilities

| Command | Description | Example |
|---|---|---|
| `echo` | Display a line of text | `echo "Deployment complete"` |
| `printf` | Format and print data | `printf "%s: %d\n" "count" 5` |
| `expr` | Evaluate expressions | `expr 5 + 3` |
| `test` / `[` | Evaluate conditional expressions | `[ -f file.txt ] && echo "exists"` |
| `date` | Display or set date and time | `date "+%Y-%m-%d %H:%M:%S"` |
| `env` | Print environment / run in modified env | `env \| grep PATH` |
| `export` | Set environment variables | `export PATH=$PATH:/opt/bin` |
| `alias` | Create command aliases | `alias ll='ls -la'` |
| `unalias` | Remove command aliases | `unalias ll` |
| `history` | Show command history | `history \| tail -20` |
| `clear` | Clear terminal screen | `clear` |
| `sleep` | Delay for a specified time | `sleep 5` |
| `watch` | Execute a program periodically | `watch -n 2 df -h` — every 2 seconds |
| `xargs` | Build/execute commands from stdin | `find . -name "*.tmp" \| xargs rm` |

---

## 👥 User and Group Management

| Command | Description | Example |
|---|---|---|
| `useradd` | Create a new user | `sudo useradd -m -s /bin/bash alice` |
| `userdel` | Delete a user | `sudo userdel -r alice` — remove home dir too |
| `usermod` | Modify a user account | `sudo usermod -aG sudo alice` — add to sudo group |
| `passwd` | Change user password | `passwd alice` |
| `groupadd` | Create a new group | `sudo groupadd devs` |
| `groupdel` | Delete a group | `sudo groupdel devs` |
| `groupmod` | Modify a group | `sudo groupmod -n developers devs` |
| `id` | Print user and group identity | `id alice` |
| `getent` | Get entries from administrative database | `getent passwd alice` |

---

## 🛠️ System Services and Logs

| Command | Description | Example |
|---|---|---|
| `systemctl` | Control the systemd manager | `sudo systemctl restart nginx` |
| `journalctl` | Query the systemd journal | `journalctl -u nginx --since "1 hour ago"` |
| `service` | Run a SysV init script (legacy) | `sudo service nginx restart` |
| `systemd-analyze` | Analyze boot performance | `systemd-analyze blame` |
| `timedatectl` | Control system time and date | `timedatectl set-timezone UTC` |

---

## 🔏 Access Control Lists

| Command | Description | Example |
|---|---|---|
| `setfacl` | Set file access control lists | `setfacl -m u:alice:rwx file.txt` |
| `getfacl` | Get file access control lists | `getfacl file.txt` |

---

## ⌨️ Helpful Shell Shortcuts

| Shortcut | Description |
|---|---|
| `Ctrl+C` | Cancel a running command |
| `Ctrl+Z` | Suspend the current job |
| `Ctrl+D` | Log out of shell or send EOF |
| `!!` | Repeat the last command (e.g. `sudo !!`) |
| `!$` | Last argument of previous command |
| `!n` | Run command number `n` from history |
| `history \| grep <term>` | Search command history |

---

## 📋 Quick Reference Table

| Category | Key Commands |
|---|---|
| File & Directory Ops | `ls`, `cd`, `mkdir`, `rm`, `cp`, `mv`, `find` |
| Viewing & Editing | `cat`, `less`, `tail`, `grep`, `sed`, `awk` |
| Permissions | `chmod`, `chown`, `sudo`, `su` |
| Processes | `ps`, `top`, `kill`, `nohup` |
| Disk & Filesystem | `df`, `du`, `mount`, `lsblk`, `dd` |
| Networking | `ip`, `ping`, `ss`, `curl`, `ssh`, `rsync` |
| Package Management | `apt`, `dnf`, `yum`, `pacman` |
| System Info | `uname`, `free`, `uptime`, `dmesg` |
| Archive/Compression | `tar`, `zip`, `gzip`, `xz` |
| Shell Utilities | `echo`, `xargs`, `watch`, `history` |
| User Management | `useradd`, `usermod`, `passwd`, `id` |
| Services & Logs | `systemctl`, `journalctl` |
| Access Control | `setfacl`, `getfacl` |

---

## 📝 Notes

This cheat sheet is a concise collection of common commands but not an exhaustive list of every Linux command. Use each command's `--help` option or `man` pages for full syntax and options — for example:
```bash
man ls
ls --help
```

*💡 Tip: Combine `man -k <keyword>` to search man pages by topic when you don't remember the exact command name (e.g. `man -k partition`).*