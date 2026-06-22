# Process Lifecycle

A reference guide to how Linux creates, runs, and terminates processes — the fork/exec/wait model, parent-child relationships, process ownership, and how PID namespaces isolate process trees.

---

## 🧬 What a Process Is

A process is a running instance of a program — code, memory, open file handles, and execution state, all tracked by the kernel under a unique **Process ID (PID)**.

```bash
ps aux | head
ps -ef | head
```

Every process (except the very first) has exactly one **parent process** that created it, forming a tree structure rooted at PID `1`.

```bash
pstree
# systemd─┬─sshd───bash───ps
#         ├─cron
#         └─nginx─┬─nginx
#                  └─nginx
```

---

## 🍴 `fork()` — Creating a New Process

In Linux, you cannot create a process "from scratch" with arbitrary code — you always start by **duplicating an existing one**. The `fork()` system call does exactly that: it creates a near-identical copy of the calling process.

### What Happens on `fork()`

- A new process (the **child**) is created with a new PID.
- The child gets a copy of the parent's memory, open file descriptors, and execution state — effectively, the program continues running in *two* places at once.
- Both parent and child resume execution **immediately after** the `fork()` call, each in its own process.
- The only difference between them at that point is the **return value** of `fork()`: the parent receives the child's PID; the child receives `0`.

```c
pid_t pid = fork();
if (pid == 0) {
    // this branch runs in the CHILD
} else {
    // this branch runs in the PARENT; pid holds the child's PID
}
```

### Copy-on-Write: Why `fork()` Is Cheap

Duplicating a process's entire memory space on every `fork()` would be expensive. Modern Linux uses **copy-on-write (COW)**: parent and child initially *share* the same physical memory pages, marked read-only. Only when either process tries to *write* to a page does the kernel actually copy it. This makes `fork()` fast even for processes with large memory footprints, since most forked processes immediately replace their memory anyway (see `exec()` below).

---

## ⚙️ `exec()` — Replacing a Process's Program

`fork()` alone only gives you a duplicate of the *same* program. To actually run a *different* program, the child typically calls one of the `exec()` family of functions (`execve`, `execvp`, `execl`, etc.).

### What Happens on `exec()`

- The calling process's memory, code, and data are **entirely replaced** by a new program.
- The **PID stays the same** — `exec()` doesn't create a new process, it transforms the current one.
- If `exec()` succeeds, it **never returns** — execution jumps straight into the new program's entry point.

### The Classic Pattern: `fork()` + `exec()`

This is how virtually every command you run from a shell actually gets started:

```
shell calls fork()
   │
   ├── PARENT (shell) ─── continues running, waits for child
   │
   └── CHILD ─── calls exec("/bin/ls") ─── becomes `ls`, runs, then exits
```

```c
pid_t pid = fork();
if (pid == 0) {
    execvp("ls", (char *[]){"ls", "-l", NULL});   // child becomes `ls`
} else {
    wait(NULL);                                    // parent waits for child to finish
}
```

This two-step dance exists because it cleanly separates two different needs: duplicating the *process* (so you have a new PID, new resources to manage) versus loading new *program code*. Combining them into one step would make features like shell redirection and pipe setup — which happen in the child **between** `fork()` and `exec()` — much harder to implement.

---

## ⏳ `wait()` — Reaping Child Processes

When a child process finishes, it doesn't vanish immediately. It becomes a **zombie** (see below) until its parent collects its exit status using `wait()` or `waitpid()`.

```c
int status;
pid_t finished_pid = wait(&status);   // blocks until any child exits
```

```c
waitpid(child_pid, &status, 0);       // blocks until THIS specific child exits
```

### Why `wait()` Matters

- It lets the parent retrieve the child's **exit status** (success/failure code).
- It allows the kernel to **fully release** the child's process table entry — without it, the entry lingers as a zombie.
- A shell, for example, uses `wait()` to know when a foreground command has finished before returning control to the user for the next prompt.

---

## 👻 Zombie and Orphan Processes

### Zombie Processes

A **zombie** (`Z` state in `ps`) is a process that has finished executing but still has an entry in the process table because its parent hasn't called `wait()` yet. It consumes no CPU or memory beyond that table entry, but a large accumulation of zombies can exhaust the system's process table.

```bash
ps aux | grep ' Z '
```

> **Fix:** Zombies can't be killed directly (they're already dead) — the only real cure is for the **parent** to call `wait()`, or for the parent itself to terminate (after which `init`/`systemd` adopts and reaps the zombie automatically).

### Orphan Processes

An **orphan** is a process whose parent has terminated *before* it did. Linux handles this automatically: orphaned processes are **re-parented** to PID `1` (`init` or `systemd`), which will reap them properly when they eventually exit.

```bash
ps -o pid,ppid,cmd -p <PID>   # check a process's current parent
```

---

## 👪 Parent and Child Process Relationships

### Key Identifiers

| Term | Meaning |
|---|---|
| **PID** | Process ID — unique identifier for the process |
| **PPID** | Parent Process ID — PID of the process that created it |
| **PGID** | Process Group ID — used for signal delivery to groups of related processes (e.g. a pipeline) |
| **SID** | Session ID — groups processes under a controlling terminal/login session |

```bash
ps -o pid,ppid,pgid,sid,cmd
```

### Inherited Properties

When a process forks, the child inherits several things from the parent by default, including:

- **UID/GID** (effective user and group ownership — see *Ownership* and *User Account Basics* guides)
- Open file descriptors
- Environment variables
- Current working directory
- Signal handling dispositions (mostly)

> **Why this matters for security:** Because children inherit the parent's UID/GID, a process running as root that forks/execs an untrusted program will run that program *as root* too, unless it explicitly drops privileges first (e.g. with `setuid()`/`setgid()` calls) before the `exec()`. This is a common source of privilege-escalation bugs in poorly written setuid programs (see the *Special Permissions* guide).

---

## 🧭 Process Ownership and Signals

Every process has an owning user (its **effective UID**), which determines what it's permitted to do — including who can send it signals.

```bash
kill -TERM 1234         # ask process 1234 to terminate gracefully
kill -KILL 1234         # force-terminate immediately (cannot be caught/ignored)
kill -9 1234             # same as -KILL, by signal number
killall nginx            # send a signal to all processes matching a name
```

In general, **a process can only send signals to processes owned by the same user** — unless the sender is root, which can signal any process. This is why you need `sudo` to kill another user's process.

```bash
kill -l        # list all available signal names/numbers
```

| Signal | Number | Meaning |
|---|---|---|
| `SIGHUP` | 1 | Hangup — often used to tell daemons to reload config |
| `SIGINT` | 2 | Interrupt — what `Ctrl+C` sends |
| `SIGKILL` | 9 | Force kill — cannot be caught, blocked, or ignored |
| `SIGTERM` | 15 | Graceful termination request — the polite default for `kill` |
| `SIGSTOP` | 19 | Pause the process |
| `SIGCONT` | 18 | Resume a stopped process |

> **Tip:** Always try `SIGTERM` (the default) before reaching for `SIGKILL`. `SIGTERM` gives a process the chance to clean up — closing files, releasing locks, flushing buffers — while `SIGKILL` terminates it instantly with no cleanup at all, which can leave corrupted state behind (e.g. for databases).

---

## 🪪 PID Namespaces

A **PID namespace** is a kernel feature that gives a group of processes their own isolated view of the process tree — the foundation of containerization technologies like Docker and LXC.

### How It Works

- Inside a new PID namespace, the first process created becomes **PID 1** *within that namespace* — even though it has a different, "real" PID on the host system.
- Processes inside the namespace **cannot see or signal** processes outside it.
- Processes outside the namespace (on the host) *can* see processes inside it, but with their host-assigned PIDs — meaning the same process effectively has two different PIDs depending on which namespace you're viewing it from.

```bash
# Inside a container, the main process appears as PID 1:
docker exec mycontainer ps aux
# PID   USER   COMMAND
# 1     root   node server.js

# From the host, the same process has a different, "real" PID:
ps aux | grep node
# 48213  root   node server.js
```

### Why This Matters

- **Isolation:** A process inside a container can't see, signal, or interfere with processes in other containers or on the host — even though they're all just regular Linux processes under the hood.
- **PID 1 responsibilities:** Just like real PID 1 (`init`/`systemd`) on a full system, the PID-1 process *inside* a namespace is responsible for reaping zombie children within that namespace. This is a frequent source of bugs in containers — many container images run an application directly as PID 1 without it being designed to reap zombies, leading to zombie accumulation inside the container over time. (This is why tools like `tini` or `dumb-init` exist — to provide a minimal, correct PID-1 process inside containers.)

```bash
lsns -t pid          # list PID namespaces on the system
ls -la /proc/<PID>/ns/pid   # inspect which namespace a process belongs to
```

---

## 🌳 Inspecting the Process Tree

```bash
pstree -p              # show the full tree, with PIDs
pstree -p $$            # show the tree starting from your current shell
ps -ef --forest         # alternative tree view via ps
ps -o pid,ppid,cmd -p 1234   # show one process's PID/PPID directly
```

```bash
top      # live, interactive view of running processes
htop     # friendlier, color interactive alternative (if installed)
```

---

## ⚡ Quick Reference

| Concept | Key Idea |
|---|---|
| `fork()` | Duplicates the calling process; both continue running independently |
| `exec()` | Replaces the current process's code with a new program; PID unchanged |
| `wait()` | Parent retrieves child's exit status; releases the process table entry |
| Zombie | Child has exited but parent hasn't called `wait()` yet |
| Orphan | Parent exited first; child is re-parented to PID 1 |
| PPID | The PID of a process's parent |
| PID namespace | Isolated view of the process tree, used by containers |

| Task | Command |
|---|---|
| View all processes | `ps aux` or `ps -ef` |
| View process tree | `pstree -p` |
| View one process's parent | `ps -o pid,ppid,cmd -p PID` |
| Send graceful termination | `kill -TERM PID` or `kill PID` |
| Force kill | `kill -9 PID` or `kill -KILL PID` |
| Kill by process name | `killall name` |
| List PID namespaces | `lsns -t pid` |
| Live process monitor | `top` or `htop` |

---

## 💡 Best Practices

- Always attempt `SIGTERM` before `SIGKILL` — give processes the chance to clean up gracefully, especially anything managing files, databases, or network connections.
- Watch for zombie accumulation (`ps aux | grep ' Z '`) on long-running systems — it usually points to a parent process that isn't calling `wait()` properly.
- When writing or choosing container entrypoints, use an init-style wrapper (`tini`, `dumb-init`) rather than running your application directly as PID 1, to avoid zombie buildup inside the container.
- Remember that forked children inherit the parent's UID/GID — be deliberate about dropping privileges before `exec()`-ing untrusted code from a privileged process.
- Use `pstree -p` over plain `ps` when you need to understand *relationships* between processes, not just a flat list.
- Treat PID numbers as namespace-relative — the same process can have different PIDs depending on whether you're looking from inside a container or from the host.