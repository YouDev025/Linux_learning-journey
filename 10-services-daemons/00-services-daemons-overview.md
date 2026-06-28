# Services and Daemons Overview

A reference guide to what services and daemons actually are, how they're started and managed, and why reliable service management is foundational to Linux system administration.

---

## 🧱 What a Daemon Is

A **daemon** is a process designed to run continuously in the background, with no controlling terminal, typically started automatically at boot and living for as long as the system is up — providing some ongoing capability (web serving, logging, scheduling, networking) rather than performing one task and exiting.

### The Naming Convention

By long-standing Unix convention, daemon process names often end in `d`:

```
sshd      — SSH daemon (handles incoming SSH connections)
crond      — cron daemon (runs scheduled tasks)
httpd / nginx — web server daemons (nginx breaks the naming convention, but functions identically)
systemd     — the init/service-management daemon itself (see below)
named        — DNS server daemon (BIND)
NetworkManager — network configuration daemon (doesn't follow the "d" convention, but is one)
```

> **Note:** The naming convention is just convention, not a hard rule enforced by the kernel — plenty of legitimate daemons (`nginx`, `NetworkManager`, `dockerd`'s parent concepts) don't strictly follow the trailing-`d` pattern, and not every program ending in `d` is necessarily a daemon either.

### Key Characteristics of a Daemon

| Characteristic | Why it matters |
|---|---|
| No controlling terminal | Detached from any interactive session — closing your terminal doesn't stop it |
| Runs as a background process | Doesn't block a shell or require someone watching it |
| Typically starts at boot | Provides its service continuously, without manual intervention each time |
| Often runs as a dedicated service account | Limits its privileges to only what the service actually needs (see the *User Account Basics* guide — accounts like `www-data` or `sshd` exist for exactly this) |
| Usually has a PID file or is tracked by the init system | Lets the system (and admins) know whether it's running, and manage it cleanly |

---

## 🔄 The Service Lifecycle

Every service moves through a predictable set of states, regardless of which specific init system manages it.

```
        ┌──────────┐
        │ inactive │  ← not running, not scheduled to start
        └────┬─────┘
             │ start
             ▼
        ┌──────────┐
        │ starting │  ← initializing (reading config, binding ports, etc.)
        └────┬─────┘
             │
             ▼
        ┌──────────┐
        │  active  │  ← running normally, providing its service
        └────┬─────┘
             │ stop / crash / restart
             ▼
        ┌──────────┐
        │ stopping │  ← shutting down cleanly (or being killed, if it won't)
        └────┬─────┘
             │
             ▼
        ┌──────────┐
        │  failed  │  ← exited unexpectedly / couldn't start
        └──────────┘
```

### The Stages in Practice

| Stage | What typically happens |
|---|---|
| **Enable/disable** | Whether the service *should* start automatically at boot — independent of whether it's currently running right now |
| **Start** | The service's main process is launched; it reads configuration, binds to ports/sockets, opens files |
| **Running/active** | Normal operation — handling requests, processing scheduled work, etc. |
| **Reload** | Re-reading configuration **without** a full stop/start — connections/state are typically preserved (see the `SIGHUP` convention in the *Signals and Scheduling* guide) |
| **Restart** | A full stop followed by a start — connections/state are lost, briefly unavailable |
| **Stop** | The service shuts down, ideally cleanly (closing connections, flushing buffers) — see graceful shutdown via `SIGTERM` in the *Signals and Scheduling* guide |
| **Failed** | The service crashed, or failed to start (bad config, port already in use, missing dependency) |

### Enabled vs. Active: A Critical Distinction

These two properties are independent, and conflating them is one of the most common points of confusion in service management:

| | Enabled | Disabled |
|---|---|---|
| **Active (running now)** | Normal expected state for most services | Manually started, but won't survive a reboot |
| **Inactive (not running)** | Will start on next boot, but isn't running right now | Won't run now, and won't start on next reboot either |

> **Practical implication:** a service can be perfectly "active" right now, yet **disabled** — meaning a reboot will leave it not running, surprising anyone who assumes "it's running" means "it'll still be running after I restart the machine." Always check both properties, not just current status, when verifying a service is properly configured.

---

## 🛠️ Modern Service Management: `systemd`

Most current Linux distributions use **systemd** as their init system and service manager — the first process started by the kernel (PID 1), responsible for bringing up the rest of the system and supervising services throughout its lifetime.

### Basic Commands

```bash
sudo systemctl start nginx          # start now
sudo systemctl stop nginx             # stop now
sudo systemctl restart nginx           # stop, then start
sudo systemctl reload nginx              # re-read config without a full restart, if the service supports it
sudo systemctl enable nginx               # start automatically at future boots
sudo systemctl disable nginx                # don't start automatically at future boots
sudo systemctl enable --now nginx             # enable AND start in one step — a common combo
```

### Checking Status

```bash
systemctl status nginx
```

```
● nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-06-20 09:15:23 UTC; 2h ago
   Main PID: 1234 (nginx)
      Tasks: 3
     Memory: 8.2M
```

| Field | Meaning |
|---|---|
| `Loaded` | Whether systemd found the unit file, and whether it's `enabled`/`disabled` |
| `Active` | Current runtime state — `active (running)`, `inactive (dead)`, `failed`, etc. |
| `Main PID` | The process ID of the service's primary process |

```bash
systemctl is-active nginx       # just print active/inactive — useful in scripts
systemctl is-enabled nginx       # just print enabled/disabled — useful in scripts
systemctl list-units --type=service          # list all currently loaded services
systemctl list-units --type=service --state=failed   # show just the failed ones
```

### Viewing Logs for a Service

```bash
journalctl -u nginx                  # all logs for this specific service
journalctl -u nginx -f                  # follow LIVE, like `tail -f`
journalctl -u nginx --since "1 hour ago"   # filter by time
journalctl -u nginx -n 50                    # just the last 50 lines
```

> **Note:** This guide introduces `systemctl`/`journalctl` at a conceptual level — a dedicated guide on `systemd` unit files, dependencies, and timers would go significantly deeper into writing and customizing services yourself.

---

## 📋 Common Daemon Examples

| Daemon | Purpose |
|---|---|
| `sshd` | Accepts and authenticates incoming SSH connections |
| `cron` / `crond` | Executes scheduled jobs at specified times (see crontab) |
| `systemd` | PID 1 — manages the entire service lifecycle for everything else |
| `nginx` / `apache2` (`httpd`) | Serve web content, handle HTTP/HTTPS requests |
| `mysqld` / `postgres` | Database server processes, handling client query connections |
| `dockerd` | Manages container lifecycle for Docker |
| `NetworkManager` | Manages network interface configuration dynamically |
| `rsyslogd` / `journald` | Collect and route system log messages |
| `dhclient` / `dhcpd` | DHCP client/server processes (see the *IP Addressing and Routing* guide) |
| `ntpd` / `chronyd` | Keep the system clock synchronized over the network |
| `firewalld` | Manages firewall rules dynamically (see the *Firewalls and iptables* guide) |

### A Quick Way to See What's Actually Running

```bash
ps aux | grep -i daemon            # rough heuristic — catches some, but not all, by name pattern
systemctl list-units --type=service --state=running    # the reliable, systemd-aware way
```

---

## 🎭 Background vs. Foreground Execution

### The Distinction, Conceptually

This connects directly to job control concepts (see the *Job Control* guide), but matters specifically for services: a **foreground** process holds onto a terminal and blocks further input until it finishes; a **background** process (or daemon) doesn't need a terminal at all and keeps running independent of whether anyone's logged in.

```bash
# Foreground: blocks the terminal until you Ctrl+C or it exits
nginx -g "daemon off;"

# Background, but still tied to THIS terminal session unless detached properly
nginx &

# True daemon: detached from any terminal, managed by the init system
sudo systemctl start nginx
```

### Why Proper Daemonization Matters

A process simply run with `&` (see *Job Control*) is **not** the same as a properly daemonized service — it's still loosely tied to the shell that launched it (depending on shell settings, closing that shell may send `SIGHUP` and kill it, as covered in the *Job Control* guide's `nohup` section), it isn't automatically restarted if it crashes, and it isn't automatically started again on the next boot.

| | `command &` | `nohup command &` | `systemctl start` (proper service) |
|---|---|---|---|
| Survives terminal close | Sometimes (shell-dependent) | Yes | Yes |
| Survives system reboot | No | No (unless separately re-run) | Yes, if enabled |
| Automatically restarted on crash | No | No | Yes, if configured (`Restart=` in the unit file) |
| Centrally logged | No (unless manually redirected) | Partial (to a log file) | Yes, via `journald` |
| Managed uniformly with other services | No | No | Yes |

> **Tip:** `nohup` and `&` are fine for a one-off, ad hoc long-running task you're personally watching (see the *Job Control* guide) — they are **not** a substitute for a real service definition when something needs to reliably run unattended, survive reboots, and restart automatically after a crash.

### Why This Matters for Operations

Production reliability depends on services being managed by something that:
- **Restarts them automatically** if they crash, without requiring a human to notice and intervene.
- **Starts them in the correct order**, respecting dependencies (e.g. a web server shouldn't start before the network is up).
- **Logs consistently** so failures are diagnosable after the fact, not just visible if someone happened to be watching a terminal at the time.
- **Survives reboots** predictably, so planned maintenance (or an unplanned crash) doesn't silently leave critical services not running.

This is precisely the gap that an init system like `systemd` (or older alternatives like SysV init, Upstart) is designed to close — turning "a long-running process I started" into "a managed, supervised service" with all of the above guarantees built in.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Start a service now | `sudo systemctl start name` |
| Stop a service now | `sudo systemctl stop name` |
| Restart (full stop+start) | `sudo systemctl restart name` |
| Reload config without restart | `sudo systemctl reload name` |
| Enable at boot | `sudo systemctl enable name` |
| Enable and start in one step | `sudo systemctl enable --now name` |
| Disable at boot | `sudo systemctl disable name` |
| Check current status | `systemctl status name` |
| Check active/inactive only | `systemctl is-active name` |
| Check enabled/disabled only | `systemctl is-enabled name` |
| List all running services | `systemctl list-units --type=service` |
| List failed services | `systemctl list-units --type=service --state=failed` |
| View a service's logs | `journalctl -u name` |
| Follow a service's logs live | `journalctl -u name -f` |

---

## 💡 Best Practices

- Always check **both** enabled and active status, not just one — a service can be running now but disabled (won't survive reboot), or enabled but currently inactive/failed.
- Use `systemctl enable --now` as the standard combo when you want a service running immediately **and** persisting across reboots, rather than running the two steps separately and risking forgetting one.
- Reach for proper service definitions (`systemd` units) rather than `nohup`/`&` for anything that genuinely needs to run unattended, restart after crashes, and survive reboots — ad hoc background processes don't provide those guarantees.
- Use `journalctl -u name` as your first troubleshooting step for a failed or misbehaving service — centralized logging is one of the main practical advantages of proper service management over ad hoc background processes.
- Prefer `reload` over `restart` when a service supports it and you're only changing configuration — it avoids the brief downtime/dropped-connections window a full restart causes.
- Periodically check `systemctl list-units --type=service --state=failed` on a system, especially after changes — a failed service can go unnoticed for a long time if nothing's actively monitoring for it.