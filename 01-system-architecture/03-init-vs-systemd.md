# init vs systemd

> A deep comparison of traditional SysV init and modern systemd — covering architecture, service management, boot behaviour, compatibility, and the reasoning behind Linux's near-universal adoption of systemd.

---

## Table of Contents

1. [The Role of PID 1](#1-the-role-of-pid-1)
2. [SysV init — The Traditional Model](#2-sysv-init)
3. [The Problems SysV init Could Not Solve](#3-sysv-problems)
4. [Intermediate Systems: Upstart & OpenRC](#4-intermediate-systems)
5. [systemd — The Modern Model](#5-systemd)
6. [Architectural Comparison](#6-architectural-comparison)
7. [Service Management: Side by Side](#7-service-management)
8. [Boot Sequence Comparison](#8-boot-sequence)
9. [Runlevels vs Targets](#9-runlevels-vs-targets)
10. [Init Scripts vs Unit Files](#10-scripts-vs-unit-files)
11. [Logging: syslog vs journald](#11-logging)
12. [Dependency Handling](#12-dependency-handling)
13. [Advantages of systemd](#13-advantages-of-systemd)
14. [Criticisms of systemd](#14-criticisms)
15. [Transitional Compatibility](#15-compatibility)
16. [Unit File Layout In Depth](#16-unit-file-layout)
17. [Migration Reference](#17-migration-reference)

---

## 1. The Role of PID 1

Every Linux system has a single special process: **PID 1**. It is:

- The first userspace process spawned by the kernel after boot.
- The **ancestor of all other processes** — every daemon, shell, and application is a descendant.
- The only process that is **never automatically killed** by the kernel's OOM killer.
- Responsible for **reaping orphaned zombie processes** (calling `waitpid` for children whose parents have exited).
- Expected to bring the system to a usable state and gracefully shut it down.

If PID 1 exits or crashes, the kernel panics. This makes it the most critical userspace process on the system, and the choice of what runs as PID 1 — the *init system* — has profound consequences for how the entire OS behaves.

```
Kernel
  └── PID 1 (init / systemd)
        ├── sshd
        ├── cron
        ├── nginx
        │     └── nginx worker
        └── login
              └── bash
                    └── vim
```

---

## 2. SysV init — The Traditional Model

SysV init (System V init, pronounced "System Five init") originated in Unix System V in the early 1980s and was the dominant Linux init system from the beginning until the mid-2010s.

### 2.1 Core Design

SysV init is **simple by philosophy**: PID 1 reads a single configuration file (`/etc/inittab`), sets a runlevel, and executes shell scripts sequentially to start services.

The entire init system is essentially:

```
/sbin/init          — the binary (typically a few hundred KB)
/etc/inittab        — configuration file
/etc/init.d/        — service scripts
/etc/rc*.d/         — symlink farm controlling what runs in each runlevel
```

### 2.2 /etc/inittab

The central configuration file. Each line has the format:

```
id:runlevel:action:process
```

```
# /etc/inittab (classic example)

# Default runlevel
id:5:initdefault:

# System initialisation
si::sysinit:/etc/init.d/rcS

# Runlevel scripts
l0:0:wait:/etc/init.d/rc 0
l1:1:wait:/etc/init.d/rc 1
l2:2:wait:/etc/init.d/rc 2
l3:3:wait:/etc/init.d/rc 3
l4:4:wait:/etc/init.d/rc 4
l5:5:wait:/etc/init.d/rc 5
l6:6:wait:/etc/init.d/rc 6

# Virtual consoles
1:2345:respawn:/sbin/getty 38400 tty1
2:23:respawn:/sbin/getty 38400 tty2
3:23:respawn:/sbin/getty 38400 tty3

# Ctrl-Alt-Del
ca::ctrlaltdel:/sbin/shutdown -t3 -r now
```

### 2.3 Runlevels

SysV init defines numbered runlevels representing system states:

| Runlevel | Conventional Meaning | Notes |
|---|---|---|
| 0 | Halt | Shuts down the system |
| 1 | Single-user / Maintenance | No networking, root only |
| 2 | Multi-user | Debian: includes networking |
| 3 | Multi-user + networking | RHEL/Fedora: no GUI |
| 4 | Undefined | User-defined |
| 5 | Multi-user + GUI | RHEL/Fedora default |
| 6 | Reboot | |
| S / s | Single-user (alias for 1) | |

Only **one runlevel is active** at a time. Switching runlevels runs the stop scripts of the old level and the start scripts of the new level.

### 2.4 The rc Script System

When entering runlevel N, init runs `/etc/init.d/rc N`, which iterates over `/etc/rcN.d/`:

```
/etc/rc5.d/
├── K01bluetooth         → ../init.d/bluetooth   (Kill)
├── K05NetworkManager    → ../init.d/NetworkManager
├── S01rsyslog           → ../init.d/rsyslog      (Start)
├── S10network           → ../init.d/network
├── S15sshd              → ../init.d/sshd
├── S20httpd             → ../init.d/httpd
└── S99local             → ../init.d/rc.local
```

- Files starting with **K** are stopped (in numeric order).
- Files starting with **S** are started (in numeric order).
- The number controls sequence — there is no dependency system.

### 2.5 Init Scripts (LSB format)

Each service in `/etc/init.d/` is a shell script implementing a standard interface:

```bash
#!/bin/bash
# /etc/init.d/myapp — LSB init script

### BEGIN INIT INFO
# Provides:          myapp
# Required-Start:    $network $syslog
# Required-Stop:     $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: My Application
# Description:       Longer description of myapp
### END INIT INFO

. /lib/lsb/init-functions

DAEMON=/usr/bin/myapp
PIDFILE=/var/run/myapp.pid

case "$1" in
  start)
    log_daemon_msg "Starting myapp"
    start-stop-daemon --start --pidfile $PIDFILE \
      --make-pidfile --background --exec $DAEMON
    log_end_msg $?
    ;;
  stop)
    log_daemon_msg "Stopping myapp"
    start-stop-daemon --stop --pidfile $PIDFILE
    log_end_msg $?
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  status)
    status_of_proc -p $PIDFILE "$DAEMON" myapp
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
```

Tools for managing the symlink farm:

```bash
update-rc.d myapp defaults        # Debian/Ubuntu
chkconfig myapp on                # RHEL/CentOS
```

---

## 3. The Problems SysV init Could Not Solve

By the late 2000s, SysV init's limitations had become acute as systems grew more complex.

### 3.1 Strictly Sequential Boot

SysV init starts services **one at a time**, in symlink-number order. Service N+1 cannot start until service N has fully started. On a modern system with dozens of services, this is wasteful — most services spend the majority of their startup time waiting for I/O (disk reads, DNS queries, socket binds), during which the CPU sits idle.

```
SysV boot timeline (sequential):
─────────────────────────────────────────────────────►  time
[rsyslog    ]
             [network    ]
                          [dbus     ]
                                     [sshd ]
                                            [nginx    ]
                                                       [login]
```

```
systemd boot timeline (parallel):
─────────────────────────────────────────────────────►  time
[rsyslog]
[network          ]
[dbus    ]
[sshd    ]
[nginx        ]
[login]
```

The practical difference on real hardware: a typical SysV boot takes **45–90 seconds**; systemd commonly achieves **5–15 seconds** on the same machine.

### 3.2 No Real Dependency Model

The numeric ordering system in `rc*.d/` is a **proxy** for dependencies, not an expression of them. If `S20httpd` needs `S10network`, the administrator must manually ensure the numbers are correct. There is no enforcement, no error on violation, and no way to express "start httpd after network is *online*, not just after the network script has exited."

The LSB `Required-Start:` comment headers are hints to tools like `insserv` that can reorder scripts, but they are not enforced at runtime.

### 3.3 No Service Supervision

Once a SysV init script starts a daemon and exits, init has no further involvement. If the daemon crashes:

- Nothing restarts it automatically.
- No notification is sent.
- The PID file may be stale.
- `service myapp status` may incorrectly report "running".

Workarounds like **daemontools**, **runit**, or **supervisor** existed but were external to the init system, requiring separate configuration.

### 3.4 No Process Tracking

SysV init does not track which processes belong to which service. A service that forks child processes leaves those children completely unaccounted for. Stopping a service with `service myapp stop` may:

- Leave worker processes running.
- Fail if the daemon double-forked and the PID file is wrong.
- Do nothing if the script lacks a proper stop implementation.

### 3.5 Shell Script Complexity and Fragility

Every init script is a free-form shell script. This means:

- **No standardisation** — scripts from different distributions are incompatible.
- **Silent failures** — a script can `exit 0` after a failure, and init will never know.
- **Race conditions** — scripts that check "is this running?" before starting have inherent races.
- **Security surface** — arbitrary code runs as root on every boot.
- **Slow** — shell interpreters, subshells, and fork/exec chains are expensive.

### 3.6 No On-demand Activation

Every service configured to start at boot starts at boot, whether or not any client ever uses it. `lpd` (printing), `cups`, `bluetooth`, `avahi` — all start unconditionally. On a server that never prints, the print daemon wastes memory for the entire uptime.

### 3.7 Logging Is Disconnected

SysV init has no log capture. A service's stdout and stderr go wherever the script redirects them — often `/dev/null`, a log file with no rotation, or nowhere at all. Kernel messages go to `dmesg`. Boot messages go to syslog (if syslog has started yet). There is no unified, queryable log.

---

## 4. Intermediate Systems: Upstart & OpenRC

Before systemd won, two systems attempted to solve SysV's problems.

### 4.1 Upstart

Developed by Canonical (Ubuntu), introduced in Ubuntu 6.10 (2006), used through Ubuntu 14.10.

**Key innovations:**
- **Event-driven** — services are defined by the events that start/stop them (`start on started networking`), not runlevel numbers.
- **Parallel startup** — services start as their trigger events fire.
- **D-Bus integration** — can react to hardware events.

**Why it lost:**
- Events-as-dependencies proved difficult to reason about.
- Complex services required elaborate event chains.
- Red Hat chose systemd for RHEL 7; without Red Hat, Upstart had no enterprise future.
- Ubuntu adopted systemd in 15.04 (2015).

```
# Upstart job example (/etc/init/myapp.conf)
description "My Application"
start on (filesystem and started networking)
stop on runlevel [!2345]
respawn
exec /usr/bin/myapp --foreground
```

### 4.2 OpenRC

A dependency-based init system used by Gentoo, Alpine Linux, and Devuan. Still actively maintained.

**Key innovations:**
- True dependency declarations in service scripts.
- Parallel startup option.
- No PID 1 replacement — OpenRC works with any simple init (busybox init, sysvinit, runit) as PID 1.

**Why it remains:**
- Beloved on minimal and embedded systems.
- Default on Alpine Linux (common for containers).
- Chosen by Devuan (the Debian fork created specifically to avoid systemd).

```bash
# OpenRC service file (/etc/init.d/myapp)
#!/sbin/openrc-run
description="My Application"
command=/usr/bin/myapp
command_args="--foreground"
depend() {
    need net
    after logger
}
```

---

## 5. systemd — The Modern Model

systemd was created by Lennart Poettering and Kay Sievers at Red Hat, first released in 2010. It was explicitly designed to solve every known limitation of SysV init.

### 5.1 Design Goals

1. **Start services in parallel** — as aggressively as possible.
2. **Express real dependencies** — not numeric ordering hacks.
3. **Supervise all services** — restart on failure, track all children.
4. **Track processes with cgroups** — guaranteed clean shutdown of all service processes.
5. **Activate on demand** — socket, D-Bus, path, timer, and device activation.
6. **Unified logging** — capture stdout/stderr from every service into a structured journal.
7. **Replace the entire plumbing layer** — udev, logind, journald, networkd, resolved, timedated.
8. **Declarative configuration** — INI-style unit files instead of shell scripts.

### 5.2 The Socket Activation Trick

The key insight enabling aggressive parallelism: **sockets can be created before the service that will handle them**. systemd creates all sockets at boot, then starts services in parallel. If service A needs to connect to service B's socket, A can proceed immediately — the kernel buffers the connection until B is ready.

```
Traditional (sequential):
  Start service B → B opens socket → Start service A → A connects

systemd (parallel):
  systemd opens B's socket
  Start service A  ─────────────────► A connects (kernel buffers)
  Start service B  ─► B inherits socket from systemd, drains buffer
```

This means services that depend on each other via sockets can start **simultaneously**, even though one depends on the other.

---

## 6. Architectural Comparison

| Dimension | SysV init | systemd |
|---|---|---|
| **PID 1 binary size** | ~100 KB | ~1.5 MB (but replaces dozens of other tools) |
| **Configuration format** | Shell scripts | Declarative INI files |
| **Service start order** | Strictly sequential | Maximally parallel |
| **Dependency model** | Numeric ordering + LSB hints | Explicit `Requires=`, `Wants=`, `After=` |
| **Process tracking** | PID file (unreliable) | cgroups (kernel-enforced) |
| **Service supervision** | None (external tools needed) | Built-in, configurable `Restart=` |
| **On-demand activation** | None | Socket, D-Bus, path, timer, device |
| **Logging** | External syslog | Built-in journald (structured binary) |
| **Shutdown** | `kill -TERM -1` (all processes) | Per-cgroup clean shutdown |
| **User sessions** | None | systemd --user per session |
| **Resource control** | None | cgroups: CPU, memory, I/O limits |
| **Boot time** | 45–90 seconds (typical) | 5–15 seconds (typical) |
| **Scope** | Init only | Init + udev + journal + login + network + … |
| **Lines of code** | ~3,000 | ~1,300,000+ |

---

## 7. Service Management: Side by Side

### Starting and Stopping

| Action | SysV init | systemd |
|---|---|---|
| Start a service | `service nginx start` | `systemctl start nginx` |
| Stop a service | `service nginx stop` | `systemctl stop nginx` |
| Restart | `service nginx restart` | `systemctl restart nginx` |
| Reload config | `service nginx reload` | `systemctl reload nginx` |
| Status | `service nginx status` | `systemctl status nginx` |

### Enabling at Boot

| Action | SysV (Debian) | SysV (RHEL) | systemd |
|---|---|---|---|
| Enable at boot | `update-rc.d nginx defaults` | `chkconfig nginx on` | `systemctl enable nginx` |
| Disable at boot | `update-rc.d nginx disable` | `chkconfig nginx off` | `systemctl disable nginx` |
| Enable + start now | (two commands) | (two commands) | `systemctl enable --now nginx` |

### Listing Services

| Action | SysV | systemd |
|---|---|---|
| List all services | `service --status-all` | `systemctl list-units --type=service` |
| List enabled at boot | `chkconfig --list` | `systemctl list-unit-files --type=service` |
| List failed | (manual grep) | `systemctl list-units --failed` |

---

## 8. Boot Sequence Comparison

### SysV Boot Sequence

```
1. Kernel executes /sbin/init
2. init reads /etc/inittab → determines default runlevel (e.g. 5)
3. init runs /etc/init.d/rcS  (system initialisation — sequential)
4. init runs /etc/init.d/rc 5 (runlevel 5 scripts — sequential)
   ├── Stop K* scripts from previous runlevel
   └── Start S* scripts in numeric order:
         S01rsyslog → wait → S10network → wait → S15sshd → ...
5. init spawns getty processes on tty1–tty6
6. Login prompt appears
```

**Total wall time:** sum of all script execution times (no parallelism).

### systemd Boot Sequence

```
1. Kernel executes /lib/systemd/systemd (or /sbin/init → symlink)
2. systemd reads all unit files (parallel parse)
3. systemd activates default.target (→ graphical.target or multi-user.target)
4. Dependency graph built → parallelism maximised
5. sysinit.target (kernel modules, udev, clock, cryptsetup)
   │   ↕ parallel
6. basic.target (sockets, timers, paths, dbus)
   │   ↕ parallel
7. All service units in multi-user.target start simultaneously
   (held back only by declared After= / Requires= dependencies)
8. graphical.target → display manager starts
9. Login prompt / display manager
```

**Total wall time:** length of the critical dependency chain, not the sum.

---

## 9. Runlevels vs Targets

### SysV Runlevels — A Single Integer

The system is always in exactly one runlevel. Switching runlevels stops everything configured for the old level and starts everything configured for the new level. The mechanism is entirely symlink-driven.

```bash
# Check current runlevel
runlevel
# Output: N 5  (previous: N/A, current: 5)

# Change runlevel
telinit 3

# Set default runlevel (edit /etc/inittab)
id:3:initdefault:
```

### systemd Targets — Composable Milestones

Targets are synchronisation points that can be active simultaneously. They do not represent a single system state; they represent satisfied sets of dependencies.

```bash
# Check default target
systemctl get-default
# Output: graphical.target

# Change default target
systemctl set-default multi-user.target

# Switch target now (closest to telinit)
systemctl isolate rescue.target

# List active targets
systemctl list-units --type=target
```

**Key difference:** when `multi-user.target` is active, `basic.target` and `sysinit.target` are *also* active — they are not exited when a higher target is reached. SysV has no equivalent; it only knows the current runlevel number.

### Runlevel to Target Mapping

```
/lib/systemd/system/runlevel0.target → poweroff.target
/lib/systemd/system/runlevel1.target → rescue.target
/lib/systemd/system/runlevel2.target → multi-user.target
/lib/systemd/system/runlevel3.target → multi-user.target
/lib/systemd/system/runlevel4.target → multi-user.target
/lib/systemd/system/runlevel5.target → graphical.target
/lib/systemd/system/runlevel6.target → reboot.target
```

---

## 10. Init Scripts vs Unit Files

This is the most visible difference for administrators and package maintainers.

### SysV Init Script

```bash
#!/bin/bash
# /etc/init.d/mywebapp
### BEGIN INIT INFO
# Provides:          mywebapp
# Required-Start:    $network $remote_fs $syslog
# Required-Stop:     $network $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: My Web Application
### END INIT INFO

NAME=mywebapp
DAEMON=/usr/bin/mywebapp
DAEMON_ARGS="--port 8080 --workers 4"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start() {
    start-stop-daemon --start --quiet --pidfile $PIDFILE \
        --exec $DAEMON --test > /dev/null || return 1
    start-stop-daemon --start --quiet --pidfile $PIDFILE \
        --make-pidfile --background --exec $DAEMON -- $DAEMON_ARGS \
        || return 2
}

do_stop() {
    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 \
        --pidfile $PIDFILE --name $NAME
    RETVAL="$?"
    rm -f $PIDFILE
    return "$RETVAL"
}

case "$1" in
    start)
        log_daemon_msg "Starting $NAME"
        do_start
        case "$?" in
            0|1) log_end_msg 0 ;;
            2) log_end_msg 1 ;;
        esac ;;
    stop)
        log_daemon_msg "Stopping $NAME"
        do_stop
        case "$?" in
            0|1) log_end_msg 0 ;;
            2) log_end_msg 1 ;;
        esac ;;
    restart|force-reload)
        $0 stop
        $0 start ;;
    status)
        status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $? ;;
    *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|status}" >&2
        exit 3 ;;
esac
exit 0
```

**Line count:** ~60 lines of boilerplate to manage one binary.

### Equivalent systemd Unit File

```ini
# /lib/systemd/system/mywebapp.service
[Unit]
Description=My Web Application
After=network.target

[Service]
ExecStart=/usr/bin/mywebapp --port 8080 --workers 4
Restart=on-failure
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
```

**Line count:** 11 lines. No boilerplate, no shell, no error-handling code — systemd provides all of that.

### Feature Comparison

| Feature | Init Script | Unit File |
|---|---|---|
| Restart on crash | Manual (or external supervisor) | `Restart=on-failure` |
| Run as user | Manual (`su`, `sudo -u`) | `User=www-data` |
| Environment variables | `export VAR=val` in script | `Environment=` or `EnvironmentFile=` |
| Working directory | `cd /path` in script | `WorkingDirectory=` |
| Resource limits | `ulimit` in script | `LimitNOFILE=`, `MemoryMax=` |
| Private /tmp | Not possible without containers | `PrivateTmp=yes` |
| Log capture | Manual redirection | Automatic via journald |
| Dependency declaration | LSB header comments (advisory) | `Requires=`, `Wants=` (enforced) |
| Enable at boot | Separate tool (`update-rc.d`, `chkconfig`) | `systemctl enable` |
| Reload without restart | Manual implementation required | `ExecReload=` directive |

---

## 11. Logging: syslog vs journald

### The Traditional syslog Stack

In a SysV system, logging is assembled from several independent pieces:

```
Kernel          → /dev/kmsg → klogd → syslogd → /var/log/kern.log
Services        → syslog() C call → syslogd → /var/log/syslog
Init scripts    → stdout/stderr → wherever the script redirects (often /dev/null)
Boot messages   → console only (lost after boot)
```

Problems:
- **Fragmented** — boot messages, kernel messages, and service messages are in separate files.
- **Text-only** — no structured metadata; grepping is the only query mechanism.
- **Lost messages** — syslogd starts late; messages before it starts are lost.
- **No rate limiting** — a misbehaving service can fill the disk.
- **Stdout/stderr invisible** — a service writing to stdout instead of syslog is invisible.

### systemd journald

systemd starts journald very early (it runs inside the initramfs). Every service's stdout and stderr are captured automatically. The journal is a **structured binary log** with indexed metadata fields.

```
Kernel          → journald (via /dev/kmsg) → indexed
initramfs       → journald → indexed
All services    → journald (stdout/stderr captured automatically)
Explicit syslog → journald → also forwarded to /dev/log for compat
```

**Journal metadata fields** (queryable):

```
_SYSTEMD_UNIT=nginx.service
_PID=1234
_UID=33
_GID=33
_COMM=nginx
_EXE=/usr/sbin/nginx
PRIORITY=6
_BOOT_ID=abc123...
_MACHINE_ID=def456...
__REALTIME_TIMESTAMP=1706000000000000
```

**Querying examples:**

```bash
# All errors from this boot
journalctl -b -p err

# All messages from a specific unit
journalctl -u nginx.service

# All messages from processes with UID 1000
journalctl _UID=1000

# Combine: nginx errors in the last hour
journalctl -u nginx.service -p err --since "1 hour ago"

# Output as JSON
journalctl -u nginx.service -o json-pretty | head -40
```

No equivalent query is possible with flat syslog files without external tools.

---

## 12. Dependency Handling

### SysV: Ordering by Convention

SysV has no runtime dependency system. The administrator manually assigns start numbers:

```
S10network    — must come before anything that needs networking
S15sshd       — needs network, so assigned a higher number
S20httpd      — needs network, so assigned an even higher number
```

If a service with a lower number fails, SysV will attempt to start services with higher numbers regardless. There is no propagation of failure.

The LSB `Required-Start:` header is parsed by tools like `insserv` to auto-assign numbers, but at runtime, it is invisible to init.

### systemd: Declared Dependencies with Propagation

systemd builds a **dependency graph** before starting anything and propagates state changes:

```ini
# If postgresql fails to start:
[Unit]
Requires=postgresql.service    # myapp will not start (or will fail)
After=postgresql.service       # myapp starts after postgresql is ready
```

```ini
# If postgresql restarts at runtime:
[Unit]
BindsTo=postgresql.service     # myapp will be stopped automatically
```

```ini
# Soft dependency — try but don't require:
[Unit]
Wants=redis.service            # redis is started alongside; failure is ignored
After=redis.service
```

**Dependency types at a glance:**

| Type | What happens if the dependency fails |
|---|---|
| `Requires=` | This unit also fails |
| `Requisite=` | This unit fails (dependency must already be active) |
| `Wants=` | Nothing — failure is silently ignored |
| `BindsTo=` | This unit stops when the dependency stops |
| `PartOf=` | Propagate stop and restart from parent only |
| `Conflicts=` | Both cannot be active simultaneously |

**Ordering vs dependency** — a critical distinction absent in SysV:

```ini
After=postgresql.service   # ordering only: start after pg, but don't pull it in
Wants=postgresql.service   # dependency only: start pg alongside, but no ordering
# Both together = start pg, then start this unit after pg is ready
```

---

## 13. Advantages of systemd

### 13.1 Dramatic Boot Speed Improvement

Parallelism and socket activation make systemd boots **3–10× faster** than SysV on equivalent hardware. On SSDs with modern distributions, desktop systems routinely boot to login in under 10 seconds.

### 13.2 Reliable Service Supervision

```ini
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60s
StartLimitBurst=3
```

A service with `Restart=on-failure` will automatically restart after a crash, with configurable delay and rate limiting. SysV requires a separate supervisor daemon (daemontools, monit, supervisor) to achieve this.

### 13.3 Accurate Process Tracking via cgroups

Every service runs in its own cgroup. When a service is stopped, **all** processes in that cgroup are stopped — including workers, subshells, and any processes that double-forked to escape PID tracking. The "escaped process" problem that plagued SysV stop scripts is eliminated.

```bash
# See the cgroup tree in real time
systemd-cgls

# See resource usage per service
systemd-cgtop
```

### 13.4 On-demand Activation

Services that are rarely used do not need to run continuously:

```ini
# cups.socket — printing daemon starts only when a print job is submitted
# bluetooth.service — starts only when a Bluetooth device is detected
# sshd.socket — on some configs, sshd starts per-connection
```

This reduces the number of background processes on a typical system by 30–50%.

### 13.5 Unified, Structured Logging

All logs from all sources — kernel, initramfs, all services — are in one queryable store. Binary format enables structured queries impossible with text logs. Persistent across reboots. Rate-limited to prevent disk flooding.

### 13.6 Declarative, Auditable Configuration

Unit files are deterministic. The same unit file produces the same behaviour on any system. Shell scripts are not — they depend on the environment, installed tools, and execution context.

Security analysis tools can parse unit files:

```bash
systemd-analyze security nginx.service
# Outputs a scored security assessment of the unit's sandbox directives
```

### 13.7 Rich Ecosystem Integration

systemd is deeply integrated with:

- **udev** — device management and hotplug rules.
- **logind** — multi-seat, power management, session tracking.
- **networkd** — declarative network configuration.
- **resolved** — DNS caching and DNSSEC.
- **timesyncd** — NTP synchronisation.
- **homed** — portable home directories.
- **container managers** — nspawn, podman, Docker.

### 13.8 Transient Units and Runtime Management

```bash
# Run a one-off command in a resource-controlled scope
systemd-run --scope -p MemoryMax=512M /usr/bin/heavy-process

# Run a temporary service without a unit file
systemd-run --unit=temp-task --service-type=oneshot /usr/bin/myscript.sh
```

---

## 14. Criticisms of systemd

systemd is not without controversy. Understanding the criticisms is part of understanding the landscape.

### 14.1 Scope Creep ("Not Just an Init System")

systemd has grown to include journald, udev, networkd, resolved, timesyncd, logind, homed, and more. Critics argue this violates the Unix philosophy of "do one thing well" — the system becomes difficult to partially adopt or replace.

**Counter-argument:** all these components are optional (most can be replaced) and they share infrastructure (cgroups, D-Bus, socket activation) that would otherwise be duplicated.

### 14.2 Binary Log Format

The journal's binary format is not human-readable with standard tools (`cat`, `grep`). Requires `journalctl` to access.

**Counter-argument:** `journalctl` is universally available, and `journalctl -o cat` provides plain text. The binary format enables structured queries impossible with text logs.

### 14.3 Complexity and Attack Surface

At 1.3M+ lines of code, systemd is orders of magnitude larger than SysV init. A bug in PID 1 can be catastrophic.

**Counter-argument:** SysV init's simplicity was an illusion — the complexity lived in hundreds of shell scripts, each with its own bugs. systemd centralises and makes that complexity auditable.

### 14.4 D-Bus Dependency

Many systemd components require D-Bus, adding a dependency that doesn't exist in minimal embedded environments.

**Counter-argument:** systemd supports running without D-Bus for components that don't need it; embedded targets (like Alpine's use of OpenRC) simply don't use systemd.

### 14.5 Init Script Compatibility

Distributions that migrated to systemd needed to ship compatibility shims for existing SysV init scripts. This worked reasonably well, but the transition period created inconsistencies.

---

## 15. Transitional Compatibility

### 15.1 The SysV Compatibility Layer

systemd ships a compatibility layer that wraps SysV init scripts as synthetic service units. A script at `/etc/init.d/myapp` is automatically available as `myapp.service` without any migration work.

**How it works:**

```
/etc/init.d/myapp
        ↓
systemd generates a synthetic unit:
        ↓
myapp.service → ExecStart=/etc/init.d/myapp start
                ExecStop=/etc/init.d/myapp stop
                ExecReload=/etc/init.d/myapp reload
```

The LSB `Required-Start:` and `Required-Stop:` headers are parsed and translated into `After=` / `Before=` relationships.

**Limitations:**
- No supervision (`Restart=` cannot be inferred from a script).
- No log capture (scripts redirect their own output).
- No cgroup tracking (the script's process tree is not attributed).
- Performance benefit is limited — scripts are still sequential.

### 15.2 The `service` Command Wrapper

The legacy `service` command is retained on systemd systems as a wrapper:

```bash
service nginx start     # → systemctl start nginx.service
service nginx status    # → systemctl status nginx.service
```

On RHEL/CentOS, `chkconfig` similarly wraps `systemctl enable/disable`.

### 15.3 `systemd-sysv-generator`

This generator runs at boot and scans `/etc/init.d/`. For every script, it creates a synthetic unit file in `/run/systemd/generator/`. These units:

- Honour the LSB headers for ordering.
- Pass through `start`, `stop`, `reload`, `status` verbs.
- Cannot take advantage of any systemd-specific features.

### 15.4 Parallel SysV Script Support

On Debian-derived systems that used `sysv-rc`, parallel script execution was an option (`CONCURRENCY=makefile` in `/etc/default/rcS`). However, this required the LSB dependency headers to be correct on every installed script — a fragile assumption in practice.

### 15.5 Migrating a SysV Script to a Unit File

**Step 1: Identify what the script does**

```bash
# Read the script
cat /etc/init.d/myapp

# Key things to extract:
# - DAEMON= path to the binary
# - DAEMON_ARGS= arguments
# - User it runs as
# - Files it needs to exist
# - Services it depends on
```

**Step 2: Write the unit file**

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application           # from Short-Description:
Documentation=https://myapp.example.com
After=network.target syslog.target   # from Required-Start: $network $syslog

[Service]
Type=simple                          # forking if daemon double-forks
ExecStart=/usr/bin/myapp --arg1      # DAEMON + DAEMON_ARGS
PIDFile=/var/run/myapp.pid           # if Type=forking
User=myapp                           # if script runs as a specific user
Restart=on-failure                   # replaces external supervision
StandardOutput=journal               # replaces manual log redirection
StandardError=journal

[Install]
WantedBy=multi-user.target           # from Default-Start: 2 3 4 5
```

**Step 3: Enable and test**

```bash
systemctl daemon-reload
systemctl enable --now myapp.service
systemctl status myapp.service
journalctl -u myapp.service -f
```

**Step 4: Remove or disable the init script**

```bash
# On Debian/Ubuntu: remove SysV symlinks to avoid double-starting
update-rc.d myapp remove
# The unit file is now authoritative
```

---

## 16. Unit File Layout In Depth

### 16.1 File Locations and Override Precedence

```
/lib/systemd/system/nginx.service          ← package installs here
/etc/systemd/system/nginx.service          ← local full override (systemctl edit --full)
/etc/systemd/system/nginx.service.d/
├── 10-timeout.conf                        ← drop-in: override TimeoutSec
└── 20-restart.conf                        ← drop-in: override Restart policy
/run/systemd/system/nginx.service          ← runtime/transient (lost on reboot)
/run/systemd/generator/nginx.service       ← auto-generated from init script
```

Resolution order (highest wins): `/etc` → `/run` → `/lib`

Drop-ins in `.d/` directories are **merged** rather than replacing — only the specified directives are overridden.

### 16.2 Templated Units

A single unit file can instantiate multiple instances using the `@` syntax:

```
getty@.service          ← template
getty@tty1.service      ← instance (tty1 is the "instance specifier")
getty@tty2.service      ← instance
getty@tty3.service      ← instance
```

Inside the template, `%i` expands to the instance name:

```ini
# /lib/systemd/system/getty@.service
[Service]
ExecStart=-/sbin/agetty --autologin root --noclear %i $TERM
```

This is used for: getty terminals, network interfaces (`systemd-networkd@eth0`), container instances, per-user services.

### 16.3 The `[Unit]` Section — Full Reference

```ini
[Unit]
# Metadata
Description=Human-readable name
Documentation=man:nginx(8) https://nginx.org/en/docs/

# Ordering (does not imply dependency — see below)
After=network.target postgresql.service
Before=shutdown.target

# Hard dependencies
Requires=postgresql.service     # fail if dependency fails to start
Requisite=postgresql.service    # fail if dependency not already active
BindsTo=container@foo.service   # stop if dependency stops

# Soft dependencies
Wants=redis.service             # start alongside; ignore failure
Upholds=redis.service           # keep redis running while this runs

# Propagation
PartOf=app.target               # follow stop/restart from parent

# Conflicts
Conflicts=myapp-legacy.service  # cannot be active simultaneously

# Conditions (abort without error if false)
ConditionPathExists=/etc/myapp/config.yaml
ConditionFileNotEmpty=/etc/myapp/config.yaml
ConditionKernelVersion=>=5.10
ConditionVirtualization=!container   # don't run inside containers
ConditionHost=prod-server-01

# Assertions (abort with error if false)
AssertFileIsExecutable=/usr/bin/myapp

# Failure behaviour
OnFailure=notify-admin@%n.service   # trigger this on failure
OnSuccess=post-run.service

# Misc
DefaultDependencies=no   # disable implicit sysinit/shutdown deps (early boot only)
RefuseManualStart=yes    # can only be started by dependency, not manually
RefuseManualStop=yes     # can only be stopped by dependency
```

### 16.4 The `[Service]` Section — Full Reference

```ini
[Service]
# Process type
Type=simple|exec|forking|oneshot|notify|notify-reload|dbus|idle
RemainAfterExit=yes      # unit stays active after ExecStart exits (for oneshot)
PIDFile=/run/myapp.pid   # required for Type=forking
BusName=com.example.MyApp  # required for Type=dbus
NotifyAccess=main|exec|all  # which processes may send sd_notify

# Execution
ExecStart=/usr/bin/myapp arg1 arg2
ExecStartPre=/usr/bin/myapp --check-config
ExecStartPost=/usr/bin/post-start-hook.sh
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/usr/bin/myapp --shutdown
ExecStopPost=/usr/bin/post-stop-hook.sh

# Multiple ExecStart for oneshot (run in order)
ExecStart=/usr/bin/setup-step1.sh
ExecStart=/usr/bin/setup-step2.sh

# Environment
Environment=KEY=value KEY2=value2
EnvironmentFile=/etc/myapp/env
EnvironmentFile=-/etc/myapp/env.local    # - prefix = optional

# Identity
User=myapp
Group=myapp
SupplementaryGroups=audio docker
WorkingDirectory=/var/lib/myapp
RootDirectory=/opt/chroot             # chroot the service
UMask=0027

# Restart
Restart=no|always|on-success|on-failure|on-abnormal|on-abort|on-watchdog
RestartSec=5s
StartLimitIntervalSec=60s
StartLimitBurst=3
TimeoutStartSec=30s
TimeoutStopSec=30s
TimeoutSec=30s       # sets both start and stop
WatchdogSec=30s      # require sd_notify(WATCHDOG=1) this often

# Output
StandardInput=null|tty|socket|fd:name
StandardOutput=inherit|null|tty|journal|kmsg|journal+console|socket
StandardError=inherit|null|tty|journal|kmsg|journal+console|socket
SyslogIdentifier=myapp
SyslogFacility=daemon

# Limits (ulimit equivalents)
LimitNOFILE=65536          # max open file descriptors
LimitNPROC=512             # max processes
LimitMEMLOCK=infinity      # for databases that lock memory

# Security
NoNewPrivileges=yes
PrivateTmp=yes
PrivateNetwork=yes
PrivateDevices=yes
ProtectSystem=strict|full|yes
ProtectHome=yes|read-only|tmpfs
ReadWritePaths=/var/lib/myapp
ReadOnlyPaths=/etc/myapp
InaccessiblePaths=/etc/shadow /root
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
SystemCallFilter=@system-service
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes

# Resource control
CPUWeight=100
CPUQuota=50%
MemoryMax=512M
MemoryHigh=400M
TasksMax=128
IOWeight=100
```

### 16.5 The `[Install]` Section

```ini
[Install]
# Pulled in as Wants= by this target when unit is enabled
WantedBy=multi-user.target

# Pulled in as Requires= by this target
RequiredBy=emergency.target

# Symlink alias — enable creates /etc/systemd/system/alias.service → this file
Alias=alternative-name.service

# Also enable/disable these units
Also=myapp-helper.service myapp-logger.service
```

`systemctl enable` reads `[Install]` and creates symlinks in `.wants/` or `.requires/` directories. `systemctl disable` removes them. The unit itself is unchanged.

---

## 17. Migration Reference

### 17.1 Command Equivalents

| Task | SysV / Legacy | systemd |
|---|---|---|
| Start service | `service X start` | `systemctl start X` |
| Stop service | `service X stop` | `systemctl stop X` |
| Restart service | `service X restart` | `systemctl restart X` |
| Reload config | `service X reload` | `systemctl reload X` |
| Service status | `service X status` | `systemctl status X` |
| Enable at boot (Debian) | `update-rc.d X defaults` | `systemctl enable X` |
| Enable at boot (RHEL) | `chkconfig X on` | `systemctl enable X` |
| Disable at boot | `update-rc.d X disable` | `systemctl disable X` |
| List all services | `service --status-all` | `systemctl list-units --type=service` |
| List enabled | `chkconfig --list` | `systemctl list-unit-files --type=service` |
| Change runlevel | `telinit 3` | `systemctl isolate multi-user.target` |
| Default runlevel | Edit `/etc/inittab` | `systemctl set-default multi-user.target` |
| Reboot | `shutdown -r now` | `systemctl reboot` |
| Halt | `shutdown -h now` | `systemctl poweroff` |
| Read logs | `tail /var/log/syslog` | `journalctl -f` |
| Service logs | `grep myapp /var/log/syslog` | `journalctl -u myapp` |
| Boot logs | (unavailable) | `journalctl -b` |

### 17.2 Runlevel to Target Reference

| Old command | New command |
|---|---|
| `telinit 0` | `systemctl poweroff` |
| `telinit 1` | `systemctl rescue` |
| `telinit 3` | `systemctl isolate multi-user.target` |
| `telinit 5` | `systemctl isolate graphical.target` |
| `telinit 6` | `systemctl reboot` |
| `runlevel` | `systemctl list-units --type=target` |

### 17.3 Log Migration

| Old approach | systemd equivalent |
|---|---|
| `tail -f /var/log/syslog` | `journalctl -f` |
| `grep error /var/log/syslog` | `journalctl -p err` |
| `grep nginx /var/log/syslog` | `journalctl -u nginx` |
| `cat /var/log/kern.log` | `journalctl -k` |
| `grep "Jan 15" /var/log/syslog` | `journalctl --since 2024-01-15 --until 2024-01-16` |
| Last boot messages | `journalctl -b` |
| Previous boot messages | `journalctl -b -1` |

---

*All SysV examples reflect Debian/Ubuntu conventions. RHEL/CentOS SysV used `chkconfig` and `/etc/rc.d/` paths. systemd behaviour is identical across all distributions.*