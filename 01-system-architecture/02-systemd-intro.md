# systemd Introduction

> A practical reference for systemd — the predominant init system on modern Linux. Covers architecture, unit files, service management, dependency ordering, targets, logging, and troubleshooting.

---

## Table of Contents

1. [What Is systemd?](#1-what-is-systemd)
2. [Core Concepts](#2-core-concepts)
3. [Unit Files](#3-unit-files)
4. [Service Units](#4-service-units)
5. [Targets](#5-targets)
6. [Dependency Ordering](#6-dependency-ordering)
7. [Service States & the State Machine](#7-service-states)
8. [Fundamental systemctl Commands](#8-systemctl-commands)
9. [The Journal (journald)](#9-the-journal)
10. [Timers (Replacing cron)](#10-timers)
11. [Socket Activation](#11-socket-activation)
12. [User Sessions](#12-user-sessions)
13. [Resource Control with cgroups](#13-resource-control)
14. [Troubleshooting](#14-troubleshooting)
15. [Reference Cheat Sheet](#15-reference)

---

## 1. What Is systemd?

systemd is a suite of software that provides the **init system** and **service manager** for Linux. It is the first userspace process (PID 1) executed by the kernel after boot and remains running for the entire lifetime of the system.

### 1.1 History & Adoption

| Year | Event |
|---|---|
| 2010 | systemd created by Lennart Poettering & Kay Sievers (Red Hat) |
| 2011 | Fedora 15 — first major distro to ship systemd by default |
| 2012 | openSUSE, Arch Linux adopt systemd |
| 2014 | RHEL 7, Debian 8, Ubuntu 15.04 switch from Upstart/SysV |
| 2015+ | Universal on all mainstream distributions |

### 1.2 What systemd Replaces

| Component | Legacy | systemd |
|---|---|---|
| Init system | SysV init / Upstart | `systemd` (PID 1) |
| Service scripts | `/etc/init.d/*.sh` | `.service` unit files |
| Runlevels | `runlevel`, `telinit` | targets |
| Scheduled tasks | `crond` | `.timer` units |
| System logging | `syslogd` / `rsyslogd` | `journald` |
| Device events | `udevd` (separate) | `systemd-udevd` |
| Login sessions | `utmp`, `ConsoleKit` | `systemd-logind` |
| Network (optional) | `ifupdown`, `NetworkManager` | `systemd-networkd` |
| DNS (optional) | `/etc/resolv.conf` only | `systemd-resolved` |

### 1.3 Design Philosophy

- **Parallelism by default** — all services without hard dependencies start simultaneously.
- **Declarative over procedural** — unit files describe *what* a service needs, not *how* to start it.
- **Event-driven activation** — services start on-demand (socket, D-Bus, path, timer).
- **Unified tooling** — one interface (`systemctl`, `journalctl`) instead of dozens of scripts.
- **Cgroup integration** — every service is tracked and isolated at the kernel level.

---

## 2. Core Concepts

### 2.1 Units

A **unit** is the fundamental object systemd manages. Everything — services, mount points, devices, timers — is represented as a unit with a declarative configuration file.

Unit files are identified by their **name** and **type suffix**:

```
sshd.service          nginx.service
boot.mount            proc-sys-fs-binfmt_misc.automount
dev-sda1.device       swap.swap
multi-user.target     bluetooth.target
sshd.socket           dbus.socket
systemd-tmpfiles-clean.timer
```

### 2.2 Unit File Locations (Priority Order)

systemd reads unit files from multiple directories. Higher entries override lower:

| Priority | Location | Purpose |
|---|---|---|
| 1 (highest) | `/etc/systemd/system/` | Local admin configuration, overrides |
| 2 | `/run/systemd/system/` | Runtime-generated units (transient) |
| 3 (lowest) | `/lib/systemd/system/` | Package-shipped units (do not edit) |

For user sessions:

| Priority | Location |
|---|---|
| 1 | `~/.config/systemd/user/` |
| 2 | `/etc/systemd/user/` |
| 3 | `/lib/systemd/user/` |

### 2.3 Drop-in Overrides

Rather than editing `/lib/systemd/system/` files (which get overwritten on package updates), use **drop-in files** to extend or override individual directives:

```bash
# Creates /etc/systemd/system/sshd.service.d/override.conf
systemctl edit sshd.service

# Edit the full unit file copy (nuclear option)
systemctl edit --full sshd.service
```

A drop-in file looks like:

```ini
# /etc/systemd/system/sshd.service.d/override.conf
[Service]
Restart=always
RestartSec=3
```

Drop-ins only override the directives they specify; all other directives inherit from the base unit.

### 2.4 The systemd Binary Suite

```
systemctl      — control the service manager
journalctl     — query the journal
systemd-analyze — boot performance analysis
loginctl       — manage login sessions
hostnamectl    — manage hostname
timedatectl    — manage time/timezone
localectl      — manage locale
networkctl     — inspect networkd state
resolvectl     — inspect/query DNS via resolved
machinectl     — manage containers / VMs
systemd-run    — run a transient unit
systemd-cat    — pipe output to journal
```

---

## 3. Unit Files

All unit files share a common INI-style structure with sections. Most sections are optional depending on unit type.

### 3.1 Common Sections

#### `[Unit]` — Metadata and dependencies

```ini
[Unit]
Description=OpenSSH Server Daemon
Documentation=man:sshd(8) man:sshd_config(5)

# Ordering (does NOT imply dependency)
After=network.target sshd-keygen.target
Before=shutdown.target

# Dependencies
Requires=network.target        # hard: if network fails, this fails
Wants=network-online.target    # soft: attempt, but don't fail if absent
BindsTo=container@foo.service  # hard + stop this if the other stops
PartOf=sshd.socket             # propagate stop/restart from parent

# Conflict: if ssh.service starts, openssh.service stops
Conflicts=ssh.service

# Conditions (abort activation without error if false)
ConditionPathExists=/etc/ssh/sshd_config
ConditionFileNotEmpty=/etc/ssh/sshd_config
ConditionKernelVersion=>=5.4

# Assertions (abort with error if false)
AssertFileIsExecutable=/usr/sbin/sshd
```

#### `[Install]` — Enable/disable behaviour

```ini
[Install]
# Which target "enables" this unit by adding a dependency on it
WantedBy=multi-user.target

# Alternative: add as a Requires= dependency of another unit
RequiredBy=emergency.target

# Create a symlink alias
Alias=sshd.service

# Also enable/disable these units when this one is enabled
Also=sshd-keygen.service
```

`systemctl enable` reads this section and creates symlinks in
`/etc/systemd/system/<target>.wants/` or `<target>.requires/`.

### 3.2 Unit Type Reference

| Suffix | Key Section | Description |
|---|---|---|
| `.service` | `[Service]` | A process or daemon |
| `.target` | `[Unit]` only | Grouping / synchronisation point |
| `.socket` | `[Socket]` | Listening socket for activation |
| `.timer` | `[Timer]` | Scheduled / periodic activation |
| `.mount` | `[Mount]` | Filesystem mount (auto-generated from fstab) |
| `.automount` | `[Automount]` | Lazy mount on access |
| `.path` | `[Path]` | File/directory watch activation |
| `.device` | `[Unit]` only | udev device (auto-generated) |
| `.swap` | `[Swap]` | Swap file or partition |
| `.scope` | `[Scope]` | Externally created processes |
| `.slice` | `[Slice]` | cgroup hierarchy node |

---

## 4. Service Units

The `.service` unit is the most common type.

### 4.1 The `[Service]` Section

```ini
[Service]
# --- Process Management ---
Type=simple
ExecStart=/usr/bin/myapp --config /etc/myapp/config.yaml
ExecStartPre=/usr/bin/myapp --validate-config
ExecStartPost=/usr/bin/notify-started.sh
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/usr/bin/myapp --graceful-stop
ExecStopPost=/usr/bin/cleanup.sh

# --- Restart Policy ---
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60s
StartLimitBurst=3

# --- Identity ---
User=myapp
Group=myapp
SupplementaryGroups=docker audio

# --- Environment ---
Environment=NODE_ENV=production LOG_LEVEL=info
EnvironmentFile=/etc/myapp/env         # key=value file
EnvironmentFile=-/etc/myapp/env.local  # optional (- prefix)

# --- Working Directory & Paths ---
WorkingDirectory=/var/lib/myapp
RootDirectory=/opt/myapp-root          # chroot (optional)

# --- File Descriptors ---
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

# --- Capabilities & Security ---
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/myapp /tmp/myapp
```

### 4.2 Service Types

The `Type=` directive tells systemd how to determine when a service is "ready":

| Type | Readiness Signal | Use Case |
|---|---|---|
| `simple` | Immediately after `ExecStart` forks | Single foreground process |
| `exec` | After the exec() call succeeds | Like simple, but waits for exec |
| `forking` | When the parent process exits | Traditional daemons that double-fork |
| `oneshot` | After the process exits (with `RemainAfterExit=yes`) | Setup scripts, `ExecStart` runs once |
| `notify` | `sd_notify(READY=1)` sent by the process | Systemd-aware daemons (nginx, PostgreSQL) |
| `notify-reload` | Like notify; also uses `sd_notify` for reload | Extended notify variant |
| `dbus` | D-Bus name registered (`BusName=`) | D-Bus services |
| `idle` | After all jobs dispatched | Prevent interleaved output |

**Forking example** (traditional daemon):

```ini
[Service]
Type=forking
PIDFile=/run/myapp.pid
ExecStart=/usr/sbin/myapp -D       # -D = daemonise (forks)
```

**Oneshot example** (run-once setup):

```ini
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/ip link set eth0 up
ExecStop=/usr/bin/ip link set eth0 down
```

### 4.3 Restart Policies

| Value | Restarts on… |
|---|---|
| `no` | Never (default) |
| `always` | Any exit |
| `on-success` | Only clean exit (code 0, or listed in `SuccessExitStatus`) |
| `on-failure` | Non-zero exit, signal, timeout, watchdog |
| `on-abnormal` | Signal, timeout, watchdog (not clean or unclean exit) |
| `on-abort` | Unhandled signal only |
| `on-watchdog` | Watchdog timeout only |

**Rate limiting restarts:**

```ini
StartLimitIntervalSec=60    # within this window...
StartLimitBurst=5           # ...allow at most this many starts
```

If the burst is exceeded, the unit enters `failed` state and will not restart automatically. Reset with:

```bash
systemctl reset-failed myapp.service
```

### 4.4 Security Hardening Directives

systemd provides extensive sandboxing without containers:

```ini
[Service]
# Prevent privilege escalation
NoNewPrivileges=yes

# Private /tmp (not shared with other services)
PrivateTmp=yes

# Read-only /usr, /boot, /etc
ProtectSystem=strict

# No access to /home, /root
ProtectHome=yes

# No access to /proc of other processes
ProtectProc=invisible

# Private /dev (only whitelisted devices)
PrivateDevices=yes

# No network access
PrivateNetwork=yes

# Restrict system calls
SystemCallFilter=@system-service
SystemCallArchitectures=native

# Restrict address families
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Writable paths (when ProtectSystem=strict)
ReadWritePaths=/var/lib/myapp
ReadOnlyPaths=/etc/myapp

# Drop capabilities
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

Check the security score of any unit:

```bash
systemd-analyze security sshd.service
```

---

## 5. Targets

Targets synchronise boot stages and replace SysV runlevels. Unlike runlevels (a single active level), multiple targets can be active simultaneously.

### 5.1 Target Hierarchy

```
emergency.target          — minimal shell, read-only root
    │
rescue.target             — single-user shell, local filesystems mounted
    │
sysinit.target            — kernel modules, udev, clock, cryptsetup
    │
basic.target              — sockets, timers, paths, basic infrastructure
    │
multi-user.target         — all services, networking (no GUI)
    │
graphical.target          — display manager, GUI session
```

### 5.2 Target Comparison with SysV

| SysV Runlevel | systemd Target | Alias symlink |
|---|---|---|
| 0 | `poweroff.target` | `runlevel0.target` |
| 1 | `rescue.target` | `runlevel1.target` |
| 2, 3, 4 | `multi-user.target` | `runlevel2/3/4.target` |
| 5 | `graphical.target` | `runlevel5.target` |
| 6 | `reboot.target` | `runlevel6.target` |

### 5.3 Working with Targets

```bash
# Show current default target
systemctl get-default

# Change default target (persists across reboots)
systemctl set-default multi-user.target

# Switch to a target immediately (like telinit)
systemctl isolate rescue.target

# List active targets
systemctl list-units --type=target

# List all targets (including inactive)
systemctl list-units --type=target --all
```

### 5.4 Special Targets

| Target | Purpose |
|---|---|
| `default.target` | Symlink → actual default (graphical or multi-user) |
| `sysinit.target` | Early boot: udev, cryptsetup, journal, locale |
| `basic.target` | Mid-boot: sockets, timers, dbus |
| `network.target` | Networking *configured* (not necessarily online) |
| `network-online.target` | Networking *fully online* — use carefully (slows boot) |
| `sleep.target` | System about to suspend |
| `halt.target` | System halting |
| `final.target` | Last stage of shutdown |
| `initrd.target` | Root inside initramfs (before pivot_root) |

### 5.5 Custom Targets

```ini
# /etc/systemd/system/myapp.target
[Unit]
Description=My Application Stack
Requires=multi-user.target
After=multi-user.target
AllowIsolate=yes

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable myapp.target
systemctl isolate myapp.target
```

---

## 6. Dependency Ordering

systemd separates two distinct concepts that SysV conflated:

- **Ordering** — which unit starts *before* another.
- **Dependency** — which units *require* each other to be active.

### 6.1 Ordering Directives

| Directive | Meaning |
|---|---|
| `After=B` | This unit starts after B has started |
| `Before=B` | This unit starts before B starts |

Ordering is **bidirectional by implication**: if A has `After=B`, then B implicitly has `Before=A`. Ordering without dependency does *not* pull in the other unit — it only sequences them if both are being activated.

### 6.2 Dependency Directives

| Directive | Strength | Behaviour on failure of dependency |
|---|---|---|
| `Requires=B` | Hard | This unit fails if B fails to start |
| `Requisite=B` | Hard | This unit fails if B is not *already* active |
| `Wants=B` | Soft | B is started alongside; failure is ignored |
| `BindsTo=B` | Hardest | Stop this unit if B stops for any reason |
| `PartOf=B` | Propagation | Propagate stop/restart *from* B, not the other way |
| `Upholds=B` | Keep alive | Restart B if it stops while this unit is active |
| `Conflicts=B` | Conflict | Stop B when this unit starts (mutually exclusive) |

### 6.3 Dependency vs Ordering: A Key Example

```ini
# nginx depends on the network but doesn't need to wait for it to be online
[Unit]
Wants=network.target
After=network.target
```

```ini
# A database migration script must run AFTER postgresql is ready
[Unit]
Requires=postgresql.service
After=postgresql.service
```

Without `After=`, both units would start in parallel even though there is a `Requires=` dependency — the dependency ensures failure propagation, but not sequencing.

### 6.4 Implicit Dependencies

systemd auto-generates some dependencies without you declaring them:

- `.mount` units get `Before=local-fs.target` automatically.
- `.socket` units get a `Before=` the corresponding `.service`.
- `DefaultDependencies=yes` (default) adds `Requires=` and `After=` on `sysinit.target` and `Conflicts=` on `shutdown.target` for most unit types.

Disable for units that run during early boot or shutdown:

```ini
[Unit]
DefaultDependencies=no
```

### 6.5 Visualising Dependencies

```bash
systemd-analyze dot sshd.service | dot -Tsvg > sshd-deps.svg
systemd-analyze dot --to-pattern='*.target' | dot -Tsvg > targets.svg
```

---

## 7. Service States & the State Machine

### 7.1 Load State

Describes whether the unit file has been parsed:

| Load State | Meaning |
|---|---|
| `loaded` | Unit file found and parsed successfully |
| `not-found` | Unit file not found in any search path |
| `bad-setting` | Unit file found but contains errors |
| `error` | Other load error |
| `masked` | Deliberately disabled (symlinked to `/dev/null`) |

### 7.2 Active State

The high-level runtime state:

| Active State | Meaning |
|---|---|
| `active` | Running / mounted / listening / elapsed |
| `inactive` | Not running, clean exit |
| `activating` | In the process of starting |
| `deactivating` | In the process of stopping |
| `failed` | Exited with error, crashed, or hit rate limit |
| `reloading` | Running but reloading configuration |
| `maintenance` | (alias for failed in some contexts) |

### 7.3 Sub-State

A finer-grained state within the active state, specific to unit type. For services:

| Sub-State | Meaning |
|---|---|
| `running` | Main process alive |
| `exited` | Exited cleanly (oneshot with `RemainAfterExit`) |
| `dead` | Not running |
| `start-pre` | Running `ExecStartPre=` |
| `start` | Running `ExecStart=` |
| `start-post` | Running `ExecStartPost=` |
| `stop` | Running `ExecStop=` |
| `stop-sigterm` | Sent SIGTERM, waiting |
| `stop-sigkill` | Sent SIGKILL (timeout exceeded) |
| `stop-post` | Running `ExecStopPost=` |
| `auto-restart` | Waiting for `RestartSec=` before retry |
| `failed` | In failed state |

### 7.4 The State Transition Diagram

```
            ┌─────────────────────────────────────────────┐
            │                                             │
         start                                        stop/fail
            │                                             │
            ▼                                             │
  [inactive/dead]                                         │
       │                                                  │
  systemctl start / dependency activation                 │
       │                                                  │
       ▼                                                  │
  [activating]  ──── ExecStartPre fails ─────────► [failed]
       │                                                  ▲
       │ ExecStart succeeds                               │
       ▼                                                  │
  [active/running] ──── crash / non-zero exit ────────────┤
       │                                                  │
       │ Restart= + within rate limit                     │
       ▼                                                  │
  [auto-restart] ─── RestartSec elapsed ──► [activating]  │
       │                                                  │
       │ Rate limit exceeded                              │
       └─────────────────────────────────────────────────►┘
```

### 7.5 Masked State

Masking is stronger than disabling. A masked unit cannot be started manually or as a dependency:

```bash
systemctl mask bluetooth.service        # mask
systemctl unmask bluetooth.service      # unmask
```

Masking creates a symlink: `/etc/systemd/system/bluetooth.service → /dev/null`

---

## 8. Fundamental systemctl Commands

### 8.1 Service Lifecycle

```bash
# Start / stop / restart
systemctl start nginx.service
systemctl stop nginx.service
systemctl restart nginx.service

# Reload configuration without restarting (if supported)
systemctl reload nginx.service

# Reload if running, restart if stopped
systemctl reload-or-restart nginx.service

# Enable at boot (creates symlink in .wants/)
systemctl enable nginx.service

# Enable and start immediately
systemctl enable --now nginx.service

# Disable (remove symlink)
systemctl disable nginx.service

# Disable and stop immediately
systemctl disable --now nginx.service

# Mask (prevent any start)
systemctl mask nginx.service

# Unmask
systemctl unmask nginx.service
```

### 8.2 Inspection

```bash
# Status with recent log lines
systemctl status nginx.service

# Check if active (exit code 0 = active, 3 = inactive)
systemctl is-active nginx.service

# Check if enabled
systemctl is-enabled nginx.service

# Check if failed
systemctl is-failed nginx.service

# Show all unit properties
systemctl show nginx.service

# Show a specific property
systemctl show nginx.service --property=MainPID

# Show the unit file content
systemctl cat nginx.service

# List all loaded units
systemctl list-units

# List only services
systemctl list-units --type=service

# List failed units
systemctl list-units --failed

# List all units (including inactive)
systemctl list-units --all

# List unit files and their enable state
systemctl list-unit-files --type=service
```

### 8.3 System State

```bash
# Reload unit file changes (after editing a unit file)
systemctl daemon-reload

# Reboot / shutdown / halt / poweroff
systemctl reboot
systemctl poweroff
systemctl halt
systemctl suspend
systemctl hibernate
systemctl hybrid-sleep

# Rescue / emergency mode
systemctl rescue
systemctl emergency
```

### 8.4 Reset Failed State

```bash
# Clear failed state for a single unit
systemctl reset-failed nginx.service

# Clear all failed states
systemctl reset-failed
```

### 8.5 Dependency Inspection

```bash
# Show dependencies of a unit
systemctl list-dependencies nginx.service

# Show reverse dependencies (what depends on this unit)
systemctl list-dependencies --reverse nginx.service

# Show only required dependencies
systemctl list-dependencies --all nginx.service
```

---

## 9. The Journal (journald)

`systemd-journald` collects and stores log data from: the kernel, initramfs, services (stdout/stderr), and syslog. Logs are stored in a structured binary format under `/var/log/journal/`.

### 9.1 Basic Queries

```bash
# All logs, newest at bottom
journalctl

# Follow in real time (like tail -f)
journalctl -f

# Show only the most recent N lines
journalctl -n 50

# Logs from current boot
journalctl -b

# Logs from previous boot
journalctl -b -1

# List available boots
journalctl --list-boots

# Logs from a specific unit
journalctl -u nginx.service

# Follow a specific unit
journalctl -u nginx.service -f

# Kernel messages only
journalctl -k
```

### 9.2 Filtering

```bash
# By priority (emerg alert crit err warning notice info debug)
journalctl -p err
journalctl -p warning..err          # range

# By time
journalctl --since "2024-01-15 09:00:00"
journalctl --since "1 hour ago"
journalctl --since yesterday
journalctl --since "2024-01-15" --until "2024-01-16"

# By process
journalctl _PID=1234
journalctl _COMM=nginx              # by executable name
journalctl _UID=1000                # by user ID

# By systemd unit (more precise than -u for templated units)
journalctl _SYSTEMD_UNIT=nginx.service

# Combine filters (AND within same field, OR across same invocation)
journalctl -u nginx.service -p err --since "1 hour ago"
```

### 9.3 Output Formats

```bash
journalctl -o short          # default
journalctl -o short-precise  # microsecond timestamps
journalctl -o json           # JSON per line
journalctl -o json-pretty    # pretty-printed JSON
journalctl -o cat            # message only, no metadata
journalctl -o verbose        # all fields
journalctl -o export         # binary export format
```

### 9.4 Journal Management

```bash
# Disk usage
journalctl --disk-usage

# Vacuum old logs
journalctl --vacuum-time=2weeks      # delete logs older than 2 weeks
journalctl --vacuum-size=500M        # keep only last 500 MiB

# Verify journal integrity
journalctl --verify
```

**Persistent journal** — by default on some distros the journal is volatile (lost on reboot). To persist:

```bash
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald
```

Or set in `/etc/systemd/journald.conf`:

```ini
[Journal]
Storage=persistent        # auto | volatile | persistent | none
SystemMaxUse=1G
SystemKeepFree=200M
MaxRetentionSec=1month
```

---

## 10. Timers (Replacing cron)

Timer units (`.timer`) activate a corresponding service unit at scheduled times or intervals.

### 10.1 Monotonic Timers (relative to system events)

```ini
# /etc/systemd/system/mybackup.timer
[Unit]
Description=Run backup 15 minutes after boot, then every 6 hours

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
OnUnitInactiveSec=1h    # after the service last became inactive
AccuracySec=1min        # allow up to 1min jitter (battery-friendly)
Unit=mybackup.service

[Install]
WantedBy=timers.target
```

### 10.2 Realtime (Calendar) Timers

```ini
[Timer]
OnCalendar=daily                           # midnight every day
OnCalendar=weekly                          # Monday 00:00:00
OnCalendar=Mon,Tue *-*-* 02:00:00         # Mon+Tue at 2am
OnCalendar=*-*-* 09,17:00:00              # 9am and 5pm daily
OnCalendar=*-01-01 00:00:00               # New Year's Day
Persistent=true   # catch up if the system was off during scheduled time
```

Test calendar expressions:

```bash
systemd-analyze calendar "Mon,Fri *-*-* 08:00:00"
systemd-analyze calendar --iterations=5 "daily"
```

### 10.3 Timer Management

```bash
# Enable and start a timer
systemctl enable --now mybackup.timer

# List all active timers with next/last trigger times
systemctl list-timers
systemctl list-timers --all

# Check timer status
systemctl status mybackup.timer

# Trigger the associated service immediately (one-shot)
systemctl start mybackup.service
```

### 10.4 cron to Timer Migration

| cron expression | systemd `OnCalendar` |
|---|---|
| `@reboot` | `OnBootSec=0` (monotonic timer) |
| `* * * * *` | `OnCalendar=minutely` |
| `0 * * * *` | `OnCalendar=hourly` |
| `0 0 * * *` | `OnCalendar=daily` |
| `0 0 * * 0` | `OnCalendar=weekly` |
| `0 0 1 * *` | `OnCalendar=monthly` |
| `30 9 * * 1-5` | `OnCalendar=Mon..Fri *-*-* 09:30:00` |

---

## 11. Socket Activation

Socket activation allows services to be started on-demand when a client connects to a socket — without the service needing to be running continuously.

### 11.1 How It Works

1. systemd creates and listens on the socket.
2. A client connects; systemd activates the corresponding service.
3. The service inherits the already-connected socket via file descriptor 3 (or `$LISTEN_FDS`).
4. If no client connects, the service never starts.

### 11.2 Socket Unit

```ini
# /etc/systemd/system/myapp.socket
[Unit]
Description=MyApp Listening Socket

[Socket]
ListenStream=/run/myapp.sock    # UNIX socket
# ListenStream=8080             # TCP on port 8080
# ListenDatagram=514            # UDP
SocketUser=myapp
SocketMode=0660
Accept=no                       # pass socket to one service instance
# Accept=yes                    # spawn a new service per connection

[Install]
WantedBy=sockets.target
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=MyApp Service
Requires=myapp.socket
After=myapp.socket

[Service]
ExecStart=/usr/bin/myapp
StandardInput=socket    # for Accept=yes style
```

```bash
systemctl enable --now myapp.socket
# The service starts automatically on first connection
```

### 11.3 Well-known Socket-Activated Services

- `sshd.socket` (on some distros — start sshd per connection)
- `cups.socket` (printing)
- `dbus.socket`
- `systemd-journald.socket`

---

## 12. User Sessions

systemd manages per-user service managers, allowing users to run their own services without root privileges.

### 12.1 User Units

```bash
# Control user units (no sudo needed)
systemctl --user status myapp.service
systemctl --user start myapp.service
systemctl --user enable myapp.service

# Enable a user service to start on login
systemctl --user enable --now myapp.service

# Enable a user service to start even without a login session (lingering)
loginctl enable-linger $USER
```

**Lingering** allows user services to start at boot even when the user is not logged in — useful for running user-level web servers or bots.

### 12.2 User Unit File Location

Place user unit files in `~/.config/systemd/user/`.

```ini
# ~/.config/systemd/user/mybot.service
[Unit]
Description=My Telegram Bot

[Service]
ExecStart=/home/alice/.local/bin/mybot
Restart=on-failure
EnvironmentFile=/home/alice/.config/mybot/env

[Install]
WantedBy=default.target
```

### 12.3 User Session Environment

```bash
# Inspect the user systemd environment
systemctl --user show-environment

# Set a persistent environment variable for user units
systemctl --user set-environment MYVAR=value

# Unset
systemctl --user unset-environment MYVAR
```

### 12.4 loginctl

```bash
loginctl list-sessions          # active login sessions
loginctl session-status 1       # detailed session info
loginctl list-users
loginctl show-user alice
loginctl enable-linger alice    # enable linger
loginctl disable-linger alice
loginctl lock-session 1         # lock a session
loginctl terminate-session 1    # kill a session
```

---

## 13. Resource Control with cgroups

Every systemd unit runs inside a Linux **control group (cgroup)**, enabling resource accounting and limits without external tools.

### 13.1 The cgroup Hierarchy

```
system.slice
├── sshd.service
├── nginx.service
└── postgresql.service

user.slice
├── user-1000.slice
│   ├── session-1.scope       (login session)
│   └── user@1000.service     (user systemd instance)
│       └── mybot.service

machine.slice
└── systemd-nspawn@container1.service
```

### 13.2 Resource Directives in Unit Files

```ini
[Service]
# CPU
CPUWeight=100            # relative weight (default 100, range 1-10000)
CPUQuota=50%             # cap at 50% of one CPU

# Memory
MemoryMax=512M           # hard limit (OOM kill if exceeded)
MemoryHigh=400M          # soft limit (throttle before OOM)
MemorySwapMax=0          # prevent swap usage

# I/O
IOWeight=100             # relative I/O weight
IOReadBandwidthMax=/dev/sda 50M   # read limit
IOWriteBandwidthMax=/dev/sda 20M  # write limit

# Tasks (threads/processes)
TasksMax=128             # maximum number of tasks
```

### 13.3 Inspecting Resource Usage

```bash
# Real-time resource view of services (like top for systemd)
systemd-cgtop

# Show cgroup tree
systemd-cgls

# Resource usage of a unit
systemctl status nginx.service    # includes memory/CPU/tasks in output

# Detailed cgroup stats
cat /sys/fs/cgroup/system.slice/nginx.service/memory.current
```

### 13.4 Transient Units

Run a command in a resource-controlled cgroup without a unit file:

```bash
# Run with memory limit
systemd-run --unit=heavy-job --scope -p MemoryMax=1G /usr/bin/bigprocess

# Run as a transient service
systemd-run --unit=mytask.service --service-type=oneshot /usr/bin/myscript.sh

# Run as the current user
systemd-run --user --unit=myapp /usr/bin/myapp
```

---

## 14. Troubleshooting

### 14.1 Boot Performance

```bash
# Total boot time (firmware + loader + kernel + userspace)
systemd-analyze

# Time contributed by each unit
systemd-analyze blame

# Critical dependency chain (the bottleneck)
systemd-analyze critical-chain

# Critical chain for a specific unit
systemd-analyze critical-chain nginx.service

# SVG timeline of entire boot
systemd-analyze plot > /tmp/boot.svg

# Security hardening scores
systemd-analyze security
systemd-analyze security nginx.service
```

### 14.2 Diagnosing a Failed Unit

```bash
# Step 1: See what failed
systemctl list-units --failed

# Step 2: Get the full status and recent log
systemctl status failing-unit.service

# Step 3: Read the full journal for this unit this boot
journalctl -u failing-unit.service -b

# Step 4: Check the unit file for syntax errors
systemd-analyze verify /etc/systemd/system/failing-unit.service

# Step 5: After fixing, reload and restart
systemctl daemon-reload
systemctl restart failing-unit.service

# Step 6: If in rate-limited failed state
systemctl reset-failed failing-unit.service
systemctl start failing-unit.service
```

### 14.3 Dependency Cycle Detection

```bash
journalctl -b | grep "Found ordering cycle"
journalctl -b | grep "Breaking ordering cycle"

# Visualise dependencies
systemd-analyze dot failing-unit.service | dot -Tsvg > cycle.svg
```

### 14.4 Common Failure Patterns

**Unit not found:**
```
Unit myapp.service could not be found.
```
→ Check spelling; run `systemctl list-unit-files | grep myapp`; ensure the unit file is in a valid location; run `systemctl daemon-reload` after placing it.

**Permission denied:**
```
(code=exited, status=1/FAILURE)
journalctl shows: Permission denied
```
→ Check `User=` / `Group=` directives; check file ownership; check `PrivateTmp=`, `ProtectSystem=`, `ReadWritePaths=` restrictions.

**Start request repeated too quickly:**
```
start request repeated too quickly, refusing to start
```
→ Rate limit hit. Run `systemctl reset-failed myapp.service`, then adjust `StartLimitIntervalSec=` and `StartLimitBurst=`.

**Exec format error:**
```
(code=exited, status=203/EXEC)
```
→ The `ExecStart=` binary doesn't exist, isn't executable, or has a wrong shebang. Verify with `which` and `ls -la`.

**Masked unit:**
```
Failed to start myapp.service: Unit myapp.service is masked.
```
→ Run `systemctl unmask myapp.service`.

### 14.5 Inspecting Unit State in Detail

```bash
# Full property dump for a unit
systemctl show nginx.service

# Environment a service sees
systemctl show nginx.service --property=Environment

# What a unit file expands to after template instantiation
systemctl cat sshd@.service

# Check if a unit would activate at current target
systemctl is-enabled nginx.service

# Who wants this unit (reverse dependency)
systemctl list-dependencies --reverse nginx.service
```

### 14.6 Debugging with Verbose Output

To temporarily increase log verbosity for a single service:

```ini
# Drop-in override
[Service]
Environment=RUST_LOG=debug
Environment=DEBUG=1
StandardOutput=journal+console
StandardError=journal+console
```

Or start the service with environment overrides:

```bash
systemd-run --unit=myapp-debug \
  -p Environment="DEBUG=1" \
  -p StandardOutput=journal+console \
  /usr/bin/myapp
```

---

## 15. Reference Cheat Sheet

### systemctl Quick Reference

```bash
# Lifecycle
systemctl start|stop|restart|reload <unit>
systemctl enable|disable <unit>
systemctl enable --now <unit>       # enable + start
systemctl mask|unmask <unit>
systemctl reset-failed [unit]

# Inspection
systemctl status <unit>
systemctl is-active|is-enabled|is-failed <unit>
systemctl cat <unit>
systemctl show <unit>
systemctl list-units [--type=] [--failed] [--all]
systemctl list-unit-files [--type=]
systemctl list-dependencies [--reverse] <unit>
systemctl list-timers [--all]

# System
systemctl daemon-reload             # after editing unit files
systemctl get-default               # show default target
systemctl set-default <target>
systemctl isolate <target>

# Power
systemctl reboot|poweroff|suspend|hibernate
```

### journalctl Quick Reference

```bash
journalctl -b               # this boot
journalctl -b -1            # previous boot
journalctl -f               # follow
journalctl -u <unit>        # by unit
journalctl -k               # kernel only
journalctl -p err           # priority filter
journalctl --since "1h ago"
journalctl --disk-usage
journalctl --vacuum-time=2w
```

### Key Files

| File / Directory | Purpose |
|---|---|
| `/lib/systemd/system/` | Package unit files (read-only) |
| `/etc/systemd/system/` | Local unit files and overrides |
| `/etc/systemd/system/<unit>.d/` | Drop-in directory for a unit |
| `/run/systemd/system/` | Runtime / transient units |
| `/etc/systemd/system/default.target` | Symlink to default target |
| `/etc/systemd/journald.conf` | Journal configuration |
| `/etc/systemd/system.conf` | Global systemd configuration |
| `/var/log/journal/` | Persistent journal storage |
| `~/.config/systemd/user/` | User unit files |

### Unit Dependency Reference

| Directive | Type | Failure behaviour |
|---|---|---|
| `Wants=` | Soft dependency | Ignored |
| `Requires=` | Hard dependency | This unit fails |
| `Requisite=` | Hard (must already be active) | This unit fails |
| `BindsTo=` | Hard + stop propagation | This unit stops |
| `PartOf=` | Stop/restart propagation only | Follows parent |
| `After=` | Ordering only | No effect |
| `Before=` | Ordering only | No effect |
| `Conflicts=` | Mutual exclusion | Other unit stopped |

---

*Tested against systemd 252+ (Debian 12, Ubuntu 22.04+, RHEL 9, Fedora 38+). Some directives may not be available on older systemd versions.*