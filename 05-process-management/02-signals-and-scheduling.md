# Signals and Scheduling

A reference guide to how Linux processes communicate via signals, how to send them safely, and how the kernel decides which process gets CPU time and when.

---

## 📡 What Signals Are

A **signal** is a limited, asynchronous notification sent to a process — essentially a software interrupt. Unlike normal program input, a process doesn't have to be "listening" for a signal; the kernel delivers it directly, interrupting whatever the process was doing.

Each signal has a **name** and a **number**, and a process can respond to most signals in one of three ways:

| Response | Meaning |
|---|---|
| **Default action** | The kernel's built-in behavior for that signal (often: terminate) |
| **Custom handler** | The program defines its own code to run when the signal arrives |
| **Ignore** | The program explicitly discards the signal and does nothing |

> **Important exception:** `SIGKILL` and `SIGSTOP` **cannot** be caught, blocked, or ignored — the kernel enforces these unconditionally, which is exactly why `SIGKILL` is the reliable last resort when a process won't respond to anything else.

```bash
kill -l    # list all signal names and numbers
```

---

## 📋 Common Signals

| Signal | Number | Default Action | Typical Use |
|---|---|---|---|
| `SIGHUP` | 1 | Terminate | Sent when a controlling terminal closes; often repurposed by daemons to mean "reload your config" |
| `SIGINT` | 2 | Terminate | What `Ctrl+C` sends — interrupt request |
| `SIGQUIT` | 3 | Terminate + core dump | What `Ctrl+\` sends |
| `SIGKILL` | 9 | Terminate | Unconditional, un-catchable force kill |
| `SIGTERM` | 15 | Terminate | The polite, catchable default for `kill` — "please stop" |
| `SIGSTOP` | 19 | Stop | Unconditional pause — same effect as `Ctrl+Z`'s `SIGTSTP`, but un-catchable |
| `SIGTSTP` | 20 | Stop | What `Ctrl+Z` sends — catchable suspend request |
| `SIGCONT` | 18 | Continue | Resume a stopped process |
| `SIGCHLD` | 17 | Ignore | Sent to a parent when a child process terminates |
| `SIGUSR1` / `SIGUSR2` | 10 / 12 | Terminate | Reserved for application-defined custom behavior |

### `SIGTERM` vs. `SIGKILL` — Why the Distinction Matters

- **`SIGTERM`** is a *request*. A well-behaved process catches it, closes open files, releases locks, flushes buffers, and exits cleanly. This is why it's the default signal for plain `kill`.
- **`SIGKILL`** is *not* a request — the process is terminated immediately by the kernel, with zero opportunity to clean up. For something like a database mid-write, this can mean corrupted data on disk.

> **Rule of thumb:** always try `SIGTERM` first. Only escalate to `SIGKILL` if the process ignores `SIGTERM` after a reasonable wait (a hung or misbehaving process, or one explicitly blocking the signal).

### `SIGHUP`'s Double Life

Historically, `SIGHUP` meant "your controlling terminal just disconnected." Many long-running daemons (like `nginx`, `sshd`, and others) have repurposed it as a convention for **"reload your configuration without fully restarting."**

```bash
sudo kill -HUP $(pgrep nginx)    # ask nginx to reload its config
```

This is why background jobs are protected from terminal-close signals using `nohup` (see the *Job Control* guide) — without it, closing the terminal sends `SIGHUP`, which by default terminates the job rather than "reloading" it (only daemons that specifically repurpose `SIGHUP` treat it as a reload signal).

---

## ☠️ Sending Signals: `kill`, `pkill`, `killall`

### `kill` — By PID or Job Number

```bash
kill 12345           # SIGTERM (default) to PID 12345
kill -9 12345        # SIGKILL by number
kill -KILL 12345     # SIGKILL by name
kill -HUP 12345      # SIGHUP, e.g. to reload a daemon's config
kill %1               # SIGTERM to job 1 (shell job-control syntax)
```

### `pkill` — By Name or Pattern

```bash
pkill nginx           # SIGTERM to all processes named "nginx"
pkill -9 -f "backup-script.sh"   # SIGKILL, matching the full command line
pkill -u alice         # signal all processes owned by user alice
```

| Flag | Meaning |
|---|---|
| `-f` | Match against the full command line, not just the process name |
| `-u user` | Restrict matches to processes owned by a specific user |
| `-9` / `-SIGNAL` | Specify which signal to send (default is `SIGTERM`) |

### `killall` — By Exact Name

```bash
killall sleep         # SIGTERM to every process literally named "sleep"
killall -9 firefox    # force-kill all processes named "firefox"
```

> ⚠️ **Caution:** `pkill -f` searches the entire command line, which can easily over-match. `pkill -f script` would match `run-script.sh`, `script-runner`, *and* anything else containing "script" anywhere in its invocation. Always sanity-check with `pgrep` (same matching logic, just lists PIDs instead of signaling them) before running `pkill`.

```bash
pgrep -f "backup-script.sh"   # preview what pkill -f would target
```

### Permission Rules for Signaling

A process can only send a signal to another process if:
- it's running as the **same user** as the target, or
- it's running as **root**, which can signal any process regardless of owner.

This is why killing another user's process requires `sudo`.

---

## ⚙️ CPU Scheduling Basics

Linux uses a **preemptive, priority-based scheduler** to share CPU time across all runnable processes. On a single CPU core, only one process can actually execute at any given instant — the scheduler rapidly switches between processes (a "context switch"), giving the illusion of simultaneous execution.

### The Default Scheduler: CFS

The **Completely Fair Scheduler (CFS)** is the default for normal processes on modern Linux. Rather than fixed time slices, CFS tracks how much CPU *time* each process has accumulated and always picks the process that's received the *least* CPU time so far relative to its priority — approximating an "ideal" system where every process gets a perfectly fair, simultaneous share of the CPU.

```bash
cat /proc/sys/kernel/sched_*   # various scheduler tunables (advanced)
```

> **Most users never need to touch the scheduler algorithm directly** — what's actually configurable day-to-day is each process's **priority**, via `nice`/`renice` below.

---

## 🎚️ Process Priority: `nice` and `renice`

### Nice Values

Every process has a **nice value** ranging from `-20` (highest priority) to `19` (lowest priority), with `0` as the default. The name is intentionally ironic: a *higher* nice value means the process is being "nicer" to others — yielding more CPU time to them — while a *lower* (more negative) value is *less* nice, demanding more CPU time for itself.

```
-20 ─────────────────────────────────── 0 ─────────────────────────────────── 19
(highest priority,                 (default)                    (lowest priority,
 least "nice")                                                     most "nice")
```

### Starting a Process with a Specific Priority: `nice`

```bash
nice -n 10 ./background-task.sh      # start with a lower priority (niceness 10)
nice -n -5 ./important-task.sh       # start with a higher priority (requires root for negative values)
```

> **Note:** Only **root** can set a *negative* nice value (raise priority above default) or lower the niceness of an already-running process below where it currently sits. Regular users can only make their own processes *nicer* (raise the nice value, lowering priority), not less nice.

### Changing an Already-Running Process's Priority: `renice`

```bash
renice -n 10 -p 12345          # set PID 12345's nice value to 10
sudo renice -n -5 -p 12345     # requires root for negative values
renice -n 5 -u alice            # apply to all of alice's processes
```

| Flag | Meaning |
|---|---|
| `-n` | The nice value to set |
| `-p` | Target a specific PID |
| `-u` | Target all processes owned by a user |
| `-g` | Target all processes in a process group |

### Viewing Current Priorities

```bash
ps -o pid,ni,cmd       # show nice values alongside processes
top                     # the "NI" column shows nice value live
```

> **When to use this:** lower the priority (`nice -n 10` or higher) for CPU-intensive background tasks — like a video encode or a large compile — that shouldn't compete with interactive work for responsiveness. Raise priority cautiously, and generally only for genuinely time-sensitive system tasks, since it comes at other processes' expense.

---

## 📊 Load Averages

The **load average** is a measure of how much demand there is for CPU time — roughly, the average number of processes that are either running or waiting to run.

```bash
uptime
#  10:42:01 up 4 days,  2:15,  3 users,  load average: 1.25, 0.98, 0.76
cat /proc/loadavg
```

The three numbers represent the average load over the last **1, 5, and 15 minutes**, respectively.

### Interpreting Load Average

A load average is most meaningful **relative to the number of CPU cores** available:

```bash
nproc    # number of CPU cores available
```

| Load vs. core count | Meaning |
|---|---|
| Load < core count | System has spare CPU capacity |
| Load ≈ core count | System is fully utilized, but not overloaded |
| Load > core count | More work is queued than the CPU(s) can handle right now — processes are waiting |

**Example:** a load average of `4.0` means very different things on a 2-core machine (heavily overloaded — twice the demand the CPU can serve) versus a 16-core machine (lightly loaded — plenty of spare capacity).

> **Note:** On Linux specifically (unlike some other Unix systems), load average also includes processes waiting on **disk I/O**, not just CPU — so a high load average can sometimes point to a storage bottleneck rather than a CPU one. Cross-check with a tool like `iostat` or `vmstat` if load is high but CPU usage (per `top`) looks low.

### Comparing the Three Numbers

- **Rising trend** (1-min > 5-min > 15-min): load is increasing — a spike just started.
- **Falling trend** (1-min < 5-min < 15-min): load is decreasing — a spike is resolving.
- **All similar**: load has been steady over the period shown.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| List all signals | `kill -l` |
| Send SIGTERM to a PID | `kill PID` |
| Send SIGKILL to a PID | `kill -9 PID` |
| Send a signal by name | `kill -HUP PID` |
| Send signal to a job number | `kill %N` |
| Signal by process name | `pkill name` |
| Signal by full command line | `pkill -f pattern` |
| Preview a pkill match | `pgrep -f pattern` |
| Start with custom priority | `nice -n 10 command` |
| Change a running process's priority | `renice -n 10 -p PID` |
| View nice values | `ps -o pid,ni,cmd` or `top` |
| View load average | `uptime` or `cat /proc/loadavg` |
| View core count | `nproc` |

---

## 💡 Best Practices

- Always attempt `SIGTERM` (plain `kill`) before `SIGKILL` — give processes the chance to exit cleanly, especially anything touching disk state.
- Use `pgrep` to preview matches before running `pkill` or `killall` — broad patterns can catch more processes than intended.
- Reach for `SIGHUP` to reload daemon configs (where supported) instead of fully restarting the service — it avoids dropping active connections on services designed to support it.
- Use `nice` for CPU-heavy background tasks (encoding, compiling, batch jobs) so they don't starve interactive processes of responsiveness.
- Interpret load average relative to `nproc`, not as an absolute number — a "high" load on a 32-core server may be nothing to worry about.
- If load average is high but `top` shows low CPU usage, check disk I/O (`iostat`, `vmstat`) — Linux load average includes I/O-blocked processes, not just CPU-bound ones.
- Remember permission rules: you can only signal your own processes unless you're root — plan `sudo` usage accordingly when managing services or other users' processes.