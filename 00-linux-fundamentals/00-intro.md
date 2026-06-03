# 🐧 Linux Fundamentals

> _The foundation of modern computing — servers, security, cloud, and embedded systems all run on Linux._

---

## 📖 Module Overview

This module introduces the core concepts, history, and philosophy behind Linux. By the end, you'll understand why Linux dominates the technology landscape and how to navigate it confidently from the command line.

---

## 🎯 Learning Objectives

By completing this module, you will be able to:

- Explain what Linux is, where it came from, and why it matters in modern computing
- Describe the open source ecosystem and the principles behind it
- Identify and differentiate popular Linux distributions suited for learning and professional use
- Navigate the Linux command line and terminal with confidence

---

## 📚 Topics Covered

### 1. What Linux Is — and Why It Matters

Linux is a free, open-source operating system kernel created by **Linus Torvalds** in 1991. Today it powers:

- 🌐 Over **96%** of the world's top web servers
- ☁️ The majority of cloud infrastructure (AWS, GCP, Azure)
- 🔒 Nearly every penetration testing and cybersecurity platform
- 📱 The Android operating system
- 🤖 Embedded systems, IoT devices, and supercomputers

Understanding Linux is not optional for anyone serious about technology — it _is_ the infrastructure.

---

### 2. The Open Source Ecosystem

Open source software is software whose source code is freely available for anyone to view, modify, and distribute.

| Concept                  | Description                                |
| ------------------------ | ------------------------------------------ |
| **Open Source**          | Source code is public and modifiable       |
| **Free Software (FOSS)** | Emphasizes user freedom, not just price    |
| **GPL License**          | Requires derivatives to remain open source |
| **Community Driven**     | Maintained by contributors worldwide       |

**Key figures & projects:**

- **Richard Stallman** — GNU Project, Free Software Foundation
- **Linus Torvalds** — Linux kernel
- **The Linux Foundation** — Stewardship of the Linux ecosystem

---

### 3. Common Linux Distributions for Learners

A **distribution (distro)** is a complete operating system built around the Linux kernel, bundled with software, a package manager, and a desktop environment.

| Distribution   | Best For                   | Package Manager | Notes                                   |
| -------------- | -------------------------- | --------------- | --------------------------------------- |
| **Ubuntu**     | Beginners, general use     | `apt`           | Largest community, great documentation  |
| **Kali Linux** | Cybersecurity & pentesting | `apt`           | 600+ pre-installed security tools       |
| **Parrot OS**  | Security & privacy         | `apt`           | Lighter than Kali, beginner-friendly    |
| **Fedora**     | Developers                 | `dnf`           | Cutting-edge packages, Red Hat upstream |
| **Arch Linux** | Advanced users             | `pacman`        | DIY philosophy, highly customizable     |
| **Debian**     | Stability & servers        | `apt`           | The base for Ubuntu and many others     |

> 🎓 **Recommended for this course:** Ubuntu or Kali Linux (or both via virtual machine)

---

### 4. The Linux Command Line & Terminal Basics

The **terminal** (also called the shell, CLI, or command line) is where you interact directly with the operating system through typed commands.

#### Why Learn the CLI?

- Faster and more powerful than GUIs for most tasks
- Required for server administration and security work
- Enables scripting and automation
- Universal — works the same across nearly all Linux systems

#### Essential Commands

```bash
# Navigation
pwd               # Print working directory
ls -la            # List all files with details
cd /path/to/dir   # Change directory
cd ~              # Go to home directory
cd ..             # Go up one directory

# File Operations
touch file.txt    # Create an empty file
mkdir myfolder    # Create a directory
cp src dest       # Copy a file
mv src dest       # Move or rename a file
rm file.txt       # Remove a file
rm -rf folder/    # Remove a folder recursively (use with caution!)

# Viewing & Editing
cat file.txt      # Print file contents
less file.txt     # View file with scrolling
nano file.txt     # Simple terminal text editor
head -n 10 f.txt  # Show first 10 lines
tail -n 10 f.txt  # Show last 10 lines

# System Info
whoami            # Show current user
uname -a          # Show system/kernel info
df -h             # Disk usage
top               # Live process monitor
man command       # Manual/help for any command

# Permissions
chmod +x file     # Make file executable
sudo command      # Run as superuser
```

#### Understanding the Prompt

```
user@hostname:~$
│    │         │└── $ = regular user, # = root
│    │         └─── ~ = current directory (home)
│    └─────────────── hostname (machine name)
└──────────────────── logged-in username
```

#### The Linux Filesystem Hierarchy

```
/                   Root of the filesystem
├── bin/            Essential user binaries (ls, cp, etc.)
├── etc/            System configuration files
├── home/           User home directories
│   └── username/
├── var/            Variable data (logs, caches)
├── tmp/            Temporary files
├── usr/            User programs and utilities
└── root/           Home directory for the root user
```

---

## 🔧 Setup & Prerequisites

Before starting this module, you should have:

- [ ] A working Linux installation, virtual machine (VirtualBox / VMware), or WSL (Windows Subsystem for Linux)
- [ ] Terminal access
- [ ] No prior Linux experience required!

### Quick Setup Options

| Method                      | Difficulty  | Notes                             |
| --------------------------- | ----------- | --------------------------------- |
| **VirtualBox + Ubuntu ISO** | ⭐ Easy     | Free, isolated, recommended       |
| **WSL 2 (Windows)**         | ⭐ Easy     | Native Linux on Windows           |
| **Dual Boot**               | ⭐⭐ Medium | Real hardware, more complex       |
| **Live USB**                | ⭐ Easy     | No installation needed            |
| **Cloud VPS**               | ⭐⭐ Medium | Remote server, great for practice |

---
---

## 📌 Key Takeaways

- Linux is the backbone of modern infrastructure — learning it is essential for any technical career
- Open source means transparency, collaboration, and freedom
- Distributions package Linux for different audiences; Ubuntu and Kali are great starting points
- The command line is your most powerful tool — invest time in learning it well

---

## 🔗 Resources

| Resource                          | Link                                     |
| --------------------------------- | ---------------------------------------- |
| The Linux Command Line (book)     | https://linuxcommand.org/tlcl.php        |
| OverTheWire: Bandit (CLI wargame) | https://overthewire.org/wargames/bandit/ |
| Linux Journey (interactive)       | https://linuxjourney.com                 |
| Ubuntu Documentation              | https://help.ubuntu.com                  |
| explainshell.com                  | https://explainshell.com                 |

---

## 📂 Module Structure

```
linux-fundamentals/
├── README.md             ← You are here
├── slides/
│   └── linux-intro.pdf
├── exercises/
│   ├── 01-navigation.md
│   ├── 02-file-operations.md
│   └── 03-permissions.md
└── notes/
    └── cheatsheet.md
```

---

## ✅ Module Completion Checklist

- [ ] Read all four topic sections
- [ ] Set up a Linux environment
- [ ] Completed all 5 exercises
- [ ] Can explain what Linux is without notes
- [ ] Comfortable navigating the CLI with basic commands

---

_Module 1 of the Linux & Security Foundations curriculum._  
\*Next module: → **Users, Permissions & the Linux Filesystem\***
