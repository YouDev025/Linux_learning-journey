# Linux Commands Cheat Sheet

This reference includes common Linux commands organized by topic. Use it as a quick lookup for file operations, system management, networking, package management, shell utilities, and more.

## File and Directory Operations

- `ls` — list directory contents
- `cd` — change directory
- `pwd` — print current directory
- `mkdir` — create directory
- `rmdir` — remove empty directory
- `rm` — remove files or directories
- `cp` — copy files and directories
- `mv` — move or rename files and directories
- `touch` — create an empty file or update timestamp
- `find` — search for files and directories
- `locate` — find files by name using database
- `tree` — display directory structure as a tree
- `stat` — display file or filesystem status
- `file` — determine file type
- `ln` — create hard and symbolic links

## File Viewing and Editing

- `cat` — concatenate and display file contents
- `tac` — display file contents in reverse
- `more` — view file contents page by page
- `less` — view file contents with navigation
- `head` — display first lines of a file
- `tail` — display last lines of a file
- `nano` — simple command-line text editor
- `vi` / `vim` — modal text editor
- `sed` — stream editor for filtering and transforming text
- `awk` — pattern scanning and processing language
- `grep` — search text using patterns
- `cut` — remove sections from each line of files
- `sort` — sort lines of text
- `uniq` — report or omit repeated lines
- `wc` — count lines, words, and bytes

## Permissions and Ownership

- `chmod` — change file modes or permissions
- `chown` — change file owner and group
- `chgrp` — change group ownership
- `umask` — set default file creation permissions
- `sudo` — execute command as superuser or another user
- `su` — switch user identity

## Process and Job Management

- `ps` — report process status
- `top` — display dynamic real-time process viewer
- `htop` — interactive process viewer (if installed)
- `pstree` — display process tree
- `kill` — send signals to processes
- `killall` — kill processes by name
- `pkill` — send signal to processes by pattern
- `nice` — run a command with modified scheduling priority
- `renice` — alter priority of running process
- `bg` — resume job in background
- `fg` — bring job to foreground
- `jobs` — list active jobs
- `nohup` — run command immune to hangups

## Disk and Filesystem

- `df` — report filesystem disk space usage
- `du` — estimate file and directory space usage
- `mount` — mount filesystem
- `umount` — unmount filesystem
- `lsblk` — list block devices
- `blkid` — locate/print block device attributes
- `fdisk` — partition table manipulator for Linux
- `parted` — GNU partition editor
- `mkfs` — build a Linux filesystem
- `fsck` — filesystem consistency check and repair
- `dd` — convert and copy a file, including disks
- `sync` — flush filesystem buffers

## Networking

- `ip` — show/manipulate routing, devices, policy routing, and tunnels
- `ifconfig` — configure network interfaces (legacy)
- `ip addr` — display IP addresses
- `ip route` — show/manipulate route table
- `ping` — send ICMP ECHO requests to network hosts
- `traceroute` / `tracepath` — trace network path to host
- `netstat` — network statistics (legacy)
- `ss` — socket statistics
- `curl` — transfer data from or to a server
- `wget` — download files from the web
- `scp` — secure copy over SSH
- `rsync` — fast incremental file transfer
- `ssh` — openSSH remote login client
- `hostname` — show or set system hostname
- `nmcli` — NetworkManager command-line tool

## Package Management

- `apt` / `apt-get` — Debian/Ubuntu package manager
- `dpkg` — Debian package manager
- `yum` — RPM package manager for older CentOS/RHEL
- `dnf` — modern Fedora/CentOS/RHEL package manager
- `rpm` — RPM package manager
- `zypper` — package manager for openSUSE
- `pacman` — package manager for Arch Linux

## System Information

- `uname` — print system information
- `hostnamectl` — control the system hostname
- `dmesg` — print kernel ring buffer messages
- `uptime` — show how long the system has been running
- `free` — display memory usage
- `vmstat` — report virtual memory statistics
- `lscpu` — display CPU architecture information
- `lsusb` — list USB devices
- `lspci` — list PCI devices
- `uname -r` — show kernel release
- `who` — show who is logged on
- `w` — show who is logged on and what they are doing
- `last` — show last logins

## Archive and Compression

- `tar` — archive files
- `gzip` — compress files
- `gunzip` — decompress gzipped files
- `bzip2` — compress files with Burrows-Wheeler algorithm
- `bunzip2` — decompress bzip2 files
- `zip` — package and compress files
- `unzip` — extract zip archives
- `xz` — compress files with LZMA
- `unxz` — decompress xz files
- `7z` — archive with 7-Zip format (if installed)

## Text Processing and Shell Utilities

- `echo` — display a line of text
- `printf` — format and print data
- `expr` — evaluate expressions
- `test` / `[` — evaluate conditional expressions
- `date` — display or set date and time
- `env` — print environment or run command in modified environment
- `export` — set environment variables
- `alias` — create command aliases
- `unalias` — remove command aliases
- `history` — show command history
- `clear` — clear terminal screen
- `sleep` — delay for a specified time
- `watch` — execute a program periodically
- `xargs` — build and execute command lines from standard input

## User and Group Management

- `useradd` — create a new user
- `userdel` — delete a user
- `usermod` — modify a user account
- `passwd` — change user password
- `groupadd` — create a new group
- `groupdel` — delete a group
- `groupmod` — modify a group
- `id` — print user and group identity
- `getent` — get entries from administrative database

## System Services and Logs

- `systemctl` — control the systemd system and service manager
- `journalctl` — query the systemd journal
- `service` — run a SysV init script (legacy)
- `systemd-analyze` — analyze system boot performance
- `timedatectl` — control system time and date
- `hostnamectl` — control system hostname

## Permissions and Security

- `chmod` — change file permissions
- `chown` — change file owner and group
- `chgrp` — change group ownership
- `setfacl` — set file access control lists
- `getfacl` — get file access control lists
- `sudo` — execute a command as another user

## Filesystem and Storage

- `mount` — mount a filesystem
- `umount` — unmount a filesystem
- `df` — show filesystem disk space usage
- `du` — estimate file space usage
- `lsblk` — list block devices
- `fdisk` — manipulate disk partition table
- `blkid` — locate/print block device attributes

## Helpful Shell Shortcuts

- `Ctrl+C` — cancel a running command
- `Ctrl+Z` — suspend the current job
- `Ctrl+D` — log out of shell or send EOF
- `!!` — repeat the last command
- `!$` — last argument of previous command
- `!n` — run command n from history
- `history | grep` — search command history

---

## Notes

This cheat sheet is a concise collection of common commands but not an exhaustive list of every Linux command. Use each command's `--help` option or `man` pages for full syntax and options, for example `man ls` or `ls --help`.
