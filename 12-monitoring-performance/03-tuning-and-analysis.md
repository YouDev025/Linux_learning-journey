# Tuning and Analysis

A reference guide to acting on the performance data covered in the *Performance Tools* guide — kernel tuning parameters, I/O scheduling, swap management, and capacity planning for sustained reliability.

---

## 🧭 Tuning as the Second Half of a Workflow

The *Performance Tools* guide covered **measuring** — finding which resource is actually the bottleneck using the USE Method (utilization, saturation, errors). Tuning is the deliberate second half: **changing system configuration in response to that data**, rather than adjusting settings speculatively without evidence they address an actual, measured problem.

> **A discipline worth stating explicitly:** every tuning change in this guide should be motivated by something you've actually observed (high `si`/`so` in `vmstat`, high `await` in `iostat`, a specific kernel parameter hitting its limit in logs) — not applied preemptively because "it's a common recommendation." Tuning without measurement risks fixing a problem that doesn't exist while potentially introducing a new one that does, and makes it much harder to know afterward whether a change actually helped.

---

## ⚙️ Kernel Tuning Parameters: `sysctl`

### What `sysctl` Controls

Many kernel behaviors are exposed as **tunable parameters** under `/proc/sys/`, readable and (for many) writable at runtime via the `sysctl` interface — without needing to recompile or reboot for most changes.

```bash
sysctl -a                          # list ALL current kernel parameters (long output)
sysctl vm.swappiness                  # read one specific parameter
sudo sysctl vm.swappiness=10            # change it NOW (temporary — lost on reboot unless persisted)
```

### Persisting Changes

```bash
sudo nano /etc/sysctl.d/99-custom.conf
```

```
vm.swappiness = 10
net.core.somaxconn = 4096
```

```bash
sudo sysctl --system            # apply ALL sysctl.d configuration files immediately, without rebooting
```

> **Tip:** Always write changes to a file under `/etc/sysctl.d/` rather than only running `sysctl -w` interactively — runtime-only changes vanish on the next reboot, silently reverting whatever tuning you did, often discovered only when the original problem mysteriously reappears.

### `vm.swappiness` — Swap Aggressiveness

```bash
sysctl vm.swappiness
# vm.swappiness = 60   (a common default)
```

Controls how aggressively the kernel prefers to swap out memory pages (to make room for disk cache) versus reclaiming cache directly — a value from `0` (avoid swapping as much as possible) to `100` (swap aggressively).

```bash
sudo sysctl vm.swappiness=10      # common adjustment for a server prioritizing application memory over cache
```

> **When this is genuinely worth tuning:** if `vmstat`'s `si`/`so` columns (see the *Performance Tools* guide) show swap activity you've determined is hurting performance, and the system has enough free RAM that swapping shouldn't be necessary, lowering `swappiness` makes the kernel reclaim cache before reaching for swap. This is **not** a substitute for adding actual memory if the system is genuinely memory-constrained — it shifts *when* swapping happens, not whether the underlying memory pressure exists.

### `net.core.somaxconn` — Connection Backlog

Controls the maximum number of pending connections the kernel will queue for a listening socket before the application has accepted them — relevant for high-connection-rate services (busy web servers, load balancers).

```bash
sudo sysctl net.core.somaxconn=4096
```

> **When this matters:** if a busy service is dropping connections under load and `ss -s`/application logs show connection queue overflows, the default (often `128` historically) can be a real bottleneck — but the application itself also needs to be configured to actually use a larger backlog (many web servers have their own `backlog` setting that must match or be below the kernel's `somaxconn`).

### `fs.file-max` — System-Wide File Descriptor Limit

```bash
sysctl fs.file-max
sudo sysctl fs.file-max=2097152
```

A system-wide ceiling on open file descriptors across all processes — relevant for systems running many processes or services each holding many open files/sockets simultaneously.

> **Note:** this is the *system-wide* ceiling — per-process limits are configured separately (via `ulimit`, or `LimitNOFILE=` in a systemd unit, see the *systemd Service Files* guide). Hitting "too many open files" errors can stem from either limit, so check both.

### `vm.overcommit_memory` — Memory Allocation Strategy

```bash
sysctl vm.overcommit_memory
```

| Value | Behavior |
|---|---|
| `0` | Heuristic overcommit (default) — kernel guesses whether an allocation is "reasonable" |
| `1` | Always overcommit — never refuse an allocation based on available memory |
| `2` | Strict accounting — refuse allocations that would exceed configured limits, no overcommit |

> **Why this exists:** many applications allocate more virtual memory than they'll actually use (e.g. via `fork()`, covered in the *Process Lifecycle* guide, which initially shares pages via copy-on-write rather than truly doubling memory usage) — strict accounting (`2`) can cause legitimate allocations to fail in scenarios the heuristic mode would have handled fine. This is a genuinely advanced tuning parameter; changing it without specific justification (e.g. running certain database or memory-intensive workloads with documented recommendations) is rarely a good idea.

### Networking Parameters Worth Knowing

```bash
net.ipv4.tcp_fin_timeout = 60          # how long a closed TCP connection lingers in TIME_WAIT
net.ipv4.tcp_max_syn_backlog = 2048      # pending SYN (connection-initiating) queue size
net.core.rmem_max / wmem_max             # maximum socket receive/send buffer sizes
```

> **A general caution for network tuning specifically:** these parameters interact with each other and with application-level settings in ways that are easy to get subtly wrong — changing one without understanding the others can shift a bottleneck rather than resolve it. Reach for vendor/application-specific tuning guides (e.g. a database's documented kernel recommendations) rather than generic network tuning advice when optimizing for a specific workload.

---

## 💾 I/O Scheduling

### What an I/O Scheduler Does

The kernel's I/O scheduler decides the **order** in which pending disk requests are actually issued to the underlying storage device — this matters because the "best" order depends heavily on the type of storage involved.

### Checking the Current Scheduler

```bash
cat /sys/block/sda/queue/scheduler
# [mq-deadline] kyber bfq none
```

The bracketed entry is the currently active scheduler for that specific device.

### Common Schedulers and When They Fit

| Scheduler | Best suited for |
|---|---|
| `none` (no-op) | NVMe SSDs — the device's own internal controller already handles ordering far better than the kernel can second-guess; minimal kernel overhead is the right choice |
| `mq-deadline` | General-purpose, including most SSDs and many HDDs — balances throughput with bounding how long any single request can be delayed |
| `bfq` (Budget Fair Queueing) | Workloads prioritizing fairness/responsiveness between competing processes, e.g. desktop interactive use, or multi-tenant systems where one process shouldn't starve others' I/O |
| `kyber` | Latency-sensitive workloads on fast (SSD/NVMe) storage, simpler/lighter-weight than `bfq` |

> **The core principle behind these defaults:** spinning hard drives benefit from request reordering/elevator-style scheduling (minimizing physical seek distance), since seeking is genuinely slow. NVMe SSDs have no seek penalty at all and a sophisticated internal controller — for these, `none` often outperforms anything the kernel scheduler tries to add on top, since there's no seek-time benefit to capture and the scheduler is pure overhead.

### Changing the Scheduler

```bash
echo mq-deadline | sudo tee /sys/block/sda/queue/scheduler    # temporary — until reboot
```

For persistence, typically configured via a udev rule:

```bash
sudo nano /etc/udev/rules.d/60-scheduler.rules
```

```
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
```

> **Tip:** Note the `rotational` attribute distinction in the rule above — it's a clean way to apply different scheduler choices automatically based on whether a device is a spinning disk (`rotational == 1`) or an SSD/NVMe (`rotational == 0`), rather than hardcoding per-device-name rules that might not match consistently across different hardware.

### Checking Whether It's Actually Worth Tuning

Connecting back to the measurement discipline from the *Performance Tools* guide: I/O scheduler tuning is worth investigating specifically when `iostat -x`'s `await` is elevated and `%util` is high on a device where the **default** scheduler choice might be mismatched (e.g. a spinning-disk-oriented scheduler accidentally left active on an NVMe device after a migration). On correctly auto-detected modern setups, the default is frequently already appropriate, and this is a less commonly impactful tuning lever than swap or application-level configuration.

---

## 🔄 Swap Management

### Sizing Swap

| System type | Common swap sizing guidance |
|---|---|
| Server with ample RAM, swap as a safety net only | A modest fixed amount (e.g. 2-4GB), or even none, if memory is well-provisioned and monitored |
| Server expected to occasionally use swap under load spikes | RAM-dependent; historically "equal to RAM" was common advice, less universally true with today's larger RAM sizes |
| System using hibernation (suspend-to-disk) | Swap must be AT LEAST the size of RAM, since the entire RAM contents get written to swap during hibernation |

> **The shifting nature of this guidance:** older rules of thumb (swap = 2x RAM) originated when typical RAM sizes were small enough that swap was a routine, expected part of normal operation. With contemporary RAM sizes, treating *any* sustained swap activity as a performance problem to investigate (per the *Performance Tools* guide's `si`/`so` discussion) — rather than a normal, expected behavior — is generally the more accurate modern framing, except specifically for hibernation support.

### Viewing Current Swap Configuration

```bash
swapon --show
free -h
cat /proc/swaps
```

```
NAME      TYPE      SIZE   USED PRIO
/dev/sda2 partition   4G     0B   -2
```

### Adding Swap (Swap File, Common on Modern Systems)

```bash
sudo fallocate -l 4G /swapfile           # allocate the file
sudo chmod 600 /swapfile                   # restrict permissions — swap can contain sensitive memory contents
sudo mkswap /swapfile                        # format it as swap
sudo swapon /swapfile                          # activate it
```

```bash
# /etc/fstab — make it persistent (see the Partitioning and Filesystems guide)
/swapfile none swap sw 0 0
```

> **Tip:** A swap *file* (rather than a dedicated swap *partition*) is generally the more flexible modern approach — easy to resize or remove without repartitioning, at a negligible performance cost on modern filesystems/storage.

### Swap and Encrypted Systems

If the system uses LUKS full-disk encryption (see the *Storage Encryption* guide), swap should be encrypted too — unencrypted swap can leak sensitive memory contents to disk in plaintext, directly undermining the rest of the encryption setup.

### Multiple Swap Devices and Priority

```bash
sudo swapon --priority 10 /dev/sda2
sudo swapon --priority 5 /swapfile
```

Higher priority swap is used first — useful if you have both a fast (NVMe) and slow (spinning disk) swap location, and want the faster one preferred before falling back to the slower one under heavier memory pressure.

---

## 📐 Capacity Planning Basics

### Why Capacity Planning Is Distinct from Reactive Tuning

Everything above responds to a problem already showing up in current metrics. **Capacity planning** asks a forward-looking question instead: **given current trends, when will current capacity become insufficient, and what should be provisioned before that happens?** This shifts the work from reactive firefighting to proactive provisioning — directly enabled by the historical metrics collection discussed in the *Performance Tools* guide (`sar`'s background collection) and the *Monitoring Basics* guide's metrics infrastructure.

### The Basic Approach: Trend, Don't Just Snapshot

```bash
sar -u -f /var/log/sysstat/sa01      # CPU usage at the start of the month
sar -u -f /var/log/sysstat/sa15        # CPU usage mid-month
sar -u -f /var/log/sysstat/sa28          # CPU usage near month-end
```

A single current reading tells you today's utilization; comparing readings **over time** tells you the **trend** — which is what actually drives a capacity decision. 60% disk utilization today is very different information depending on whether it was 40% three months ago (growing, plan ahead) or has been stable at 60% for a year (likely fine as-is).

### Key Questions Capacity Planning Tries to Answer

| Question | What to look at |
|---|---|
| When will we run out of disk space? | Historical `df`/disk usage trend, extrapolated forward |
| Will current CPU/memory handle expected growth? | Historical `sar`/monitoring data, correlated with known growth drivers (user count, traffic volume) |
| Do we need to scale before a known future event? | Combine trend data with business knowledge (a planned launch, seasonal traffic pattern) |
| Is current headroom adequate for unexpected spikes? | Compare typical utilization against peak/worst-case observed utilization, not just average |

### A Simple Disk Space Projection Example

```bash
# Check current usage and growth rate
df -h /var
du -sh /var/log/* | sort -rh | head -10      # what's actually consuming space
```

```
Day 1:  120GB used
Day 30: 135GB used
→ ~15GB/month growth rate
→ At 500GB total capacity, ~25GB remaining → roughly 1.7 months until full, AT THE CURRENT RATE
```

> **The critical caveat in any such projection:** linear extrapolation assumes the current growth rate continues unchanged — genuinely useful as an early-warning trigger ("we should investigate/plan within the next month"), but not a precise prediction, since growth rates frequently aren't actually linear (a new feature launch, a traffic spike, a cleanup of old data can all shift the rate substantially). Treat these projections as **prompts to investigate and plan**, not as guaranteed deadlines.

### Headroom: Planning for More Than Just "Current Trend"

A capacity plan based purely on smooth historical trend extrapolation misses **spikes** — a service might average 40% CPU but regularly spike to 95% during specific known-busy periods (e.g. business hours, a daily batch job). Provisioning only for the *average* leaves no margin for those spikes.

```bash
sar -u -f /var/log/sysstat/sa15 | awk '{print $3}' | sort -rn | head -5   # find PEAK readings, not just average
```

> **Tip:** When reviewing historical data for capacity planning, deliberately look at peak/percentile values (e.g. "95th percentile CPU usage"), not just the average — the average can look comfortably low while peak periods are already uncomfortably close to capacity, which is the actual constraint that matters for reliability.

### Connecting Capacity Planning Back to Tuning

Capacity planning and the tuning sections above aren't fully separate activities — sometimes the answer to "we're approaching a capacity limit" is genuinely "provision more resources," but sometimes it's "the current resource usage is higher than it needs to be due to a tunable inefficiency" (an oversized log retention window, a swappiness setting causing unnecessary disk I/O, an undersized connection backlog causing retries that amplify load). Reviewing whether tuning can extend current capacity is often cheaper and faster than provisioning new hardware/instances, and worth checking before assuming growth requires new resources.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| View a sysctl parameter | `sysctl parameter.name` |
| Change temporarily | `sudo sysctl parameter.name=value` |
| Persist a change | add to `/etc/sysctl.d/99-custom.conf`, then `sudo sysctl --system` |
| Lower swap aggressiveness | `vm.swappiness = 10` |
| Increase connection backlog | `net.core.somaxconn = 4096` |
| Check current I/O scheduler | `cat /sys/block/sda/queue/scheduler` |
| Change scheduler temporarily | `echo SCHEDULER \| sudo tee /sys/block/sda/queue/scheduler` |
| View current swap | `swapon --show` |
| Add a swap file | `fallocate` → `chmod 600` → `mkswap` → `swapon` → add to `/etc/fstab` |
| Review historical CPU trend | `sar -u -f /var/log/sysstat/saDD` |
| Find peak (not average) usage | `sar ... \| sort -rn \| head` |

---

## 💡 Best Practices

- Tune only in response to actual measured evidence (per the *Performance Tools* guide), not preemptively based on generic "recommended settings" lists — unmotivated tuning risks new problems and makes outcomes hard to evaluate.
- Always persist `sysctl` changes to a file under `/etc/sysctl.d/`, never rely on runtime-only `sysctl -w` — it silently reverts on the next reboot.
- Treat any sustained swap activity as worth investigating on a modern, adequately-provisioned system, rather than assuming it's normal — `vm.swappiness` tuning shifts *when* swapping happens, it doesn't fix genuine memory shortage.
- Let `rotational` drive I/O scheduler selection automatically (via udev rules) rather than hardcoding per-device assumptions that may not hold after hardware changes.
- Restrict permissions on any swap file (`chmod 600`) and ensure swap is encrypted on systems using full-disk encryption — unencrypted swap can leak sensitive memory contents.
- Base capacity planning on trends and peak/percentile values, not single current readings or averages alone — averages can mask already-concerning peak-period utilization.
- Treat linear growth projections as early-warning triggers to investigate, not precise deadlines — real-world growth rates rarely stay perfectly linear.
- Before assuming a capacity constraint requires new resources, check whether a tuning adjustment could meaningfully extend current headroom — it's often the cheaper, faster option.