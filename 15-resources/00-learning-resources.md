# 📚 Learning Resources

> Curated resources for further study and continued Linux skills development — official documentation, distribution guides, man pages, and trusted security/sysadmin blogs.

---

## Table of Contents

- [Official Linux Documentation](#-official-linux-documentation)
- [Distribution-Specific Guides](#-distribution-specific-guides)
- [Man Pages and Reference Tools](#-man-pages-and-reference-tools)
- [Security and System Administration Blogs](#-security-and-system-administration-blogs)
- [Quick Reference Table](#-quick-reference-table)

---

## 🐧 Official Linux Documentation

Primary, authoritative sources maintained by the Linux kernel and open-source communities.

| Resource | Description | Link |
|---|---|---|
| The Linux Kernel Documentation | Official, actively maintained documentation tree for the kernel itself — admin guides, user-space APIs, and developer manuals. | [docs.kernel.org](https://docs.kernel.org/) |
| The Linux Kernel Archives | Home of kernel source releases, mailing lists, and links to the wider documentation ecosystem. | [kernel.org](https://www.kernel.org/) |
| Linux Kernel Newbies | Community-curated index of guides for people learning to read or contribute to the kernel source. | [kernelnewbies.org](https://kernelnewbies.org/) |

---

## 🖥️ Distribution-Specific Guides

Each major distribution maintains its own documentation and community wiki — invaluable for install steps, package management quirks, and troubleshooting.

| Distribution | Resource | Link |
|---|---|---|
| Ubuntu | Official Ubuntu Documentation (Desktop & Server guides) | [help.ubuntu.com](https://help.ubuntu.com/) |
| Arch Linux | ArchWiki — widely regarded as one of the best Linux wikis, useful even for non-Arch users | [wiki.archlinux.org](https://wiki.archlinux.org/title/Main_page) |
| Red Hat / RHEL | Red Hat Documentation index, covering RHEL, Ansible, OpenShift, and more | [docs.redhat.com](https://docs.redhat.com/en) |
| Debian | Debian Documentation Project, including the Debian Reference and Administrator's Handbook | [debian.org/doc](https://www.debian.org/doc/) |

---

## 📖 Man Pages and Reference Tools

Quick, offline-first references every Linux user should know how to use.

| Tool | Description | Example |
|---|---|---|
| `man` | Read the manual page for any installed command | `man ls` |
| `man -k` | Search man page descriptions by keyword | `man -k partition` |
| `--help` | Most commands support a quick built-in help flag | `ls --help` |
| man7.org | Browsable, well-formatted online mirror of Linux man pages | [man7.org/linux/man-pages](https://man7.org/linux/man-pages/) |
| tldr pages | Community-maintained, simplified man pages with practical examples | [tldr.sh](https://tldr.sh/) |

---

## 🛡️ Security and System Administration Blogs

Sources that track vulnerabilities, hardening practices, and sysadmin news.

| Resource | Description | Link |
|---|---|---|
| LWN.net | Long-running, technically deep coverage of kernel development, security, and the wider Linux ecosystem — recommended once you have some baseline familiarity. | [lwn.net](https://lwn.net/) |
| LinuxSecurity.com | Community-focused source for Linux and open-source security news, advisories, and hardening guides. | [linuxsecurity.com](https://linuxsecurity.com/) |
| TecMint | Practical tutorials spanning Linux, sysadmin, security, and DevOps topics for a broad range of skill levels. | [tecmint.com](https://www.tecmint.com/) |

---

## 📋 Quick Reference Table

| Category | Best Starting Point |
|---|---|
| Kernel internals | [docs.kernel.org](https://docs.kernel.org/) |
| General distro help | [help.ubuntu.com](https://help.ubuntu.com/) or [wiki.archlinux.org](https://wiki.archlinux.org/title/Main_page) |
| Enterprise/RHEL-family | [docs.redhat.com](https://docs.redhat.com/en) |
| Command syntax lookup | `man <command>` or [man7.org](https://man7.org/linux/man-pages/) |
| Security news & hardening | [linuxsecurity.com](https://linuxsecurity.com/) |
| Sysadmin tutorials | [tecmint.com](https://www.tecmint.com/) |

---

## 📝 Notes

Documentation sites and blog rosters change over time — bookmark the distro-specific wiki for whatever system you run day-to-day, since it will usually be the fastest path to an accurate, version-matched answer.

*💡 Tip: When in doubt, start with `man` or `--help` before searching the web — the local documentation matches the exact version of the tool installed on your system.*