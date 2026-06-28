# Service Management

A hands-on reference for the day-to-day `systemctl` operations every Linux administrator uses constantly — starting, stopping, restarting services, controlling boot-time behavior, and diagnosing failures.

---

## ▶️ `systemctl start` / `stop` / `restart`

### Starting a Service

```bash
sudo systemctl start nginx
```

Starts the service **right now**. If it's already running, this is effectively a no-op (systemd won't start a second instance).

### Stopping a Service

```bash
sudo systemctl stop nginx
```

Stops the service right now. systemd sends `SIGTERM` to the main process by default, waits a configured timeout, then escalates to `SIGKILL` if it hasn't exited (see the *Signals and Scheduling* guide for what these actually do).

### Restarting a Service

```bash
sudo systemctl restart nginx
```

A full **stop, then start** — the service is briefly unavailable, and any in-memory state or active connections are lost. Use this for changes that genuinely require a fresh process (binary updates, certain config changes the service can't hot-reload).

### Reloading Instead of Restarting

```bash
sudo systemctl reload nginx
```

Asks the service to re-read its configuration **without** a full stop/start — typically implemented as sending `SIGHUP` (see `ExecReload=` in the *systemd Service Files* guide) or an equivalent in-process mechanism. Active connections are generally preserved, and downtime is effectively zero.

```bash
sudo systemctl reload-or-restart nginx
```

A convenient fallback: reload if the service supports it, otherwise fall back to a full restart automatically — useful when you're not certain a given service's unit file defines `ExecReload=`.

### Why the Distinction Matters in Practice

| | `restart` | `reload` |
|---|---|---|
| Downtime | Brief gap while stopping/starting | Effectively none |
| Active connections | Dropped | Generally preserved |
| Picks up binary/major changes | Yes | No — same process keeps running |
| Picks up config changes | Yes | Yes, IF the service supports reload |
| Works on every service | Yes | Only if the unit defines `ExecReload=` |

> **Tip:** Default to `reload` for routine configuration changes on services that support it (web servers, many daemons), and reserve `restart` for situations that genuinely need a fresh process — it meaningfully reduces user-facing disruption on production systems.

---

## 🔌 `systemctl enable` / `disable`

### The Core Distinction: Now vs. At Boot

This is the single most important concept in this guide, and the most commonly confused: **starting/stopping** controls whether a service is running **right now**. **Enabling/disabling** controls whether it will start **automatically on the next boot**. These are completely independent of each other.

```bash
sudo systemctl enable nginx        # WILL start at next boot — says nothing about right now
sudo systemctl disable nginx        # will NOT start at next boot — says nothing about right now
```

### The Four Possible Combinations

| State | Running now? | Will start at next boot? |
|---|---|---|
| Started + Enabled | ✅ Yes | ✅ Yes |
| Started + Disabled | ✅ Yes | ❌ No — stops being "running" after a reboot |
| Stopped + Enabled | ❌ No | ✅ Yes — will come up on next boot regardless |
| Stopped + Disabled | ❌ No | ❌ No |

> **The classic trap:** running `systemctl start nginx` and confirming it's working, then assuming it's "set up correctly" — without realizing it's still **disabled**, and a routine reboot weeks later silently leaves it not running, with no immediate error to alert anyone. Always pair `start` with `enable` (or use the combined form below) for anything meant to be permanent.

### Enabling and Starting in One Step

```bash
sudo systemctl enable --now nginx
```

This is the standard, recommended pattern for "I want this running now, and I want it to stay that way after every future reboot" — covering both halves of the distinction in a single command.

```bash
sudo systemctl disable --now nginx       # the inverse: stop it now, AND prevent it from starting at future boots
```

### Checking Both States

```bash
systemctl is-active nginx        # "active" or "inactive" — running RIGHT NOW?
systemctl is-enabled nginx        # "enabled" or "disabled" — will it start at boot?
```

```bash
systemctl status nginx
```

```
● nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-06-20 09:15:23 UTC; 2h ago
```

Both pieces of information appear in plain `status` output too — `enabled`/`disabled` on the `Loaded` line, `active (running)`/`inactive (dead)` on the `Active` line. Reading both lines, every time, avoids the trap above.

### What `enable` Actually Does

```bash
sudo systemctl enable nginx
# Created symlink /etc/systemd/system/multi-user.target.wants/nginx.service → /usr/lib/systemd/system/nginx.service
```

`enable` creates a **symlink** connecting the unit to whichever target its `[Install]` section specifies (see the *systemd Service Files* guide) — `disable` simply removes that symlink. This is why enabling/disabling doesn't require `daemon-reload` the way editing a unit file's actual content does — it's a separate, lighter-weight operation.

### Masking: A Stronger Form of Disable

```bash
sudo systemctl mask nginx
```

`disable` prevents *automatic* starting at boot, but someone can still `systemctl start` it manually afterward. `mask` goes further — it makes the unit completely unstartable (by anyone, including manual `start` attempts) by symlinking it to `/dev/null`, until explicitly unmasked.

```bash
sudo systemctl unmask nginx       # reverse a mask
```

> **When to use masking:** when you need to guarantee a service genuinely cannot run at all — e.g. a service that conflicts with another you're deliberately using instead, where you want to prevent anyone (including another automated process, or your future self) from accidentally starting it again.

---

## 🚨 Diagnosing Failed Services

### Step 1: Check Status First

```bash
systemctl status nginx
```

```
● nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Sat 2026-06-20 09:20:11 UTC; 30s ago
   Process: 5678 ExecStart=/usr/sbin/nginx -g daemon on; (code=exited, status=1/FAILURE)
   Main PID: 5678 (code=exited, status=1/FAILURE)
```

This single command often tells you most of what you need: the failure result type, the exit code, and which specific `Exec*` step failed.

### Step 2: Read the Actual Logs

```bash
journalctl -u nginx -e             # jump to the most recent entries (see the Logs and journald guide)
journalctl -u nginx -n 50            # just the last 50 lines
journalctl -u nginx -b                 # logs from the current boot only
```

> **Tip:** `systemctl status` typically shows only the last few log lines inline — `journalctl -u name` is where the actual detailed error output usually lives. Don't stop at `status` alone if the failure reason isn't immediately obvious.

### Step 3: Common Failure Categories and What to Check

| Symptom | Likely cause | Where to check |
|---|---|---|
| Exits immediately, status=1 | Configuration error, missing file, bad syntax | `journalctl -u name`, and the application's own config validation (e.g. `nginx -t`) |
| `Active: failed (Result: timeout)` | Service didn't signal "ready" within the expected time | Whether `Type=notify` is set correctly, or if startup is genuinely just slow |
| Port already in use | Another process is already bound to the same port | `sudo ss -tulnp \| grep PORT` (see the *Linux Network Tools* guide) |
| Permission denied | Running as the wrong user, or file/directory permissions are wrong | `User=`/`Group=` in the unit file, and `ls -l` on the relevant paths (see the *Permissions* guide) |
| `Result: signal` | The process was killed by a signal — often `SIGKILL` after an unresponsive shutdown, or an external `kill` | `journalctl` around the failure time; check for OOM kills specifically (see below) |
| Starts, then immediately restart-loops | `Restart=` policy retrying a genuinely broken startup repeatedly | `systemctl status` will show `Restart` count climbing; fix the underlying error rather than the loop itself |

### Checking for Out-of-Memory Kills

A service abruptly dying with no obvious application-level error is sometimes the kernel's OOM killer terminating it under memory pressure, rather than anything wrong with the service's own logic.

```bash
journalctl -k | grep -i "out of memory"
journalctl -k | grep -i "oom"
dmesg | grep -i oom              # equivalent, if not using journald for kernel logs
```

### Validating Configuration Directly (Application-Specific)

Many services provide their own config validation, independent of systemd — checking this BEFORE attempting a restart avoids restart-loop cycles on a config you already know is broken:

```bash
sudo nginx -t                    # nginx-specific: test config syntax without actually reloading/restarting
sudo apachectl configtest          # Apache equivalent
sudo sshd -t                         # SSH daemon equivalent
```

### Checking Resource Limits

```bash
systemctl show nginx -p LimitNOFILE      # check a specific resource limit applied to the service
systemctl show nginx -p MemoryMax          # check configured memory limit, if any
```

A service hitting a configured resource limit (too many open files, memory cap) can fail in ways that look like an application bug but are actually a systemd-enforced constraint — worth ruling out for resource-sensitive failures.

### Validating Unit File Syntax Itself

```bash
systemd-analyze verify /etc/systemd/system/nginx.service
```

Useful when you've recently edited the unit file itself (see the *systemd Service Files* guide) and want to rule out a structural problem in the unit file BEFORE assuming the issue is in the application it's launching.

---

## 🧭 A Complete Diagnostic Workflow

```bash
# 1. What's the current state?
systemctl status myservice

# 2. What do the detailed logs say?
journalctl -u myservice -e

# 3. Is something else already using a port/resource this needs?
sudo ss -tulnp | grep PORT

# 4. Is the unit file itself valid?
systemd-analyze verify /etc/systemd/system/myservice.service

# 5. Does the application's OWN config validation pass? (if it has one)
myapp --check-config        # varies by application

# 6. After fixing the underlying issue, reload unit definitions if you edited the unit file
sudo systemctl daemon-reload

# 7. Try starting again, and confirm BOTH active and enabled state
sudo systemctl start myservice
systemctl is-active myservice
systemctl is-enabled myservice
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Start now | `sudo systemctl start name` |
| Stop now | `sudo systemctl stop name` |
| Full restart | `sudo systemctl restart name` |
| Reload config (no downtime, if supported) | `sudo systemctl reload name` |
| Reload, fallback to restart | `sudo systemctl reload-or-restart name` |
| Enable at boot (only) | `sudo systemctl enable name` |
| Disable at boot (only) | `sudo systemctl disable name` |
| Enable AND start together | `sudo systemctl enable --now name` |
| Disable AND stop together | `sudo systemctl disable --now name` |
| Prevent ANY start, even manual | `sudo systemctl mask name` |
| Reverse a mask | `sudo systemctl unmask name` |
| Check if running now | `systemctl is-active name` |
| Check if set to start at boot | `systemctl is-enabled name` |
| Full status (both, plus recent logs) | `systemctl status name` |
| Detailed logs for diagnosis | `journalctl -u name -e` |
| Validate unit file syntax | `systemd-analyze verify file.service` |

---

## 💡 Best Practices

- Always pair `start` with `enable` (or use `enable --now`) for anything meant to run permanently — a service that's running but disabled will silently stop surviving the next reboot.
- Read both the `Loaded` (enabled/disabled) and `Active` (running/stopped) lines in `systemctl status` — checking only one half of the picture is the most common service-management mistake.
- Prefer `reload` over `restart` for routine config changes on services that support it — it avoids unnecessary downtime and dropped connections.
- Use `journalctl -u name -e` as your default next step after `systemctl status` shows a failure — the detailed error almost always lives in the logs, not the brief status summary.
- Run an application's own config-test command (`nginx -t`, etc.) before restarting after a config change — it catches syntax errors without triggering a restart-loop on a config you already know is broken.
- Reach for `mask` instead of `disable` when you need to guarantee a service truly cannot be started by anyone, including manual intervention — `disable` alone doesn't prevent manual starts.
- Rule out resource limits (`systemctl show -p LimitNOFILE`, `MemoryMax`) and OOM kills (`journalctl -k | grep -i oom`) before assuming a mysterious crash is purely an application-level bug.