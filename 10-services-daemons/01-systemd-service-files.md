# systemd Service Files

A reference guide to writing and managing systemd unit files — the `[Unit]`, `[Service]`, and `[Install]` sections, system vs. user services, and how to safely test and reload changes.

---

## 🧱 What a Unit File Is

A **unit file** is a plain-text configuration file describing something systemd manages — most commonly a service, but also targets, timers, sockets, and mounts. This guide focuses on `.service` units, which describe a single managed process (or set of related processes).

### Where Unit Files Live

| Location | Purpose |
|---|---|
| `/usr/lib/systemd/system/` (or `/lib/systemd/system/`) | Unit files installed by packages — don't edit these directly |
| `/etc/systemd/system/` | Custom/admin-defined unit files, and overrides — this is where YOUR units go |
| `~/.config/systemd/user/` | User-level units (see *User Services* below) |

```bash
systemctl cat nginx.service        # show the actual unit file content systemd is using, wherever it lives
systemctl list-unit-files --type=service    # list all known unit files
```

> **Tip:** Never edit files in `/usr/lib/systemd/system/` directly — package upgrades will overwrite your changes without warning. Create a new file in `/etc/systemd/system/`, or use an override (see below), instead.

---

## 📄 Anatomy of a Service Unit File

A minimal but complete example:

```ini
[Unit]
Description=My Custom Backup Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/scripts/backup.sh
User=backup
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo nano /etc/systemd/system/mybackup.service
```

---

## 🔷 The `[Unit]` Section

Describes **metadata and dependency ordering** — what this unit is, and how it relates to other units.

```ini
[Unit]
Description=My Custom Backup Service
Documentation=https://example.com/docs/backup
After=network.target postgresql.service
Requires=postgresql.service
Wants=some-optional-service.service
Conflicts=other-backup-tool.service
```

| Directive | Meaning |
|---|---|
| `Description` | Human-readable summary, shown in `systemctl status` |
| `Documentation` | URL(s) to relevant docs |
| `After` | Start this unit AFTER the listed units (ordering only — doesn't imply a hard dependency) |
| `Before` | Start this unit BEFORE the listed units |
| `Requires` | A HARD dependency — if the listed unit fails/stops, this unit is stopped too |
| `Wants` | A SOFT dependency — pulls in the listed unit if available, but doesn't fail if it's missing |
| `Conflicts` | Cannot run at the same time as the listed unit(s) — starting this one stops those |

### `After`/`Before` vs. `Requires`/`Wants`: A Critical Distinction

This is one of the most commonly confused pairs in systemd configuration:

```
After=network.target        ← ORDERING only: "start after network is up," but doesn't
                                require network.target to succeed or even exist

Requires=postgresql.service   ← DEPENDENCY: "I genuinely need this to function" — if it's
                                 not running, systemd won't consider this unit properly started
```

> **Common mistake:** specifying only `After=` without `Requires=`/`Wants=` when a service genuinely cannot function without the other. `After=` alone only controls *order*, not whether the dependency actually started successfully — a service can come up "after" a failed dependency and just... fail at runtime, with the ordering directive having done nothing to prevent that.

> **Best practice combo:** for a genuine hard dependency, specify both together:
> ```ini
> Requires=postgresql.service
> After=postgresql.service
> ```
> `Requires` alone doesn't guarantee *order* — without `After`, both could start in parallel, defeating the purpose.

---

## 🔷 The `[Service]` Section

Describes **how to actually run the process** — the core of the unit file for a `.service` type unit.

```ini
[Service]
Type=simple
ExecStart=/opt/scripts/backup.sh
ExecStartPre=/opt/scripts/check-disk-space.sh
ExecStop=/opt/scripts/cleanup.sh
ExecReload=/bin/kill -HUP $MAINPID
User=backup
Group=backup
WorkingDirectory=/opt/backup
Environment=LOG_LEVEL=info
EnvironmentFile=/etc/backup/backup.env
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
```

### `Type=` — How systemd Should Treat the Main Process

| Type | Meaning |
|---|---|
| `simple` (default) | The process started by `ExecStart` IS the main process — runs in the foreground, stays running |
| `forking` | The process forks and the PARENT exits; systemd tracks the resulting CHILD as the real service (common for older-style daemons that self-daemonize) |
| `oneshot` | The process is expected to run once and EXIT — useful for setup tasks, not long-running services |
| `notify` | The process tells systemd it's ready via a special protocol (`sd_notify`), rather than systemd just assuming readiness on launch |
| `idle` | Like `simple`, but delays actually starting until other jobs have finished — mostly cosmetic, for cleaner boot output |

> **Tip:** `simple` is correct for the vast majority of custom services — a script or program that runs continuously in the foreground without forking or backgrounding itself. Reach for `forking` only when wrapping an older daemon that explicitly double-forks itself; reach for `oneshot` for genuine run-once setup tasks.

### Key `ExecStart`-Family Directives

| Directive | Runs |
|---|---|
| `ExecStartPre` | Before the main process starts — e.g. validation, setup |
| `ExecStart` | The main process itself |
| `ExecStartPost` | After the main process has started successfully |
| `ExecStop` | When stopping the service — explicit cleanup, if needed beyond just signaling |
| `ExecReload` | On `systemctl reload` — typically sends a signal like `SIGHUP` rather than fully restarting (see the *Signals and Scheduling* guide) |

> **Note:** `ExecStop` is often unnecessary — by default, systemd will send `SIGTERM` (then `SIGKILL` after a timeout) to the main process automatically when stopping. Only define `ExecStop` explicitly if cleanup needs to happen beyond what a plain signal accomplishes.

### Restart Behavior

```ini
Restart=on-failure       # restart only if it exits with a non-zero/error status
RestartSec=5               # wait 5 seconds before each restart attempt
StartLimitIntervalSec=60     # within this window...
StartLimitBurst=3              # ...allow at most this many restart attempts before giving up
```

| `Restart=` value | Meaning |
|---|---|
| `no` (default) | Never restart automatically |
| `on-success` | Restart only on a CLEAN exit (exit code 0) |
| `on-failure` | Restart on a non-zero exit, signal, or timeout — the common choice for most services |
| `on-abnormal` | Restart on a signal, timeout, or watchdog failure — but NOT a clean non-zero exit |
| `always` | Restart unconditionally, regardless of how it exited |

> **Tip:** `on-failure` is the right default for most real services — it recovers automatically from crashes without endlessly restart-looping something that's exiting cleanly and intentionally (e.g. a `oneshot`-style task that's genuinely done).

### Running as a Dedicated User

```ini
User=backup
Group=backup
```

Connects directly to the principle of least privilege covered in the *User Account Basics* guide — a service should run as a dedicated, limited-privilege account rather than root, unless it genuinely needs root-level access for its function.

### Environment Variables

```ini
Environment=LOG_LEVEL=info
Environment=API_TIMEOUT=30
EnvironmentFile=/etc/backup/backup.env       # load MULTIPLE variables from a separate file
```

```bash
# /etc/backup/backup.env
LOG_LEVEL=info
API_KEY=abc123
```

> **Tip:** Use `EnvironmentFile` (with restrictive permissions — see the *Permissions* guide) for secrets, rather than putting sensitive values directly in the unit file itself, since unit files in `/etc/systemd/system/` are often more broadly readable than a dedicated, tightly-permissioned secrets file.

---

## 🔷 The `[Install]` Section

Describes how the unit integrates with `systemctl enable`/`disable` — specifically, what target(s) "pull it in" automatically at boot.

```ini
[Install]
WantedBy=multi-user.target
```

| Directive | Meaning |
|---|---|
| `WantedBy` | When enabled, creates a symlink so this unit starts when the LISTED target is reached — `multi-user.target` (normal, non-graphical multi-user boot) is the standard choice for most services |
| `RequiredBy` | Like `WantedBy`, but a HARD dependency from the target's perspective |
| `Alias` | Additional name(s) this unit can also be referred to by |

> **Note:** The `[Install]` section only matters for `systemctl enable`/`disable` — it has no effect on `systemctl start`/`stop`, which work regardless of whether `[Install]` is even present.

---

## ✅ Creating and Testing a New Service

### Step-by-Step Workflow

```bash
# 1. Create the unit file
sudo nano /etc/systemd/system/mybackup.service

# 2. Tell systemd to re-read unit files from disk (REQUIRED after creating/editing any unit file)
sudo systemctl daemon-reload

# 3. Start it and watch for immediate problems
sudo systemctl start mybackup
sudo systemctl status mybackup

# 4. Check logs if anything looks wrong
journalctl -u mybackup -n 50

# 5. Once confirmed working, enable it to persist across reboots
sudo systemctl enable mybackup
```

> ⚠️ **Critical step often forgotten:** `systemctl daemon-reload` is **required** after creating a new unit file or editing an existing one — systemd caches unit file content, and skipping this step means your changes are silently ignored, with systemd continuing to act on the old (or nonexistent) definition.

### Validating Syntax Before Starting

```bash
systemd-analyze verify /etc/systemd/system/mybackup.service
```

This checks the unit file for structural problems (missing required directives, invalid syntax) without actually starting anything — a useful safety check before `daemon-reload` + `start`, especially on a unit you're not fully confident about yet.

### Common Troubleshooting Commands

```bash
systemctl status mybackup           # current state, recent log lines, and exit code if failed
journalctl -u mybackup -e             # jump to the END of this service's logs
journalctl -u mybackup --since today    # logs from today only
systemctl show mybackup               # dump EVERY effective property/setting for the unit, including inherited defaults
```

---

## 👤 User Services vs. System Services

### System Services

Run by the **system instance** of systemd (PID 1), typically as root or a dedicated service account, available regardless of whether any particular user is logged in — appropriate for anything that should be available system-wide (web servers, databases, system daemons).

```bash
sudo systemctl start myservice          # always needs sudo for system-level units
```

### User Services

Run by a **per-user instance** of systemd, started when that user logs in (or, with `loginctl enable-linger`, even without an active login session) — appropriate for things scoped to one specific user (a personal sync tool, a development environment, a notification daemon).

```bash
mkdir -p ~/.config/systemd/user/
nano ~/.config/systemd/user/mysync.service
```

```ini
[Unit]
Description=My Personal Sync Tool

[Service]
ExecStart=/home/alice/scripts/sync.sh
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload          # note: NO sudo for user services
systemctl --user start mysync
systemctl --user enable mysync
journalctl --user -u mysync
```

### Keeping a User Service Running Without an Active Login

By default, a user service stops when that user fully logs out. To keep it running independent of login sessions:

```bash
loginctl enable-linger alice      # requires root, run ONCE per user who needs this
```

### Comparison

| | System service | User service |
|---|---|---|
| Managed by | System systemd instance (PID 1) | Per-user systemd instance |
| Command prefix | `sudo systemctl ...` | `systemctl --user ...` (no sudo) |
| Unit file location | `/etc/systemd/system/` | `~/.config/systemd/user/` |
| Runs without login | Yes, always | Only with `loginctl enable-linger` |
| Appropriate for | System-wide services (web servers, databases) | Per-user tools (sync clients, personal automation) |

---

## 🔧 Overriding an Existing Unit File (Without Editing the Original)

Rather than copying and modifying a package-provided unit file directly (which gets overwritten on upgrade), systemd supports **drop-in overrides** that layer additional/changed settings on top of the original.

```bash
sudo systemctl edit nginx.service
```

This opens an editor for a small override file (automatically created at `/etc/systemd/system/nginx.service.d/override.conf`) — you only need to specify the directives you want to **change**, not the entire original file:

```ini
[Service]
Restart=always
RestartSec=10
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx
```

```bash
systemctl cat nginx.service          # shows the ORIGINAL plus your override, merged together
```

> **Tip:** Always prefer `systemctl edit` over directly modifying a package-installed unit file — overrides survive package upgrades, since they live in a separate file the package manager doesn't touch.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Reload unit file definitions after editing | `sudo systemctl daemon-reload` |
| Validate a unit file's syntax | `systemd-analyze verify file.service` |
| Show the effective unit file content | `systemctl cat name.service` |
| Show all effective properties | `systemctl show name.service` |
| Create a safe override for an existing unit | `sudo systemctl edit name.service` |
| Start/stop a system service | `sudo systemctl start/stop name` |
| Start/stop a user service | `systemctl --user start/stop name` |
| Enable a service at boot | `sudo systemctl enable name` |
| Keep user services running without login | `loginctl enable-linger username` |
| View a service's logs | `journalctl -u name` |

---

## 💡 Best Practices

- Always run `systemctl daemon-reload` after creating or editing a unit file — forgetting this is one of the most common "why isn't my change taking effect" issues.
- Pair `Requires=` with a matching `After=` for genuine hard dependencies — `Requires=` alone doesn't guarantee start order, and `After=` alone doesn't guarantee the dependency actually succeeded.
- Use `Restart=on-failure` rather than `Restart=always` for most services — it avoids endless restart loops for services that exit cleanly and intentionally.
- Run services as a dedicated, limited-privilege user (`User=`/`Group=`) rather than root, unless the service genuinely requires elevated access.
- Use `EnvironmentFile=` with tight permissions for secrets, rather than embedding them directly in a unit file that may be more broadly readable.
- Use `systemctl edit` (drop-in overrides) instead of directly modifying package-provided unit files — overrides survive package upgrades; direct edits don't.
- Validate with `systemd-analyze verify` before relying on a new unit file, especially for anything complex or going into a production environment.
- For per-user tooling that should survive logout, remember `loginctl enable-linger` is required — without it, the service stops the moment that user's session ends.