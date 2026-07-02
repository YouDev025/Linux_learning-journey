# 🔐 Security Cheat Sheet

> A quick-reference guide to essential Linux security commands — account auditing, authentication, file integrity, logging, and hardening — with syntax, explanations, and real examples.

---

## Table of Contents

- [Account Audit](#-account-audit)
- [Authentication](#-authentication)
- [File Integrity](#-file-integrity)
- [Logs](#-logs)
- [Hardening](#-hardening)
- [Quick Reference Table](#-quick-reference-table)

---

## 👤 Account Audit

Commands for reviewing user accounts, login activity, and password policies.

### `lastlog`
Show the most recent login of each user (or all users).
```bash
lastlog                  # show last login for all users
lastlog -u alice         # show last login for a specific user
lastlog -t 30            # show logins within the last 30 days
```

### `passwd`
View or change password status and policy for a user account.
```bash
passwd -S alice          # show password status (locked, expired, etc.)
sudo passwd -l alice     # lock a user account
sudo passwd -u alice     # unlock a user account
```

### `chage`
View or set password aging/expiration policy for a user.
```bash
chage -l alice                     # list password aging info
sudo chage -M 90 alice              # force password change every 90 days
sudo chage -E 2026-12-31 alice      # set an account expiration date
```

---

## 🔑 Authentication

Commands and config files for managing SSH access and pluggable authentication.

### `sshd_config`
Main configuration file controlling SSH daemon behavior (not a command, but critical to review).
```bash
sudo nano /etc/ssh/sshd_config
# Common hardening lines:
#   PermitRootLogin no
#   PasswordAuthentication no
#   Port 2222
sudo systemctl restart sshd        # apply changes
```

### `ssh-keygen`
Generate, manage, and convert SSH authentication keys.
```bash
ssh-keygen -t ed25519 -C "user@host"     # generate a modern keypair
ssh-copy-id user@remote-host             # copy public key to a remote server
ssh-keygen -lf ~/.ssh/id_ed25519.pub     # show key fingerprint
```

### `pam`
Pluggable Authentication Modules — the framework behind login, sudo, and password policy enforcement (configured under `/etc/pam.d/`).
```bash
cat /etc/pam.d/common-password    # view password policy rules (Debian/Ubuntu)
cat /etc/pam.d/sshd               # view PAM rules applied to SSH logins
```

---

## 🧩 File Integrity

Tools for detecting unauthorized changes to files and system binaries.

### `aide`
Advanced Intrusion Detection Environment — creates a baseline database and checks for file changes.
```bash
sudo aideinit                     # initialize the baseline database
sudo aide --check                 # check current state against baseline
sudo aide --update                # update the database after legitimate changes
```

### `tripwire`
Similar to AIDE; monitors file system integrity and alerts on unexpected changes.
```bash
sudo tripwire --init              # initialize the integrity database
sudo tripwire --check             # run an integrity check
```

---

## 📜 Logs

Commands for reviewing system logs and audit trails.

### `journalctl`
Query and display logs from systemd's journal.
```bash
journalctl -xe                    # show recent logs with explanations
journalctl -u sshd                # show logs for the sshd service
journalctl --since "1 hour ago"   # show logs from the last hour
```

### `ausearch`
Search the Linux audit logs for specific events.
```bash
sudo ausearch -m avc -ts today            # search for SELinux denials today
sudo ausearch -ui 1000                    # search events for a specific user ID
```

### `auditctl`
Configure and control the Linux Audit daemon's rules in real time.
```bash
sudo auditctl -l                          # list current audit rules
sudo auditctl -w /etc/passwd -p wa -k passwd_watch  # watch a file for write/attribute changes
```

---

## 🛡️ Hardening

Commands for checking the status of mandatory access control and firewall systems.

### `selinuxenabled`
Check whether SELinux is currently enabled (exit code 0 = enabled).
```bash
selinuxenabled && echo "SELinux is enabled" || echo "SELinux is disabled"
getenforce                        # show current mode (Enforcing/Permissive/Disabled)
```

### `apparmor_status`
Show the status of AppArmor profiles (enforced, complain, or unloaded).
```bash
sudo apparmor_status
```

### `ufw status`
Show whether the Uncomplicated Firewall is active and list current rules.
```bash
sudo ufw status verbose
```

---

## 📋 Quick Reference Table

| Category        | Tools                                      | Typical Use                          |
|------------------|----------------------------------------------|----------------------------------------|
| Account Audit    | `lastlog`, `passwd`, `chage`                 | Review logins and password policies |
| Authentication   | `sshd_config`, `ssh-keygen`, `pam`           | Secure remote access and login flow |
| File Integrity   | `aide`, `tripwire`                           | Detect unauthorized file changes |
| Logs             | `journalctl`, `ausearch`, `auditctl`         | Investigate events and audit trails |
| Hardening        | `selinuxenabled`, `apparmor_status`, `ufw status` | Verify access control and firewall state |

---

*💡 Tip: Always test authentication changes (like `sshd_config` edits) in a second terminal session before closing your current one — a mistake can lock you out of remote access.*