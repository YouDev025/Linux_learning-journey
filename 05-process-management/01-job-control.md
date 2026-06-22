# Job Control

A reference guide to managing foreground and background jobs from the shell — suspending, resuming, signaling, and keeping processes alive beyond your session.

---

## 🧩 What a "Job" Is

A **job** is the shell's term for a process (or pipeline of processes) that it started and is tracking — distinct from a process's PID, a job has its own **job number**, scoped to that shell session.

Every job is in one of three states:

| State | Meaning |
|---|---|
| **Foreground** | Connected to the terminal; you can type input to it; the shell waits for it to finish |
| **Background** | Running, but detached from terminal input; the shell prompt is immediately available |
| **Stopped** | Suspended — not running at all, but not terminated either; can be resumed later |

---

## ▶️ Starting Jobs in the Background

Append `&` to a command to launch it directly in the background:

```bash
long-running-task &
# [1] 12345
```

The shell prints the **job number** (`[1]`) and the **PID** (`12345`), then immediately returns your prompt.

```bash
sleep 300 &
./backup-script.sh &
npm run dev &
```

---

## 📋 `jobs` — Listing Active Jobs

```bash
jobs
# [1]   Running                 sleep 300 &
# [2]-  Stopped                 vim notes.txt
# [3]+  Running                 ./backup-script.sh &
```

```bash
jobs -l    # also show PIDs
jobs -r    # show only running jobs
jobs -s    # show only stopped jobs
```

### Reading the Job Markers

| Marker | Meaning |
|---|---|
| `+` | The **current** job — what `fg`/`bg` will act on if you don't specify a number |
| `-` | The **previous** job — what becomes current if the `+` job ends |
| *(none)* | Any other job |

---

## ⏸️ Suspending the Foreground Job: `Ctrl+Z`

Pressing `Ctrl+Z` while a foreground process is running sends it `SIGTSTP`, **suspending** it (not terminating it) and returning control to the shell immediately.

```bash
$ vim notes.txt
# (press Ctrl+Z)
[1]+  Stopped                 vim notes.txt
$
```

The process is now stopped — frozen in place, consuming no CPU, but still fully intact in memory and resumable at any time.

> **Common workflow:** suspend a long interactive task with `Ctrl+Z` to quickly run another command, then resume it afterward with `fg`.

---

## ▶️ `fg` — Resume in the Foreground

Brings a background or stopped job back to the foreground, reconnecting it to terminal input and making the shell wait for it again.

```bash
fg            # resume the current ("+") job
fg %1         # resume job number 1 specifically
fg %backup    # resume by matching the start of the command name
```

If the job was stopped, `fg` sends it `SIGCONT` first to resume execution, then brings it to the foreground.

---

## ⏯️ `bg` — Resume in the Background

Resumes a **stopped** job, but keeps it in the background instead of reconnecting it to the terminal.

```bash
bg            # resume the current ("+") job in the background
bg %2         # resume job number 2 specifically
```

```bash
$ vim notes.txt
# Ctrl+Z to stop it
[1]+  Stopped                 vim notes.txt
$ bg %1
[1]+ vim notes.txt &
```

> **Note:** `bg` doesn't make sense for an interactive program like `vim` (it needs terminal input to do anything useful) — it's most useful for non-interactive long-running tasks you suspended by mistake, or want to send to the background after starting in the foreground.

---

## 🛑 Signals from the Keyboard

| Keystroke | Signal | Effect |
|---|---|---|
| `Ctrl+C` | `SIGINT` | Interrupt — politely asks the foreground process to stop; most programs exit cleanly |
| `Ctrl+Z` | `SIGTSTP` | Suspend — pauses the foreground process, returns it to "Stopped" |
| `Ctrl+\` | `SIGQUIT` | Quit — like `Ctrl+C`, but also requests a core dump; rarely needed |
| `Ctrl+D` | *(EOF, not a signal)* | Signals "end of input" to the current program — often exits a shell or REPL |

> **Tip:** `Ctrl+C` and `Ctrl+Z` are easy to confuse. `Ctrl+C` *terminates* (the process ends and is gone). `Ctrl+Z` *suspends* (the process is paused, intact, and resumable with `fg`/`bg`). If you meant to stop something temporarily but it disappeared, you likely hit `Ctrl+C` by reflex.

---

## ☠️ `kill` — Sending Signals Directly

`kill` despite its name, sends *any* signal, not just termination — `Ctrl+C` and `Ctrl+Z` are really just convenient shortcuts for signals you can also send manually.

```bash
kill 12345           # send SIGTERM (15) to PID 12345 — graceful request to stop
kill -9 12345        # send SIGKILL — force-terminate, no cleanup, cannot be ignored
kill -STOP 12345     # send SIGSTOP — same effect as Ctrl+Z, but by PID
kill -CONT 12345     # send SIGCONT — resume a stopped process, same effect as bg/fg
```

### Targeting Jobs Instead of PIDs

`kill` also accepts job-number syntax directly, so you don't need to look up the PID:

```bash
kill %1              # send SIGTERM to job 1
kill -9 %2           # force-kill job 2
```

### Killing by Name

```bash
pkill -f backup-script    # kill processes matching a pattern
killall sleep              # kill all processes named "sleep"
```

> ⚠️ **Caution:** `pkill`/`killall` match by process name or pattern, which can be broader than intended — double-check the pattern (`pkill -f` in particular searches the full command line) before running it, especially as root.

---

## 🏃 Keeping Processes Alive Beyond the Session: `nohup`

By default, when you close a terminal or log out, the shell sends `SIGHUP` ("hangup") to its background jobs, which typically terminates them. `nohup` makes a command **ignore** `SIGHUP`, so it survives even after you disconnect.

```bash
nohup ./long-running-task.sh &
# output, if not redirected, goes to nohup.out by default
```

```bash
nohup ./backup.sh > backup.log 2>&1 &    # explicitly redirect output instead of using nohup.out
```

### Limitations of `nohup`

- It only protects against `SIGHUP` — a `kill -9` or system shutdown still terminates the process.
- It's a "fire and forget" tool: you can't easily reattach to see live output or send input once it's running, beyond reading the log file.
- It doesn't help if you want to **reconnect** to an interactive session later (e.g. to check progress on a multi-step task) — for that, you want a terminal multiplexer.

---

## 🖥️ Persistent Sessions: `screen` and `tmux`

Both `screen` and `tmux` create a session that **keeps running on the server** even after you disconnect — and crucially, lets you **reattach** to it later and pick up exactly where you left off, including all terminal output.

### `tmux` (more modern, generally recommended)

```bash
tmux new -s mywork          # start a new named session
# ... work normally inside ...
# detach: Ctrl+b then d       (returns to your normal shell, session keeps running)

tmux ls                      # list active sessions
tmux attach -t mywork        # reattach to a named session
tmux kill-session -t mywork  # terminate a session entirely
```

| Key Combo (after `Ctrl+b`) | Action |
|---|---|
| `d` | Detach from the session |
| `c` | Create a new window |
| `n` / `p` | Next / previous window |
| `%` | Split pane vertically |
| `"` | Split pane horizontally |

### `screen` (older, still widely available)

```bash
screen -S mywork             # start a new named session
# detach: Ctrl+a then d

screen -ls                    # list active sessions
screen -r mywork               # reattach to a named session
```

### `nohup` vs. `tmux`/`screen`

| | `nohup` | `tmux` / `screen` |
|---|---|---|
| Survives terminal close | ✅ | ✅ |
| Can reattach and view live output | ❌ | ✅ |
| Can send input after detaching/reconnecting | ❌ | ✅ |
| Good for | One-shot scripts, cron-like tasks | Long interactive work, monitoring, multi-step sessions |

> **Tip:** Use `nohup` for a script you just want to run and check on later via a log file. Use `tmux`/`screen` for anything you might want to *come back to and interact with* — like a long SSH-based build, a database migration you're watching step-by-step, or a development environment you want to leave running across reconnects.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Start a job in the background | `command &` |
| List active jobs | `jobs` |
| List jobs with PIDs | `jobs -l` |
| Suspend the foreground job | `Ctrl+Z` |
| Resume in foreground | `fg` or `fg %N` |
| Resume in background | `bg` or `bg %N` |
| Interrupt (terminate) foreground job | `Ctrl+C` |
| Send SIGTERM to a PID | `kill PID` |
| Send SIGTERM to a job | `kill %N` |
| Force kill | `kill -9 PID` |
| Kill by name/pattern | `pkill -f pattern` or `killall name` |
| Run immune to terminal hangup | `nohup command &` |
| Start a persistent session | `tmux new -s name` or `screen -S name` |
| Detach from tmux / reattach | `Ctrl+b d` / `tmux attach -t name` |
| Detach from screen / reattach | `Ctrl+a d` / `screen -r name` |

---

## 💡 Best Practices

- Use `Ctrl+Z` + `bg` when you start something in the foreground by mistake and want to free up the terminal, rather than killing and restarting it.
- Prefer `kill` (plain `SIGTERM`) before `kill -9` — give processes a chance to clean up; reserve `-9` for processes that won't respond to a graceful request.
- Always double-check the pattern passed to `pkill -f` or `killall` before running it — these can match more processes than intended.
- Use `nohup` for simple, non-interactive long-running scripts where you only need the end result or a log file.
- Use `tmux` or `screen` instead of `nohup` for anything you'll want to reattach to and interact with — especially over SSH connections prone to dropping.
- Name your `tmux`/`screen` sessions (`-s name`) rather than relying on default numbering — it makes reattaching after a disconnect far less error-prone.
- Remember that closing a terminal sends `SIGHUP` to background jobs by default — if a background task unexpectedly dies after you disconnect, this is almost always why.