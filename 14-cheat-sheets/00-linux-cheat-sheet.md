# Linux Cheat Sheet

Quick reference for the most commonly used Linux commands, organized by topic.

---

## 📁 Navigation

| Command | Description |
|---|---|
| `pwd` | Print working directory |
| `cd /path` | Change to absolute path |
| `cd ..` | Move up one level |
| `cd -` | Return to previous directory |
| `cd ~` | Go to home directory |
| `ls` | List directory contents |
| `ls -la` | Long format, include hidden files |
| `ls -lh` | Human-readable file sizes |
| `tree -L 2` | Directory tree, 2 levels deep |
| `which cmd` | Locate a command's binary |
| `type cmd` | Show how a name is resolved |

---

## 📄 File Operations

| Command | Description |
|---|---|
| `cp src dst` | Copy a file |
| `cp -r src/ dst/` | Copy directory recursively |
| `mv src dst` | Move or rename |
| `rm file` | Delete a file |
| `rm -rf dir/` | Delete directory (no prompt) |
| `mkdir -p a/b/c` | Create nested directories |
| `touch file` | Create empty file |
| `ln -s src link` | Create symbolic link |
| `ln src link` | Create hard link |
| `find . -name "*.sh"` | Find files by name pattern |
| `find . -type f -mtime -1` | Files modified in last 24h |
| `find . -perm -4000` | Find SUID files |

---

## 🗜️ Archiving & Compression

| Command | Description |
|---|---|
| `tar -czvf archive.tar.gz dir/` | Compress directory |
| `tar -xzvf archive.tar.gz` | Extract archive |
| `tar -tvf archive.tar.gz` | List contents without extracting |
| `gzip file` | Compress a single file |
| `gunzip file.gz` | Decompress a file |
| `zip -r archive.zip dir/` | Create zip archive |
| `unzip archive.zip` | Extract zip archive |

---

## 🔒 Permissions

| Command | Description |
|---|---|
| `chmod 644 file` | `rw-r--r--` (numeric) |
| `chmod 755 file` | `rwxr-xr-x` (executable) |
| `chmod 600 file` | Owner read/write only (secrets) |
| `chmod u+x file` | Add execute for owner |
| `chmod -R 750 dir/` | Recursive permission set |
| `chown user file` | Change owner |
| `chown user:group file` | Change owner and group |
| `chgrp group file` | Change group only |
| `chmod +t dir/` | Set sticky bit |
| `chmod u+s file` | Set setuid bit |
| `chmod g+s dir/` | Set setgid bit |
| `umask 022` | Default creation mask |
| `ls -Z file` | Show SELinux context |
| `getfacl file` | Show ACL entries |
| `setfacl -m u:user:rw file` | Add ACL entry |

---

## 👤 Users & Groups

| Command | Description |
|---|---|
| `whoami` | Current username |
| `id` | Current user, UID, GID, groups |
| `groups username` | List groups a user belongs to |
| `useradd -m -s /bin/bash user` | Create user with home dir |
| `passwd username` | Set or change password |
| `usermod -aG group user` | Add to group (safe append) |
| `usermod -s /usr/sbin/nologin user` | Disable interactive login |
| `userdel -r user` | Delete user and home directory |
| `groupadd groupname` | Create a group |
| `gpasswd -a user group` | Add user to group |
| `gpasswd -d user group` | Remove user from group |
| `groupdel groupname` | Delete a group |
| `chage -l username` | Show password aging info |
| `chage -M 90 username` | Set 90-day max password age |
| `chage -d 0 username` | Force password change at next login |
| `faillock --user username` | View login failure count |
| `faillock --user username --reset` | Unlock a locked account |

---

## 🔑 sudo

| Command | Description |
|---|---|
| `sudo command` | Run command as root |
| `sudo -u user command` | Run as a specific user |
| `sudo -i` | Start interactive root shell |
| `sudo -l` | List your sudo permissions |
| `sudo visudo` | Edit sudoers file safely |
| `sudo visudo -f /etc/sudoers.d/file` | Edit a drop-in rule file |

---

## ⚙️ Process Management

| Command | Description |
|---|---|
| `ps aux` | All processes, full detail |
| `ps -eo pid,ppid,user,%cpu,%mem,cmd` | Custom output format |
| `pstree -p` | Process tree with PIDs |
| `top` | Live interactive process view |
| `htop` | Friendlier top with tree view |
| `kill -TERM PID` | Graceful termination |
| `kill -9 PID` | Force kill (uncatchable) |
| `pkill -f pattern` | Kill by command pattern |
| `killall name` | Kill all processes by name |
| `nice -n 10 cmd` | Start with low priority |
| `renice -n 5 -p PID` | Change running process priority |
| `jobs -l` | List shell background jobs |
| `fg %1` | Bring job 1 to foreground |
| `bg %1` | Resume job 1 in background |
| `nohup cmd &` | Run immune to terminal close |

---

## 📡 Signals

| Signal | Number | Meaning |
|---|---|---|
| `SIGHUP` | 1 | Reload config (daemons) |
| `SIGINT` | 2 | Interrupt (Ctrl+C) |
| `SIGKILL` | 9 | Force kill (uncatchable) |
| `SIGTERM` | 15 | Graceful stop (default) |
| `SIGSTOP` | 19 | Pause process |
| `SIGCONT` | 18 | Resume paused process |

---

## 📦 Package Management (APT)

| Command | Description |
|---|---|
| `apt update` | Refresh package index |
| `apt upgrade` | Upgrade installed packages |
| `apt full-upgrade` | Upgrade + resolve dependency changes |
| `apt install pkg` | Install a package |
| `apt remove pkg` | Remove (keep config files) |
| `apt purge pkg` | Remove and config files |
| `apt autoremove` | Remove unused dependencies |
| `apt search keyword` | Search available packages |
| `apt show pkg` | Show package details |
| `apt list --installed` | List installed packages |
| `dpkg -L pkg` | Files installed by a package |
| `dpkg -S /path/to/file` | Which package owns a file |
| `apt-mark hold pkg` | Prevent package from upgrading |
| `apt-mark unhold pkg` | Allow upgrades again |

---

## 📦 Package Management (DNF / RPM)

| Command | Description |
|---|---|
| `dnf check-update` | List available updates |
| `dnf upgrade` | Upgrade all packages |
| `dnf install pkg` | Install a package |
| `dnf remove pkg` | Remove a package |
| `dnf search keyword` | Search packages |
| `dnf info pkg` | Show package details |
| `dnf history list` | Show transaction history |
| `dnf history undo N` | Roll back transaction N |
| `dnf upgrade --security` | Security updates only |
| `rpm -qa \| grep pkg` | Query installed RPMs |
| `rpm -qi pkg` | Full package info |
| `rpm -ql pkg` | Files installed by package |
| `rpm -qf /path/to/file` | Which package owns a file |
| `rpm -V pkg` | Verify installed files |

---

## 🌐 Networking

| Command | Description |
|---|---|
| `ip addr show` | Show IP addresses |
| `ip route show` | Show routing table |
| `ip route show default` | Show default gateway |
| `ping -c 4 host` | Test reachability (4 packets) |
| `traceroute -n host` | Trace hops (no DNS) |
| `mtr host` | Combined ping + traceroute |
| `ss -tuln` | Listening ports (TCP+UDP) |
| `ss -tulnp` | Listening ports + process |
| `ss -tn state established` | Active TCP connections |
| `dig host +short` | Quick DNS lookup |
| `dig @8.8.8.8 host` | Query specific DNS server |
| `dig -x IP +short` | Reverse DNS lookup |
| `host hostname` | Simple DNS lookup |
| `curl -sf URL` | Fetch URL, silent on error |
| `wget URL` | Download a file |
| `tcpdump -i eth0 -n` | Capture packets (no DNS) |
| `tcpdump -i eth0 port 80` | Capture filtered by port |
| `nmap localhost` | Scan local open ports |

---

## 🔥 Firewall (ufw)

| Command | Description |
|---|---|
| `ufw status verbose` | Firewall status and rules |
| `ufw default deny incoming` | Set default-deny policy |
| `ufw allow ssh` | Allow SSH (port 22) |
| `ufw limit ssh` | Rate-limit SSH (brute-force protection) |
| `ufw allow 80/tcp` | Allow HTTP |
| `ufw allow "Nginx Full"` | Allow HTTP + HTTPS via app profile |
| `ufw allow from IP to any port 22` | Restrict port by source IP |
| `ufw deny 23` | Explicitly deny a port |
| `ufw delete allow 80` | Remove a rule |
| `ufw logging medium` | Enable firewall logging |
| `ufw enable` | Activate the firewall |
| `ufw disable` | Disable the firewall |

---

## 🔐 SSH

| Command | Description |
|---|---|
| `ssh user@host` | Connect to remote host |
| `ssh -p 2222 user@host` | Custom port |
| `ssh-keygen -t ed25519` | Generate a key pair |
| `ssh-copy-id user@host` | Install public key on remote |
| `ssh-add ~/.ssh/id_ed25519` | Add key to SSH agent |
| `chmod 600 ~/.ssh/id_*` | Fix key permissions |
| `scp src user@host:dst` | Copy file over SSH |
| `rsync -avz src/ user@host:dst/` | Efficient sync over SSH |
| `ssh -L 8080:localhost:80 host` | Local port forwarding |
| `ssh -J bastion target` | Jump through a bastion host |

---

## 💾 Storage & Disks

| Command | Description |
|---|---|
| `df -h` | Disk usage, all filesystems |
| `du -sh dir/` | Total size of a directory |
| `du -ah . \| sort -rh \| head` | Largest files/dirs |
| `lsblk -f` | Block devices + filesystems |
| `blkid /dev/sda1` | UUID and filesystem type |
| `mount /dev/sdb1 /mnt/pt` | Mount a filesystem |
| `umount /mnt/pt` | Unmount |
| `mkfs.ext4 /dev/sdX1` | Format as ext4 |
| `mkfs.xfs /dev/sdX1` | Format as XFS |
| `fdisk /dev/sdX` | Interactive partitioning |
| `parted /dev/sdX print` | Show partition table |
| `sync` | Flush pending writes to disk |

---

## 🗂️ LVM

| Command | Description |
|---|---|
| `pvcreate /dev/sdX` | Initialize physical volume |
| `pvs` | List physical volumes |
| `vgcreate vg /dev/sdX` | Create volume group |
| `vgs` | List volume groups |
| `lvcreate -n lv -L 10G vg` | Create logical volume |
| `lvs` | List logical volumes |
| `lvextend -r -L +5G /dev/vg/lv` | Grow LV + filesystem |
| `lvcreate -s -n snap -L 2G /dev/vg/lv` | Create snapshot |
| `lvconvert --merge /dev/vg/snap` | Restore from snapshot |
| `lvremove /dev/vg/lv` | Remove a logical volume |

---

## 🔐 Encryption (LUKS)

| Command | Description |
|---|---|
| `cryptsetup luksFormat /dev/sdX1` | Create encrypted volume |
| `cryptsetup luksOpen /dev/sdX1 name` | Unlock (open) volume |
| `cryptsetup luksClose name` | Lock (close) volume |
| `cryptsetup luksDump /dev/sdX1` | Show header + key slots |
| `cryptsetup luksAddKey /dev/sdX1` | Add a passphrase |
| `cryptsetup luksRemoveKey /dev/sdX1` | Remove a passphrase |
| `cryptsetup luksHeaderBackup /dev/sdX1 --header-backup-file f` | Back up LUKS header |

---

## ⚙️ Services (systemd)

| Command | Description |
|---|---|
| `systemctl status svc` | Show current status |
| `systemctl start svc` | Start now |
| `systemctl stop svc` | Stop now |
| `systemctl restart svc` | Full stop + start |
| `systemctl reload svc` | Reload config (no downtime) |
| `systemctl enable svc` | Start at boot |
| `systemctl disable svc` | Don't start at boot |
| `systemctl enable --now svc` | Enable AND start together |
| `systemctl is-active svc` | Active or inactive? |
| `systemctl is-enabled svc` | Enabled or disabled? |
| `systemctl daemon-reload` | Reload unit files after edit |
| `systemctl list-units --type=service` | List all services |
| `systemctl list-units --state=failed` | Show failed services |
| `systemd-analyze verify unit.service` | Validate unit file syntax |

---

## 📋 Logs (journald)

| Command | Description |
|---|---|
| `journalctl -f` | Follow all logs live |
| `journalctl -e` | Jump to most recent entries |
| `journalctl -u svc` | Logs for a specific service |
| `journalctl -u svc -f` | Follow a service's logs live |
| `journalctl -u svc -p err` | Errors only |
| `journalctl -b` | Logs from current boot |
| `journalctl -b -1` | Logs from previous boot |
| `journalctl --since "1 hour ago"` | Filter by time |
| `journalctl -k` | Kernel messages only |
| `journalctl --disk-usage` | Journal disk consumption |
| `journalctl --vacuum-size=200M` | Shrink journal |
| `journalctl --vacuum-time=2weeks` | Remove old entries |

---

## 📊 Performance

| Command | Description |
|---|---|
| `top` | Live process + resource view |
| `htop` | Friendlier interactive top |
| `vmstat 2` | CPU/memory/swap/IO every 2s |
| `iostat -x 2` | Disk I/O with await + %util |
| `iotop -o` | Per-process disk I/O (active only) |
| `mpstat -P ALL 2` | Per-core CPU breakdown |
| `free -h` | Memory (check `available` column) |
| `sar -u 2 5` | CPU usage, 5 samples |
| `sar -u -f /var/log/sysstat/saNN` | Historical CPU data |
| `uptime` | Load averages (1/5/15 min) |
| `nproc` | Number of CPU cores |
| `dstat -cdn` | CPU + disk + network combined |

---

## 🎛️ Kernel Tuning (sysctl)

| Command | Description |
|---|---|
| `sysctl -a` | List all kernel parameters |
| `sysctl vm.swappiness` | Read a parameter |
| `sudo sysctl vm.swappiness=10` | Change temporarily |
| `sudo sysctl --system` | Apply all sysctl.d files |
| `/etc/sysctl.d/99-custom.conf` | File for persistent changes |

**Common parameters:**

| Parameter | Purpose |
|---|---|
| `vm.swappiness = 10` | Reduce swap aggressiveness |
| `net.core.somaxconn = 4096` | Increase connection backlog |
| `fs.file-max = 2097152` | System-wide file descriptor limit |

---

## 🔍 Text Processing

| Command | Description |
|---|---|
| `grep "pattern" file` | Search for a pattern |
| `grep -i "pattern" file` | Case-insensitive |
| `grep -r "pattern" dir/` | Recursive search |
| `grep -v "pattern" file` | Invert match |
| `grep -c "pattern" file` | Count matching lines |
| `grep -n "pattern" file` | Show line numbers |
| `grep -A 3 "pattern" file` | 3 lines after match |
| `sed 's/old/new/g' file` | Global find-replace |
| `sed -i.bak 's/old/new/g' f` | In-place with backup |
| `sed -n '5,10p' file` | Print lines 5–10 |
| `awk '{print $1}' file` | Print first field |
| `awk -F: '{print $1}' file` | Custom delimiter |
| `awk '/ERROR/ {print $0}'` | Filter by pattern |
| `cut -d, -f2 file` | Extract CSV column 2 |
| `sort -n file` | Numeric sort |
| `sort -rn file` | Reverse numeric sort |
| `sort \| uniq -c` | Count occurrences |
| `tr 'a-z' 'A-Z'` | Translate characters |
| `tr -d '\r'` | Delete carriage returns |

---

## 🔁 Piping & Redirection

| Syntax | Description |
|---|---|
| `cmd1 \| cmd2` | Pipe stdout of cmd1 to cmd2 |
| `cmd > file` | Redirect stdout (overwrite) |
| `cmd >> file` | Redirect stdout (append) |
| `cmd 2> file` | Redirect stderr only |
| `cmd > file 2>&1` | Redirect both stdout + stderr |
| `cmd 2>/dev/null` | Discard stderr |
| `cmd < file` | Use file as stdin |
| `cmd \| tee file` | Write to file AND show output |

---

## 🐚 Shell & Scripting

| Command / Syntax | Description |
|---|---|
| `Ctrl+R` | Reverse-search history |
| `!!` | Re-run previous command |
| `sudo !!` | Re-run previous with sudo |
| `!$` | Last argument of previous command |
| `history 20` | Show last 20 history entries |
| `export VAR=value` | Set environment variable |
| `unset VAR` | Remove a variable |
| `echo ${VAR:-default}` | Default if unset |
| `echo ${VAR:?error}` | Error if unset |
| `result=$(command)` | Command substitution |
| `source ~/.bashrc` | Reload bashrc in current shell |

**Scripting best practices:**

| Syntax | Description |
|---|---|
| `#!/usr/bin/env bash` | Portable shebang |
| `set -euo pipefail` | Strict mode |
| `local varname=value` | Scope variable to function |
| `"${1:-default}"` | Default argument value |
| `bash -x script.sh` | Trace every command |
| `bash -n script.sh` | Syntax check only |

---

## 🛡️ Security

| Command | Description |
|---|---|
| `getenforce` | SELinux current mode |
| `setenforce 0` | Switch to permissive (temp) |
| `setenforce 1` | Switch to enforcing |
| `restorecon -Rv /path` | Fix SELinux file contexts |
| `chcon -t httpd_sys_content_t file` | Set a context manually |
| `ausearch -k label` | Search audit log by key |
| `auditctl -w /etc/passwd -p wa -k changes` | Watch file for writes |
| `aureport --summary` | Audit log summary |
| `aa-status` | AppArmor profile summary |
| `aa-enforce /etc/apparmor.d/profile` | Enforce a profile |
| `aa-complain /etc/apparmor.d/profile` | Set profile to complain mode |
| `aide --check` | File integrity check |
| `aide --update` | Update AIDE baseline |
| `lynis audit system` | General security audit |

---

## 🐚 Job Control

| Command | Description |
|---|---|
| `command &` | Start in background |
| `Ctrl+Z` | Suspend foreground job |
| `fg` | Resume in foreground |
| `bg` | Resume in background |
| `jobs -l` | List jobs with PIDs |
| `kill %1` | Kill job number 1 |
| `nohup cmd &` | Immune to terminal close |
| `tmux new -s name` | Start named tmux session |
| `tmux attach -t name` | Re-attach to session |
| `Ctrl+b d` | Detach from tmux |

---

## 🔢 Permission Reference

### Numeric (octal) modes

| Mode | Symbolic | Meaning |
|---|---|---|
| `7` | `rwx` | Read + write + execute |
| `6` | `rw-` | Read + write |
| `5` | `r-x` | Read + execute |
| `4` | `r--` | Read only |
| `0` | `---` | No permissions |

### Common permission sets

| Mode | Meaning | Use case |
|---|---|---|
| `755` | `rwxr-xr-x` | Scripts, public dirs |
| `644` | `rw-r--r--` | Regular files |
| `700` | `rwx------` | Private scripts |
| `600` | `rw-------` | Private files, SSH keys |
| `2775` | setgid + `rwxrwxr-x` | Shared team directories |
| `1777` | sticky + `rwxrwxrwx` | Shared temp directories |

---

## 📂 Key Directory Reference

| Path | Purpose |
|---|---|
| `/etc` | System-wide configuration |
| `/etc/passwd` | User account database |
| `/etc/shadow` | Password hashes |
| `/etc/group` | Group database |
| `/etc/sudoers` | sudo policy |
| `/etc/fstab` | Persistent mount configuration |
| `/etc/ssh/sshd_config` | SSH daemon configuration |
| `/etc/systemd/system/` | Custom service unit files |
| `/etc/sysctl.d/` | Persistent kernel parameters |
| `/etc/audit/rules.d/` | auditd rules |
| `/var/log` | System and application logs |
| `/proc` | Kernel runtime data (virtual) |
| `/sys` | Hardware and kernel parameters |
| `/tmp` | Temporary files (cleared on reboot) |
| `/dev` | Device files |
| `/usr/bin`, `/usr/sbin` | System binaries |
| `/home/user` | User home directories |
| `/root` | Root user home |
| `/mnt`, `/media` | Mountpoints |