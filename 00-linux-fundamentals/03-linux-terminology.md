# Linux Terminology

 
---

# CLI vs GUI

## CLI (Command Line Interface)

A CLI allows users to interact with the system by typing commands.

Examples:

```bash
ls
pwd
cd /home
```

### Advantages

- Fast and efficient
- Uses fewer system resources
- Ideal for automation and scripting
- Preferred by system administrators and cybersecurity professionals

### Examples

- Bash
- Zsh
- Fish

---

## GUI (Graphical User Interface)

A GUI allows users to interact using windows, icons, menus, and a mouse.

Examples:

- GNOME
- KDE Plasma
- XFCE

### Advantages

- Easy to learn
- User-friendly
- Visual interaction

### Examples

- Ubuntu Desktop
- Linux Mint
- Fedora Workstation

---

# Terminal

A **terminal** is an application that provides access to a command-line interface.

Examples:

- GNOME Terminal
- Konsole
- xterm
- Terminator

Think of a terminal as a window where you can interact with a shell.

---

# Shell

A **shell** is a command interpreter that receives user commands and communicates with the Linux kernel.

Popular shells:

- Bash
- Zsh
- Dash
- Fish

Example:

```bash
echo "Hello Linux"
```

The shell interprets the command and executes it.

---

# Session

A **session** is the period during which a user is logged into the system.

A session begins when:

```text
User Login
```

A session ends when:

```text
Logout
```

A user can have multiple active sessions simultaneously.

View logged-in users:

```bash
who
```

---

# Linux Distribution (Distro)

A Linux distribution is a complete operating system built around the Linux kernel.

A distribution includes:

- Linux kernel
- Package manager
- System tools
- Desktop environment (optional)

Examples:

- Ubuntu
- Debian
- Fedora
- Rocky Linux
- Arch Linux
- Kali Linux

---

# Process

A **process** is a running instance of a program.

Examples:

```bash
firefox
nginx
python
```

Each process has:

- PID (Process ID)
- Memory allocation
- CPU usage
- State

View running processes:

```bash
ps aux
```

or

```bash
top
```

---

# Thread

A **thread** is the smallest execution unit within a process.

A process may contain:

- One thread (single-threaded)
- Multiple threads (multi-threaded)

Benefits:

- Better performance
- Parallel execution
- Resource sharing

Example:

```text
Google Chrome
 ├─ Thread 1
 ├─ Thread 2
 ├─ Thread 3
 └─ Thread 4
```

---

# Job

A **job** is a command or process managed by the shell.

Examples:

Run a job in background:

```bash
sleep 100 &
```

View jobs:

```bash
jobs
```

Bring job to foreground:

```bash
fg
```

Send job to background:

```bash
bg
```

---

# Daemon

A **daemon** is a background process that runs continuously and provides services.

Characteristics:

- Starts automatically
- Runs without user interaction
- Often ends with the letter "d"

Examples:

| Daemon | Purpose |
|----------|----------|
| sshd | SSH server |
| systemd | System manager |
| httpd | Web server |
| crond | Task scheduler |
| named | DNS server |

View running services:

```bash
systemctl list-units --type=service
```

---

# Service

A **service** is a program managed by the operating system to provide functionality.

Examples:

- SSH service
- Web server service
- Database service

Manage services:

Start a service:

```bash
sudo systemctl start ssh
```

Stop a service:

```bash
sudo systemctl stop ssh
```

Check status:

```bash
systemctl status ssh
```

---

# Common Linux File Types

## Regular File (-)

Stores data or text.

Examples:

```text
notes.txt
script.sh
report.pdf
```

---

## Directory (d)

Contains files and subdirectories.

Examples:

```text
/home
/etc
/var
```

---

## Symbolic Link (l)

A shortcut pointing to another file.

Create one:

```bash
ln -s file.txt shortcut.txt
```

---

## Character Device (c)

Provides access to hardware devices character by character.

Examples:

```text
/dev/tty
/dev/null
```

---

## Block Device (b)

Transfers data in blocks.

Examples:

```text
/dev/sda
/dev/nvme0n1
```

---

## Socket (s)

Used for communication between processes.

Examples:

```text
Docker sockets
Web server sockets
```

---

## Named Pipe (p)

Special file for process communication.

Create one:

```bash
mkfifo mypipe
```

---

# Viewing File Types

Use:

```bash
ls -l
```

Example:

```text
-rw-r--r--  file.txt
drwxr-xr-x  Documents
lrwxrwxrwx  shortcut
```

First character meaning:

| Symbol | Type |
|----------|----------|
| - | Regular file |
| d | Directory |
| l | Symbolic link |
| c | Character device |
| b | Block device |
| s | Socket |
| p | Named pipe |

---

# Common Linux Naming Conventions

## Hidden Files

Files beginning with a dot:

```text
.bashrc
.profile
.gitconfig
```

Show hidden files:

```bash
ls -la
```

---

## Configuration Files

Typically stored in:

```text
/etc
```

Examples:

```text
/etc/passwd
/etc/hosts
/etc/fstab
```

---

## Log Files

Typically stored in:

```text
/var/log
```

Examples:

```text
syslog
auth.log
kern.log
```

---

## Executable Files

Examples:

```text
script.sh
program
binary
```

Make executable:

```bash
chmod +x script.sh
```

---

# Key Takeaways

✅ CLI uses commands, while GUI uses graphical elements.

✅ A terminal provides access to a shell.

✅ A shell interprets commands and communicates with the kernel.

✅ A session represents a user's login period.

✅ A process is a running program.

✅ Threads are execution units inside a process.

✅ Jobs are processes managed by the shell.

✅ Daemons are background services.

✅ Linux supports several special file types beyond regular files.

✅ Understanding Linux terminology is essential for cybersecurity, system administration, and DevOps.

---

# Quick Reference

| Term | Definition |
|--------|------------|
| CLI | Command Line Interface |
| GUI | Graphical User Interface |
| Terminal | Program used to access a shell |
| Shell | Command interpreter |
| Session | User login period |
| Distro | Linux distribution |
| Process | Running program |
| Thread | Execution unit inside a process |
| Job | Shell-managed process |
| Daemon | Background service process |
| Service | System functionality managed by the OS |
| PID | Process Identifier |
| Symbolic Link | Shortcut to another file |
| Hidden File | File beginning with a dot (.) |