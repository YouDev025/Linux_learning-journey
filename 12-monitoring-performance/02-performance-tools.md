# Performance Tools

A reference guide to the command-line tools for measuring Linux performance and finding bottlenecks — `top`/`htop`/`iotop` for live views, `vmstat`/`sar`/`dstat` for trend data, and a structured approach to CPU, memory, disk, and network analysis.

---

## 🧭 A Methodology Before the Tools

Reaching for tools without a structure tends to produce a pile of numbers without a conclusion. A useful starting discipline, adapted from Brendan Gregg's widely-used **USE Method**, is to check each resource (CPU, memory, disk, network) for three things:

| Check | Question |
|---|---|
| **Utilization** | How busy is this resource? (e.g. CPU % used, disk % busy) |
| **Saturation** | Is work queued up waiting for this resource? (e.g. run queue length, disk I/O queue depth) |
| **Errors** | Are there actual errors occurring? (e.g. dropped network packets, disk I/O errors) |

> **Why this ordering helps:** utilization alone can be misleading — a disk at 100% utilization serving requests instantly isn't a problem, but a disk at 60% utilization with a deep, growing queue (high saturation) often is. Checking all three, for each resource, in a consistent order, tends to find real bottlenecks faster than jumping straight to whichever metric happens to look unusual first.

---

## 🖥️ `top` — The Universal Starting Point

```bash
top
```

```
%Cpu(s): 23.4 us,  8.1 sy,  0.0 ni, 66.2 id,  2.1 wa,  0.0 hi,  0.2 si,  0.0 st
MiB Mem :  16384.0 total,   2156.3 free,   4302.1 used,   9925.6 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.  11203.4 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
 1234 www-data  20   0  812344  98234  12456 S  45.2   0.6   12:34.56 nginx
```

### Reading the CPU Line

| Field | Meaning |
|---|---|
| `us` | User-space CPU time |
| `sy` | System/kernel CPU time |
| `ni` | User-space time for processes with adjusted niceness (see the *Signals and Scheduling* guide) |
| `id` | Idle |
| `wa` | I/O wait — CPU idle specifically because it's waiting on disk/network I/O |
| `hi` / `si` | Hardware/software interrupt handling time |
| `st` | "Steal" time — CPU cycles a virtualized guest wanted but didn't get, taken by the hypervisor for other guests (relevant on VMs/cloud instances) |

> **`st` matters specifically on cloud/VM instances:** high steal time means your virtual machine isn't actually getting the CPU it's nominally allocated, because the underlying hypervisor is busy serving other tenants — a performance problem that's invisible if you only look at your own VM's `us`/`sy`/`id` breakdown, since none of those reflect time you simply weren't given.

### Interactive Commands Inside `top`

| Key | Action |
|---|---|
| `P` | Sort by CPU usage (default) |
| `M` | Sort by memory usage |
| `T` | Sort by running time |
| `k` | Kill a process (prompts for PID) |
| `r` | Renice a process (prompts for PID and new value — see the *Signals and Scheduling* guide) |
| `1` | Toggle per-core CPU breakdown vs. aggregate |
| `c` | Toggle showing full command line vs. just the process name |
| `q` | Quit |

### Per-Process Memory Fields

```
VIRT     RES      SHR
812344   98234    12456
```

| Field | Meaning |
|---|---|
| `VIRT` | Total virtual memory the process has mapped — often much larger than actual usage, includes shared libraries, memory-mapped files, reserved-but-unused address space |
| `RES` | Resident memory — actually held in physical RAM right now |
| `SHR` | Shared memory — portion of RES that could be shared with other processes (e.g. shared libraries) |

> **Common misreading:** `VIRT` looking huge is usually not alarming on its own — it reflects address space *reserved*, not memory actually *consumed*. `RES` is generally the more meaningful "how much RAM is this process actually using" figure for everyday troubleshooting.

---

## 🎨 `htop` — A Friendlier Interactive View

```bash
htop
```

`htop` shows largely the same underlying data as `top`, with several practical usability improvements: color-coded bars for CPU/memory, mouse support, easier tree-view of process parent/child relationships, and simpler in-UI process management (no need to remember a key, then type a PID blind).

| Feature | `top` | `htop` |
|---|---|---|
| Color-coded visual bars | No | Yes |
| Tree view (parent/child) | Limited (`-H`/`V` toggle) | Built-in, easy toggle (`F5`) |
| Mouse interaction | No | Yes |
| Filtering/searching processes | Limited | Built-in (`F4` filter, `/` search) |
| Pre-installed by default | Almost universally | Often needs installing |

```bash
htop -d 10        # set update delay (tenths of a second)
```

> **Tip:** `htop`'s tree view (`F5`) is genuinely useful for understanding parent/child relationships covered conceptually in the *Process Lifecycle* guide — seeing which process forked which, visually, often clarifies a confusing process list faster than reading flat PID/PPID columns.

---

## 💾 `iotop` — Per-Process Disk I/O

`top`/`htop` show CPU and memory per process, but not disk I/O — `iotop` fills that specific gap.

```bash
sudo iotop                    # requires root — reads from the kernel's I/O accounting
```

```
Total DISK READ:    2.34 M/s | Total DISK WRITE:    8.91 M/s
  PID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN  IO>    COMMAND
 5678  be/4  postgres    1.20 M/s   6.50 M/s   0.00 %  45.2%  postgres
```

### Useful Flags

```bash
sudo iotop -o                   # only show processes ACTUALLY doing I/O right now (much less noisy)
sudo iotop -a                     # show ACCUMULATED I/O since iotop started, not just per-second rate
sudo iotop -P                       # show only processes, not individual threads
sudo iotop -b -n 5                    # batch mode — useful for logging/scripting, run 5 iterations then exit
```

> **Why `-o` is almost always worth using:** without it, `iotop` lists every process on the system, the overwhelming majority showing 0.00 I/O — `-o` filters down to only what's actually reading/writing right now, turning a noisy full-system list into a focused view of the actual contributors to current disk activity.

---

## 📊 `vmstat` — Virtual Memory and System-Wide Stats

```bash
vmstat 2                # refresh every 2 seconds, continuously
vmstat 2 5                 # refresh every 2 seconds, 5 times, then stop
```

```
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  0      0 2156300 145200 9456000    0    0    45   120  890  1450 23  8 66  2  0
```

### Reading the Output

| Column | Meaning |
|---|---|
| `r` | Number of processes currently RUNNABLE (running or waiting for CPU) — sustained high values relative to CPU core count indicate CPU saturation |
| `b` | Number of processes BLOCKED, waiting on I/O |
| `swpd` | Amount of virtual memory currently swapped out to disk |
| `si` / `so` | Memory swapped IN/OUT per second — any sustained non-zero value here is usually a red flag |
| `bi` / `bo` | Blocks received/sent from/to a block device — raw disk I/O activity |
| `in` | Interrupts per second |
| `cs` | Context switches per second — very high values can indicate excessive process/thread switching overhead |

> **The `r` column as a saturation signal:** this connects directly to the USE Method's "saturation" check above — `r` consistently exceeding the number of CPU cores means processes are genuinely queued waiting for CPU time, not just that the CPU is busy. `nproc` (see the *Networking Basics* and *Signals and Scheduling* guides) tells you the core count to compare against.

> **`si`/`so` (swap activity) as a critical signal:** any sustained swap-in/swap-out activity generally indicates real memory pressure — the system has run out of comfortable RAM and is actively paging to disk, which is dramatically slower than RAM and a strong indicator that more memory (or reduced memory usage) is needed. This differs from the `free`/`buff-cache` consideration in the *Logs and Metrics* guide — cache usage is benign and reclaimed instantly; active swapping is not.

---

## 📈 `sar` — Historical and Live System Activity Reporting

`sar` (System Activity Reporter, from the `sysstat` package) is distinctive in that it can report **live** data like the other tools here, but also **historical** data collected automatically in the background — useful for "what was happening at 3 AM last night" without having had a tool actively watching at the time.

```bash
sudo apt install sysstat      # Debian/Ubuntu
sudo dnf install sysstat        # RHEL/Fedora
sudo systemctl enable --now sysstat    # enables the background collection service
```

### Live Reporting

```bash
sar -u 2 5             # CPU usage, every 2 seconds, 5 times
sar -r 2 5                # memory usage
sar -d 2 5                  # disk I/O (per device)
sar -n DEV 2 5                 # network interface statistics
```

### Historical Reporting (Requires Background Collection Enabled)

```bash
sar -u                   # today's CPU usage history, at the collection interval (often every 10 min by default)
sar -u -f /var/log/sysstat/sa15      # a specific PAST day's data (day 15 of the current month)
sar -u -s 09:00:00 -e 10:00:00          # a specific time window within the available data
```

> **Why this historical capability is uniquely valuable:** `top`/`htop`/`vmstat`/`iotop` are all live-only — if you weren't actively watching when a problem occurred, that data is gone. `sar`'s background collection means a system experiencing intermittent issues can be retroactively investigated, without needing to have predicted exactly when to watch in real time. This is directly analogous to the metrics/logs distinction in the *Monitoring Basics* guide — `sar` is essentially a built-in, lightweight, single-host metrics history.

---

## 🎛️ `dstat` — A Combined, Customizable View

`dstat` consolidates CPU, memory, disk, and network statistics into a single, configurable, color-coded live display — somewhat positioned as a more modern, combined alternative to running `vmstat`/`iostat`/`sar` separately side by side.

```bash
sudo apt install dstat        # may be packaged as `dstat` or its successor `pcp-dstat`/`dool` on some distros
dstat                            # default view: CPU, disk, network, paging, system
```

```
----total-cpu-usage---- -dsk/total- -net/total- ---paging-- ---system--
usr sys idl wai stl| read  writ| recv  send|  in   out | int   csw
 23   8  66   2    0|1230k 4502k| 145k  892k|   0     0 | 890  1450
```

### Selecting Specific Columns

```bash
dstat -c -m -d -n          # CPU, memory, disk, network specifically
dstat --top-cpu --top-mem    # also show the top CPU/memory consuming process per interval
dstat -cdn 5                   # CPU, disk, network, every 5 seconds
```

> **Note:** `dstat` has been effectively superseded/absorbed by tools like `pcp-dstat` (part of the Performance Co-Pilot suite) on some current distributions, since the original `dstat` project is no longer actively maintained — check what's actually packaged and current on your specific distribution rather than assuming the original `dstat` command is still the maintained option.

---

## 🔍 Putting It Together: CPU, Memory, Disk, and Network Analysis

### CPU Bottleneck Checklist

```bash
top                      # is overall %us+%sy genuinely high, or mostly %wa (which is actually an I/O issue)?
mpstat -P ALL 2             # is load spread across cores, or concentrated on one (a single-threaded bottleneck)?
vmstat 2                       # is `r` consistently higher than the core count? (genuine CPU saturation)
```

### Memory Bottleneck Checklist

```bash
free -h                  # check `available`, not just `free` (see the Logs and Metrics guide)
vmstat 2                   # check `si`/`so` — any sustained non-zero swap activity is a strong signal
top                          # sort by %MEM (`M` key) to find the largest consumers
```

### Disk Bottleneck Checklist

```bash
iostat -x 2               # check `await` (rising = trouble) and `%util` (sustained near 100% = saturated)
iotop -o                    # which SPECIFIC process is generating the I/O?
sar -d 2 5                    # per-device historical/live comparison
```

### Network Bottleneck Checklist

```bash
sar -n DEV 2 5             # throughput per interface
ss -s                        # socket-level summary (see the Linux Network Tools guide)
dstat -n 2                     # quick combined view alongside other resources, for correlation
```

> **The value of checking multiple resources together, not in isolation:** a disk bottleneck often *manifests* as high `%wa` in `top`'s CPU line — looking at CPU alone might misdiagnose this as a CPU problem. Running `iostat`/`iotop` alongside `top` (or using `dstat`'s combined view) makes the actual cross-resource relationship visible immediately, rather than requiring you to mentally connect numbers from several separately-run tools.

---

## ⚡ Quick Reference

| Tool | Best for |
|---|---|
| `top` | Universal first check — process list, CPU/memory overview, always available |
| `htop` | Friendlier interactive alternative, tree view, easier filtering |
| `iotop` | Per-process disk I/O — which process is actually generating disk activity |
| `vmstat` | System-wide CPU/memory/swap/IO trend, especially the `r` (CPU saturation) and `si`/`so` (swap) columns |
| `sar` | Historical AND live reporting — the only tool here that can retroactively investigate past activity |
| `dstat` | Combined, customizable live view across CPU/memory/disk/network at once |

| Symptom | Where to look first |
|---|---|
| High overall load, unclear why | `top` → check `%wa` specifically before assuming CPU-bound |
| Suspected memory pressure | `free -h` (`available`) + `vmstat` (`si`/`so`) |
| Suspected disk bottleneck | `iostat -x` (`await`, `%util`) + `iotop -o` for the specific process |
| Suspected network bottleneck | `sar -n DEV` + `ss -s` |
| "What happened at 3 AM" | `sar -f /var/log/sysstat/saDD` (historical) |

---

## 💡 Best Practices

- Apply the Utilization/Saturation/Errors check to each resource rather than fixating on whichever single metric looks unusual first — utilization alone can be misleading without checking saturation alongside it.
- Distinguish `%wa` (I/O wait) from genuine CPU load in `top` before concluding a problem is CPU-bound — high `%wa` usually points toward storage, not CPU capacity.
- Treat `VIRT` in `top` as reserved address space, not actual memory consumption — `RES` is the more meaningful per-process figure for everyday troubleshooting.
- Watch `vmstat`'s `si`/`so` columns specifically for swap activity — any sustained non-zero value is a stronger memory-pressure signal than `free`'s raw "free" number.
- Enable `sysstat`'s background collection (`systemctl enable --now sysstat`) proactively, before an incident — it's the only tool in this set that lets you investigate after the fact rather than only while actively watching.
- Use `iotop -o` rather than plain `iotop` for almost all practical troubleshooting — it filters out the overwhelming majority of processes doing zero I/O.
- Check related resources together rather than in isolation — a disk or network bottleneck frequently shows up first as elevated `%wa` in a CPU view, and isolated single-tool investigation can lead to misdiagnosing which resource is actually the root cause.