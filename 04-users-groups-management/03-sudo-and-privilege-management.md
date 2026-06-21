# sudo and Privilege Management

A reference guide to `sudo` — how privilege delegation works, how to configure it safely with `visudo`, and how to grant fine-grained access without handing out full root.

---

## 🧩 What `sudo` Does

`sudo` ("substitute user, do") lets an authorized user run a command as another user — typically root — without logging in as that user directly. It exists to avoid the alternative: sharing the root password, or having everyone log in as root for routine admin tasks.

```bash
sudo apt update          # run a single command as root
sudo -u alice whoami     # run a command as a specific user (not just root)
sudo -i                  # start an interactive root login shell
sudo -s                  # start a root shell, keeping current environment
```

Every `sudo` invocation is checked against a policy file — `/etc/sudoers` — and (by default) logged, giving an audit trail that shared root credentials never could.

---

## 📜 `/etc/sudoers` — The Policy File

`/etc/sudoers` defines **who** can run **what**, **as whom**, and under **what conditions**.

### Basic Rule Syntax

```
user_or_group   host = (run_as_user:run_as_group)   command_list
```

```bash
alice   ALL=(ALL:ALL) ALL
```

This reads: `alice`, on `ALL` hosts, can run as `ALL` users/groups, the command `ALL` (anything).

### Common Examples

```bash
# alice can run any command as root, anywhere
alice   ALL=(ALL:ALL) ALL

# Members of the "admins" group can run any command as root
%admins ALL=(ALL) ALL

# bob can only restart nginx — nothing else
bob     ALL=(root) /usr/bin/systemctl restart nginx

# deploy user can run specific deployment scripts as the "webapp" user, no password
deploy  ALL=(webapp) NOPASSWD: /opt/scripts/deploy.sh
```

> **Note:** A `%` prefix denotes a **group** rather than a user — `%admins` means "anyone in the `admins` group."

---

## ✏️ Editing Safely with `visudo`

**Never edit `/etc/sudoers` directly with a text editor.** Use `visudo` instead.

```bash
sudo visudo
```

### Why `visudo` Matters

- It **locks** the file, preventing simultaneous edits from corrupting it.
- It **validates syntax** before saving — if there's an error, it warns you and refuses to save, rather than leaving a broken file in place.
- A broken `sudoers` file can mean **no one can use `sudo` at all**, including to fix the file itself.

```bash
sudo visudo
# >>> /etc/sudoers: syntax error near line 28 <<<
# What now? Options are:
#   (e)dit again
#   e(x)it without saving
```

> ⚠️ **Caution:** If `visudo` reports a syntax error, choose **edit again** and fix it — do not force a save with a broken file, and do not exit without saving if you're unsure. Keep a separate root shell or console session open while editing, just in case.

### Editing Drop-In Files Instead

Rather than editing the main file, it's common (and safer) to add scoped rules in `/etc/sudoers.d/`:

```bash
sudo visudo -f /etc/sudoers.d/deploy-user
```

Each file in `/etc/sudoers.d/` is included automatically (as configured by a `#includedir` directive in the main file). This keeps custom rules organized, easy to review individually, and easy to remove without touching the main file.

---

## 🎯 Granting Limited Command Access

The real value of `sudo` is **least privilege**: granting exactly the access a task needs, not blanket root.

### Restricting to Specific Commands

```bash
bob   ALL=(root) /usr/bin/systemctl restart nginx, /usr/bin/systemctl status nginx
```

`bob` can restart or check the status of nginx — nothing else requires elevated access for him.

### Using Command Aliases for Readability

```bash
Cmnd_Alias WEBADMIN = /usr/bin/systemctl restart nginx, /usr/bin/systemctl restart apache2
bob   ALL=(root) WEBADMIN
```

Aliases keep policy files readable as rules grow — define once, reference by name across multiple user lines.

### Restricting Arguments Precisely

```bash
alice ALL=(root) /usr/bin/systemctl restart nginx
```

This allows *only* `systemctl restart nginx` with that exact argument — not `systemctl restart anything-else`, and not `systemctl stop nginx`.

> ⚠️ **Caution:** Wildcards in command rules can be dangerous if not scoped carefully:
> ```bash
> alice ALL=(root) /usr/bin/systemctl *
> ```
> This grants `alice` *any* systemctl subcommand — including disabling security services or starting arbitrary units. Be as specific as the task allows.

### Granting Access to a Script, Not a Shell

Avoid granting `sudo` access to general-purpose interpreters or editors unless truly necessary:

```bash
# Risky — bob could use vim's :! to escape into an arbitrary root shell
bob ALL=(root) /usr/bin/vim /etc/nginx/nginx.conf

# Safer — a deliberately scoped script that does one thing
bob ALL=(root) /opt/scripts/edit-nginx-conf.sh
```

Many common binaries (`vim`, `less`, `more`, `find`, `awk`, even `man` in some configurations) have known **shell-escape** sequences that can be used to spawn an unrestricted root shell from inside an otherwise "limited" command. Granting `sudo` on these without care can quietly hand over full root.

---

## 🔓 Passwordless `sudo` (`NOPASSWD`)

By default, `sudo` re-prompts for the user's own password (not root's) before running a command, then caches that authentication for a short window (commonly 15 minutes).

```bash
deploy ALL=(webapp) NOPASSWD: /opt/scripts/deploy.sh
```

`NOPASSWD` skips that prompt entirely for the listed command(s).

### When `NOPASSWD` Makes Sense

- **Automated scripts/CI pipelines** that need to run a specific privileged command without a human present to type a password.
- **Tightly scoped commands** where the action itself is low-risk even if triggered unexpectedly (e.g. restarting a specific non-critical service).

### When to Avoid It

- For **broad access** (`ALL=(ALL) NOPASSWD: ALL`) — this removes the last speed bump before a mistake or a compromised session causes serious damage.
- For **interactive human admin accounts** doing general system administration — the password re-prompt is a deliberate, valuable friction point.

> ⚠️ **Caution:** `NOPASSWD: ALL` on a regular user account is close to equivalent to giving that account the root password outright — anyone who can act as that user (including via a stolen SSH session or a compromised script) gets unrestricted root with zero additional verification.

---

## 👑 Root vs. `sudo` — Policy Considerations

### Why Avoid Direct Root Login

| Direct root login | `sudo`-based access |
|---|---|
| One shared credential | Individual accountability per user |
| No record of *who* did *what* | Logged per-user, per-command (see below) |
| All-or-nothing access | Granular, per-command delegation possible |
| Compromise of root = total compromise | Compromise of one sudo-enabled account ≠ necessarily full root |

Most security-conscious distributions **disable direct root login** entirely (especially over SSH) and require administrators to authenticate as themselves first, then escalate via `sudo`.

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
```

### Auditing `sudo` Usage

Every `sudo` command is logged, typically to the system log or a dedicated log file:

```bash
sudo cat /var/log/auth.log | grep sudo      # Debian/Ubuntu
sudo cat /var/log/secure | grep sudo        # RHEL/CentOS/Fedora
journalctl _COMM=sudo                       # systemd-based logging
```

This is one of the strongest practical arguments for `sudo` over shared root: every escalation is attributable to a specific account.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Run one command as root | `sudo command` |
| Run a command as a specific user | `sudo -u username command` |
| Start an interactive root shell | `sudo -i` |
| Edit sudoers policy safely | `sudo visudo` |
| Edit a scoped drop-in policy file | `sudo visudo -f /etc/sudoers.d/filename` |
| Check what a user is allowed to run | `sudo -l` (as that user) or `sudo -U username -l` |
| View sudo usage log (Debian/Ubuntu) | `sudo cat /var/log/auth.log \| grep sudo` |
| View sudo usage log (RHEL/Fedora) | `sudo cat /var/log/secure \| grep sudo` |

---

## 💡 Best Practices

- Always use `visudo` (or `visudo -f` for drop-in files) — never edit `/etc/sudoers` with a plain text editor.
- Grant the narrowest command set that accomplishes the task — prefer specific binaries with fixed arguments over wildcards or full shells.
- Be wary of granting `sudo` access to general-purpose tools (editors, pagers, interpreters) that have known shell-escape sequences — wrap the actual task in a dedicated script instead.
- Reserve `NOPASSWD` for automation and tightly scoped, low-risk commands — keep the password prompt for general interactive administrative access.
- Disable direct root login (`PermitRootLogin no` in SSH config) and require escalation through individually-attributable `sudo` accounts instead.
- Organize custom rules in `/etc/sudoers.d/` rather than appending to the main file — it's easier to review, audit, and roll back individual policies.
- Periodically review `sudo` logs and the contents of `/etc/sudoers` / `/etc/sudoers.d/` to confirm granted access still matches actual need — privilege tends to accumulate over time if not audited.