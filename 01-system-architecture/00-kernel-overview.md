# Linux Kernel Overview

> A comprehensive reference to the Linux kernel's architecture — covering its monolithic design, subsystems, memory management, process scheduling, I/O, system calls, and module system.

---

## Table of Contents

1. [What Is the Kernel?](#1-what-is-the-kernel)
2. [Kernel Architecture: Monolithic vs Alternatives](#2-kernel-architecture)
3. [Kernel Space vs User Space](#3-kernel-vs-user-space)
4. [System Calls](#4-system-calls)
5. [Process Management](#5-process-management)
6. [Scheduling](#6-scheduling)
7. [Memory Management](#7-memory-management)
8. [Virtual File System (VFS)](#8-virtual-file-system)
9. [I/O and Block Layer](#9-io-and-block-layer)
10. [Networking Stack](#10-networking-stack)
11. [Kernel Modules and Drivers](#11-kernel-modules-and-drivers)
12. [Interrupt Handling](#12-interrupt-handling)
13. [Synchronisation Primitives](#13-synchronisation)
14. [Kernel Versioning and Configuration](#14-versioning-and-config)
15. [Observability and Debugging](#15-observability)
16. [Reference Summary](#16-reference)

---

## 1. What Is the Kernel?

The kernel is the **core of the operating system** — the software layer that sits between hardware and all userspace programs. It is the only component that runs in full hardware-privileged mode (ring 0 on x86), with unrestricted access to all CPU instructions, memory, and I/O ports.

Every other program — shells, databases, web servers, desktop environments — runs in unprivileged user space and must request kernel services through the **system call interface**.

### 1.1 Responsibilities

| Domain | What the kernel does |
|---|---|
| **Process management** | Create, schedule, and terminate processes and threads |
| **Memory management** | Virtual address spaces, paging, allocation, protection |
| **File systems** | Abstract disk structures into files and directories |
| **Device I/O** | Talk to hardware through drivers; expose uniform interfaces |
| **Networking** | Implement TCP/IP and socket APIs |
| **Security** | Enforce access control, capabilities, namespaces, seccomp |
| **Inter-process communication** | Pipes, signals, sockets, shared memory, message queues |
| **Hardware abstraction** | Uniform interface regardless of underlying hardware |

### 1.2 The Kernel Is Not the OS

A common conflation: Linux is the kernel; **GNU/Linux** (or a named distribution) is the operating system. The kernel alone provides no shell, no utilities, and no desktop. Without userspace (glibc, coreutils, init, etc.), a bare kernel can boot but offers nothing usable.

### 1.3 Key Numbers (Linux 6.x)

| Metric | Value |
|---|---|
| Lines of code | ~35 million |
| Supported architectures | 25+ (x86, ARM, RISC-V, MIPS, PowerPC, s390…) |
| Contributors (6.x cycle) | 1,700–2,000 per release |
| Release cadence | ~9–10 weeks per major version |
| Supported device drivers | ~8,000+ |
| Active subsystems | 30+ |

---

## 2. Kernel Architecture: Monolithic vs Alternatives

### 2.1 The Monolithic Design

Linux uses a **monolithic kernel**: all core OS services — process management, memory management, file systems, device drivers, networking — run in a **single shared address space** in kernel mode.

```
┌──────────────────────────────────────────────────────────┐
│                     User Space                           │
│   applications   glibc   shells   daemons   ...         │
└──────────────────────┬───────────────────────────────────┘
                       │ system calls
┌──────────────────────▼───────────────────────────────────┐
│                   Kernel Space                           │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌────────┐ ┌─────────────┐  │
│  │ Process  │ │ Memory   │ │  VFS   │ │  Networking │  │
│  │ Manager  │ │ Manager  │ │ Layer  │ │    Stack    │  │
│  └──────────┘ └──────────┘ └────────┘ └─────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │           Device Drivers (thousands)               │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │      Hardware Abstraction Layer (arch/)             │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────┐
│                       Hardware                           │
│        CPU    RAM    Disk    NIC    GPU    USB ...       │
└──────────────────────────────────────────────────────────┘
```

**Implications of monolithic design:**

- All kernel code shares one address space — a bug in any driver can corrupt the entire kernel (kernel panic).
- Function calls between subsystems are direct C function calls — extremely fast (no IPC overhead).
- Adding new functionality is straightforward: write a module, load it into the shared space.
- Performance is excellent because there are no context switches between OS components.

### 2.2 Alternative Designs

| Architecture | Description | Examples |
|---|---|---|
| **Monolithic** | All OS services in one address space | Linux, FreeBSD, traditional Unix |
| **Microkernel** | Only IPC, scheduling, basic memory in kernel; everything else in userspace servers | GNU Hurd, MINIX 3, QNX, seL4 |
| **Hybrid** | Microkernel with some services moved back into kernel for performance | macOS (XNU = Mach + BSD), Windows NT |
| **Exokernel** | Minimal kernel exposes hardware directly; library OSes implement abstractions | Research systems (MIT Exokernel) |
| **Unikernel** | Application linked directly with OS libraries into a single kernel-mode binary | MirageOS, IncludeOS |

### 2.3 Why Monolithic Won

Microkernels were theoretically superior in the 1990s (Tanenbaum–Torvalds debate, 1992). In practice:

- IPC between userspace OS servers introduces latency that monolithic direct calls do not.
- Context switches between privilege levels are expensive; microkernels do many more of them.
- Linux's modular monolithic design (loadable modules, clean subsystem interfaces) captured most software engineering benefits of microkernels without the performance cost.
- Linux drivers can be loaded/unloaded at runtime, providing the extensibility advantage attributed to microkernels.

### 2.4 Linux's Modular Monolithic Approach

Linux is not a rigid monolith. The kernel is divided into cleanly separated subsystems, and most drivers and filesystems are **loadable modules** — code that can be inserted into or removed from the running kernel without a reboot. This gives Linux the extensibility of a microkernel with the performance of a monolith.

---

## 3. Kernel Space vs User Space

### 3.1 CPU Privilege Rings

Modern CPUs implement hardware-enforced privilege levels. On x86:

```
Ring 0  — Kernel mode: unrestricted access to all instructions and hardware
Ring 1  — (unused by Linux)
Ring 2  — (unused by Linux)
Ring 3  — User mode: restricted; privileged instructions cause a fault
```

ARM uses equivalent EL (Exception Level) designations: EL0 (user), EL1 (kernel), EL2 (hypervisor), EL3 (secure monitor).

### 3.2 What Each Space Can Do

| Capability | Kernel Space | User Space |
|---|---|---|
| Access any physical memory | ✓ | ✗ |
| Execute privileged CPU instructions | ✓ | ✗ (causes fault) |
| Directly access I/O ports | ✓ | ✗ (usually) |
| Install interrupt handlers | ✓ | ✗ |
| Modify page tables | ✓ | ✗ |
| Crash the whole system with a bug | ✓ | ✗ (process is killed) |

### 3.3 Address Space Layout

Each process has its own **virtual address space**. On a 64-bit x86 Linux system:

```
0x0000000000000000                    ← NULL (unmapped, catches null deref)
   User space (0 – 128 TiB)
   ├── Text segment  (.text)          ← executable code (read + execute)
   ├── Data segment  (.data, .bss)    ← global/static variables
   ├── Heap          ↑ grows up       ← malloc() region
   ├── Memory-mapped (.mmap)          ← shared libs, files, anonymous maps
   └── Stack         ↓ grows down     ← function call frames, local vars
0x00007fffffffffff                    ← top of user space

   [canonical hole — unmapped, causes page fault]

0xffff800000000000                    ← start of kernel space
   Kernel space (upper 128 TiB)
   ├── Direct mapping of all RAM      ← kernel can address all physical memory
   ├── vmalloc region                 ← virtually contiguous kernel allocations
   ├── Kernel modules                 ← loaded .ko binaries
   └── Kernel text + data            ← the kernel itself
0xffffffffffffffff
```

Every process's virtual address space maps the **same kernel** in the upper half. When a system call is made, the CPU switches to kernel mode but is already addressing the same kernel mapping — no address space switch needed (mitigated by Meltdown/Spectre via KPTI on affected CPUs).

---

## 4. System Calls

System calls are the **only sanctioned interface** from user space into the kernel. They are not regular function calls — they require a CPU privilege level transition.

### 4.1 How a System Call Works (x86-64)

```
User space:
  1. Arguments placed in registers: rdi, rsi, rdx, r10, r8, r9
  2. System call number placed in: rax
  3. Execute: syscall instruction

CPU (hardware):
  4. Save user-mode registers
  5. Switch to kernel stack
  6. Transition to ring 0
  7. Jump to kernel syscall entry point (via MSR_LSTAR register)

Kernel:
  8. syscall dispatcher reads rax → looks up syscall table
  9. Calls the C function: sys_read(), sys_write(), sys_open(), etc.
  10. Return value placed in rax

CPU (hardware):
  11. Switch back to user stack
  12. Transition to ring 3
  13. Return to user space (sysret instruction)

User space:
  14. glibc wrapper checks rax for error (negative = errno)
  15. Returns to calling code
```

### 4.2 System Call Categories

| Category | Examples |
|---|---|
| **Process control** | `fork`, `execve`, `exit`, `wait4`, `clone`, `getpid` |
| **File operations** | `open`, `read`, `write`, `close`, `lseek`, `stat`, `unlink` |
| **Directory** | `mkdir`, `rmdir`, `getdents64`, `chdir`, `getcwd` |
| **Memory** | `mmap`, `munmap`, `brk`, `mprotect`, `madvise` |
| **Networking** | `socket`, `bind`, `listen`, `accept`, `connect`, `send`, `recv` |
| **IPC** | `pipe`, `msgget`, `msgsnd`, `shmget`, `shmat`, `semget` |
| **Signals** | `kill`, `sigaction`, `sigprocmask`, `pause`, `signalfd` |
| **Time** | `clock_gettime`, `nanosleep`, `timerfd_create` |
| **User/Group** | `getuid`, `setuid`, `getgid`, `setgroups` |
| **Capabilities** | `capget`, `capset` |
| **Namespace/cgroup** | `unshare`, `setns`, `clone` (with flags) |
| **Seccomp** | `seccomp` |

### 4.3 Viewing System Calls

```bash
# Trace all syscalls of a command
strace ls /tmp

# Count syscalls by type
strace -c ls /tmp

# Trace a running process
strace -p 1234

# Trace only specific calls
strace -e trace=read,write,open ls /tmp

# Show timestamps
strace -t ls /tmp
```

### 4.4 The C Library as Syscall Wrapper

Most programmers never call syscalls directly. The C library (glibc on most Linux systems) provides wrappers:

```c
// What you write:
ssize_t n = read(fd, buf, count);

// What glibc does (simplified):
// mov rax, 0        ; syscall number for read
// mov rdi, fd
// mov rsi, buf
// mov rdx, count
// syscall
// cmp rax, 0
// jl  set_errno     ; if negative, set errno = -rax, return -1

// Linux kernel's sys_read():
SYSCALL_DEFINE3(read, unsigned int, fd, char __user *, buf, size_t, count)
{
    struct fd f = fdget_pos(fd);
    // ... validate, call vfs_read(), return bytes read or -errno
}
```

---

## 5. Process Management

### 5.1 Processes and Threads

In Linux, **processes and threads are the same kernel object**: the `task_struct`. What distinguishes a thread from a process is which resources it shares with its creator, controlled by flags passed to the `clone()` system call.

```c
// fork() — new process, all resources copied (copy-on-write)
clone(SIGCHLD, ...)

// pthread_create() — new thread, shares everything
clone(CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD, ...)
```

### 5.2 task_struct

Every process and thread is represented by a `task_struct` in the kernel. Key fields:

```c
struct task_struct {
    // Identity
    pid_t pid;               // process ID
    pid_t tgid;              // thread group ID (= pid of main thread)
    uid_t uid, euid, suid;   // real, effective, saved UIDs
    gid_t gid, egid, sgid;

    // State
    volatile long state;     // TASK_RUNNING, TASK_INTERRUPTIBLE, etc.
    int exit_code;

    // Scheduling
    int prio;                // dynamic priority
    int static_prio;         // nice-value-based priority
    unsigned int policy;     // SCHED_NORMAL, SCHED_FIFO, SCHED_RR, etc.
    struct sched_entity se;  // CFS scheduling entity

    // Memory
    struct mm_struct *mm;    // virtual address space (NULL for kernel threads)
    struct mm_struct *active_mm;

    // Files
    struct files_struct *files;    // open file descriptor table
    struct fs_struct *fs;          // root and working directory

    // Signals
    struct signal_struct *signal;
    struct sighand_struct *sighand;
    sigset_t blocked, pending;

    // Namespace
    struct nsproxy *nsproxy;       // namespace memberships

    // Cgroups
    struct css_set *cgroups;

    // Timing
    u64 utime, stime;              // user/kernel CPU time
    u64 start_time;

    // Relationships
    struct task_struct *parent;
    struct list_head children;
    struct list_head sibling;
};
```

### 5.3 Process States

```
         fork()
           │
           ▼
      TASK_RUNNING ◄─────────────────────────────┐
      (runnable)                                  │
           │                                      │
     scheduled out               scheduled in     │
     (waiting for CPU)      (CPU becomes available)│
           │                                      │
           ▼                                      │
      TASK_RUNNING ──── gets CPU ────────────────►┘
      (actually running)
           │
     blocks on I/O / event
           │
           ▼
   TASK_INTERRUPTIBLE   ← woken by signal OR event
   TASK_UNINTERRUPTIBLE ← woken ONLY by event (not signal) — shown as D in ps
           │
     event occurs
           │
           └──────────────────────► TASK_RUNNING (runnable)

      exit() or signal
           │
           ▼
       TASK_ZOMBIE (EXIT_ZOMBIE) ← parent must call wait() to reap
           │
       parent waits
           │
           ▼
         (removed)
```

```bash
# Process state column in ps:
# R  TASK_RUNNING (running or runnable)
# S  TASK_INTERRUPTIBLE (sleeping, woken by signal)
# D  TASK_UNINTERRUPTIBLE (waiting for I/O — cannot be killed)
# Z  Zombie (exited, not yet reaped)
# T  Stopped (by signal or debugger)
# I  Idle kernel thread

ps aux
# Or with a tree view:
ps auxf
```

### 5.4 Process Creation

```
fork() / clone()
│
├── Kernel creates a new task_struct
├── Copies parent's page tables (Copy-on-Write)
│     - Physical pages are shared, marked read-only
│     - Write to a shared page → page fault → kernel copies the page
│     - Child gets its own copy, write proceeds
├── File descriptor table copied (both share open files)
└── Returns twice:
      parent: returns child PID
      child:  returns 0

exec() (execve())
│
├── Kernel replaces the current process image
├── New binary loaded from disk
├── New virtual address space created
├── Stack, heap, data initialised fresh
└── Control transferred to new program entry point
    (parent's code and data are gone)
```

**Copy-on-Write (CoW)** is why `fork()` is fast even for large processes. A `fork()` of a 1 GiB process does not copy 1 GiB of RAM — it copies page table entries (a few MiB at most) and marks pages shared. Pages are only physically duplicated when written.

### 5.5 Namespaces

Linux namespaces isolate global resources so processes in different namespaces see different views of the system. They are the foundation of containers.

| Namespace | Flag | Isolates |
|---|---|---|
| Mount (`mnt`) | `CLONE_NEWNS` | Filesystem mount tree |
| Process ID (`pid`) | `CLONE_NEWPID` | PID numbering (PID 1 in container) |
| Network (`net`) | `CLONE_NEWNET` | Network interfaces, routing tables, firewall rules |
| UTS | `CLONE_NEWUTS` | Hostname and NIS domain name |
| IPC | `CLONE_NEWIPC` | System V IPC, POSIX message queues |
| User (`user`) | `CLONE_NEWUSER` | UID/GID mappings |
| Cgroup (`cgroup`) | `CLONE_NEWCGROUP` | cgroup root |
| Time | `CLONE_NEWTIME` | System clocks (Linux 5.6+) |

```bash
# See namespaces of a process
ls -la /proc/1/ns/

# Enter a namespace (e.g. Docker container)
nsenter --target $(docker inspect -f '{{.State.Pid}}' mycontainer) --mount --pid --net
```

---

## 6. Scheduling

The scheduler decides which `TASK_RUNNING` task gets CPU time next.

### 6.1 Scheduling Classes

Linux uses a **multi-class scheduler**. Each class has a priority over the one below it:

```
Stop class       — internal kernel stop task (highest)
Deadline class   — SCHED_DEADLINE: hard real-time deadlines
Real-time class  — SCHED_FIFO, SCHED_RR: soft real-time (priority 1–99)
Fair class       — SCHED_NORMAL, SCHED_BATCH, SCHED_IDLE: normal tasks
Idle class       — runs only when nothing else can (lowest)
```

A SCHED_FIFO task at priority 50 will **always** preempt a SCHED_NORMAL task, regardless of how long the normal task has been waiting.

### 6.2 CFS — Completely Fair Scheduler

**CFS** (introduced in Linux 2.6.23, 2007) is the scheduler for normal (`SCHED_NORMAL`) tasks. Its goal: give every runnable task an equal share of CPU time.

**Core concept — virtual runtime (`vruntime`):**

- Each task has a `vruntime` counter (nanoseconds).
- When a task runs, its `vruntime` increases proportionally to real time, weighted by its `nice` value.
- The scheduler always picks the task with the **lowest `vruntime`** — the one that has received the least CPU time relative to its weight.
- Tasks are stored in a **red-black tree** keyed by `vruntime` — O(log n) pick-next.

**Nice values and weights:**

```
nice -20  → weight 88761  (gets ~10× more CPU than nice 0)
nice   0  → weight  1024  (baseline)
nice  19  → weight    15  (gets ~1/70 of CPU compared to nice 0)
```

```bash
# Set nice value at launch
nice -n 10 /usr/bin/myapp

# Change nice of running process
renice -n 5 -p 1234

# View nice values
ps -eo pid,ni,comm
```

### 6.3 Real-time Scheduling

```bash
# Set a process to SCHED_FIFO at priority 50
chrt -f 50 /usr/bin/myapp

# Set to SCHED_RR (round-robin real-time)
chrt -r 50 /usr/bin/myapp

# View scheduling policy of a process
chrt -p 1234
```

`SCHED_FIFO`: A task runs until it voluntarily sleeps or a higher-priority task preempts it. Within the same priority, no preemption.

`SCHED_RR`: Like FIFO, but tasks at the same priority get a time slice (round-robin) rather than running indefinitely.

### 6.4 Load Balancing (SMP)

On multi-core systems, CFS runs a **load balancer** that migrates tasks between per-CPU run queues to keep all cores evenly loaded. It considers:

- CPU topology (NUMA nodes, L3 cache sharing, hyperthreading).
- Task CPU affinity (`taskset`, `sched_setaffinity`).
- Cache hotness — avoids migrating tasks whose cache is warm.

```bash
# Pin a process to CPU cores 0 and 1
taskset -c 0,1 /usr/bin/myapp

# View CPU affinity
taskset -cp 1234
```

### 6.5 Preemption Models

The kernel can be configured with different preemption behaviour:

| Model | Config | Latency | Throughput | Use Case |
|---|---|---|---|---|
| No forced preemption | `PREEMPT_NONE` | High | Highest | Servers, HPC |
| Voluntary preemption | `PREEMPT_VOLUNTARY` | Medium | High | Desktop (default) |
| Full preemption | `PREEMPT` | Low | Medium | Interactive systems |
| Real-time (PREEMPT_RT) | `PREEMPT_RT` | Very low | Lower | Industrial control |

```bash
# Check current preemption model
cat /boot/config-$(uname -r) | grep PREEMPT
```

---

## 7. Memory Management

The memory management subsystem (MM) is one of the most complex parts of the kernel, spanning several hundred thousand lines of code.

### 7.1 Physical Memory Organisation

Linux divides physical RAM into fixed-size **pages** (4 KiB on x86-64 by default; huge pages: 2 MiB, 1 GiB).

Physical memory is organised into **zones**:

| Zone | Address Range (x86-64) | Purpose |
|---|---|---|
| `ZONE_DMA` | 0–16 MiB | Legacy ISA DMA devices |
| `ZONE_DMA32` | 16 MiB–4 GiB | 32-bit DMA devices |
| `ZONE_NORMAL` | 4 GiB+ | Normal kernel allocations |
| `ZONE_HIGHMEM` | (32-bit only) | Memory above kernel's direct mapping |
| `ZONE_MOVABLE` | Configurable | Pages that can be migrated (for hotplug) |

### 7.2 The Buddy Allocator

The kernel allocates physical pages using the **buddy system**: free pages are tracked in 11 lists (orders 0–10), where order N holds blocks of 2ᴺ contiguous pages.

```
Order 0:  1 page  = 4 KiB
Order 1:  2 pages = 8 KiB
Order 2:  4 pages = 16 KiB
...
Order 10: 1024 pages = 4 MiB
```

**Allocation:** find the smallest order that satisfies the request; split if needed.
**Deallocation:** merge with the "buddy" (adjacent same-size block) back up to the largest possible order.

```bash
# View buddy allocator state
cat /proc/buddyinfo

# Example output:
# Node 0, zone  DMA32  5  4  3  2  2  1  1  1  0  1  2
# (columns = order 0 through 10; values = free blocks of that order)
```

### 7.3 The Slab Allocator

The buddy allocator works in page-sized chunks. For small kernel objects (task_struct, inode, dentry, socket), a second allocator sits on top: the **slab allocator** (modern implementation: **SLUB**).

SLUB maintains **per-object caches** for frequently allocated types:

- Objects of the same type are packed into slabs (one or more pages).
- Allocation = pop from a free list in the slab: O(1).
- No memory overhead for small objects (no per-allocation headers like malloc).
- Objects are initialised (constructor) once and reused — avoids re-initialisation cost.

```bash
# View slab caches
cat /proc/slabinfo

# More readable with slabtop
slabtop

# Example entries:
# task_struct     active/total: 312/350   object size: 9408 bytes
# inode_cache     active/total: 18432/20000  object size: 648 bytes
```

### 7.4 Virtual Memory and Paging

Each process has a **virtual address space** managed by page tables. The CPU's MMU (Memory Management Unit) translates virtual → physical addresses on every memory access using these tables.

On x86-64, page table translation is **4 levels** (5 levels on systems with 5-level paging enabled):

```
Virtual address (48 bits used):
  [63:48] sign extension
  [47:39] PGD index  (9 bits) → Page Global Directory
  [38:30] PUD index  (9 bits) → Page Upper Directory
  [29:21] PMD index  (9 bits) → Page Middle Directory
  [20:12] PTE index  (9 bits) → Page Table Entry
  [11:0]  Page offset (12 bits) → offset within 4 KiB page

Each level: 512 entries × 8 bytes = 4 KiB (fits in one page)
```

**TLB (Translation Lookaside Buffer):** hardware cache of recent virtual→physical translations. TLB misses trigger a page table walk (expensive: 4 memory accesses). The kernel minimises TLB misses via huge pages, process affinity, and careful TLB flush management.

### 7.5 Page Faults

A **page fault** is a CPU exception triggered when a virtual address cannot be resolved:

| Fault Type | Cause | Kernel Response |
|---|---|---|
| **Minor** | Page is in memory but not mapped (e.g. first access to anonymous page) | Map the page, no I/O needed |
| **Major** | Page is on disk (swapped out or file-backed not yet loaded) | I/O to read page from disk |
| **Invalid** | Access to unmapped or protected address | Send `SIGSEGV` to process |
| **Copy-on-Write** | Write to a shared (forked) page | Copy the page, remap, allow write |

```bash
# View page fault statistics per process
cat /proc/1234/stat    # fields 10 (minflt) and 12 (majflt)

# System-wide
vmstat 1               # si (swap in) and so (swap out) columns
```

### 7.6 Memory Allocators: kmalloc and vmalloc

Two primary kernel allocation APIs:

**`kmalloc(size, flags)`** — physically contiguous allocation (uses slab/SLUB):
- Fast, suitable for DMA (devices need contiguous physical memory).
- Limited to ~4 MiB practically.
- `GFP_KERNEL`: may sleep (can trigger page reclaim); use in process context.
- `GFP_ATOMIC`: never sleeps (use in interrupt handlers).

**`vmalloc(size)`** — virtually contiguous but physically scattered:
- Can allocate large regions (hundreds of MiB).
- Not suitable for DMA (pages may not be physically contiguous).
- Higher overhead (requires page table mapping).

```bash
# View vmalloc usage
cat /proc/vmallocinfo | head -20

# Summary
cat /proc/meminfo | grep Vmalloc
```

### 7.7 Memory Zones and Reclaim

When physical memory is low, the kernel **reclaims** pages:

```
Page reclaim priority (low memory → high memory pressure):
1. Drop clean page cache (file data already on disk — free immediately)
2. Write dirty page cache to disk, then free
3. Swap anonymous pages (process heap/stack) to swap device
4. OOM killer — kill a process to free memory (last resort)
```

**Page cache:** the kernel caches all file I/O in RAM. Reading a file twice returns the cached data. Dirty (modified) pages are written back asynchronously. On a system with 16 GiB RAM and 4 GiB of active processes, ~12 GiB may be page cache — this is normal and intentional.

```bash
# Memory overview
free -h
cat /proc/meminfo

# Drop caches (testing, not production)
echo 3 > /proc/sys/vm/drop_caches

# OOM killer log
dmesg | grep -i "killed process"
journalctl -k | grep "Out of memory"
```

### 7.8 Huge Pages

Huge pages (2 MiB or 1 GiB) reduce TLB pressure for large-memory applications:

**Static huge pages:**
```bash
# Allocate 512 huge pages (1 GiB total)
echo 512 > /proc/sys/vm/nr_hugepages

# View huge page pool
cat /proc/meminfo | grep Huge

# Mount hugetlbfs for explicit use
mount -t hugetlbfs none /mnt/huge
```

**Transparent Huge Pages (THP):** kernel automatically promotes anonymous pages to huge pages:
```bash
cat /sys/kernel/mm/transparent_hugepage/enabled
# [always] madvise never
```

---

## 8. Virtual File System (VFS)

The **VFS** is an abstraction layer that presents a unified interface for all filesystem operations, regardless of the underlying filesystem type.

### 8.1 VFS Architecture

```
User space:  open("/etc/hostname", O_RDONLY)
                        │
                   system call
                        │
              ┌─────────▼──────────┐
              │        VFS         │    ← unified kernel interface
              │  (generic layer)   │
              └────────┬───────────┘
                       │ dispatches to
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
      ext4          tmpfs          procfs
    (on disk)   (in RAM)      (virtual/kernel)
         │
         ▼
    Block layer → disk driver → physical disk
```

The same `read()`, `write()`, `open()`, `stat()` calls work identically on ext4, Btrfs, NFS, `/proc`, `/sys`, and a socket — the VFS routes them to the right implementation.

### 8.2 VFS Objects

| Object | struct | Description |
|---|---|---|
| **Superblock** | `super_block` | Mounted filesystem instance (metadata: block size, total inodes…) |
| **Inode** | `inode` | File metadata (size, timestamps, permissions, pointers to data blocks) |
| **Dentry** | `dentry` | Directory entry — maps a filename to an inode; cached in dcache |
| **File** | `file` | An open file — represents one process's open instance, with its own offset |

**Key relationships:**

```
/home/alice/report.pdf
│
├── dentry: "report.pdf" ──────────► inode 48291
│                                       │
│                                    ┌──┴──────────────────────────┐
│                                    │ mode: 0644                  │
│                                    │ size: 2,097,152             │
│                                    │ uid: 1000, gid: 1000        │
│                                    │ atime, mtime, ctime         │
│                                    │ data blocks: [4831, 4832…]  │
│                                    └─────────────────────────────┘
│
└── open() creates a `file` struct
       │
       ├── f_inode → inode 48291
       ├── f_pos   → current read/write position
       └── f_ops   → pointer to filesystem's read/write functions
```

### 8.3 The Dentry Cache (dcache)

Path resolution (`/home/alice/report.pdf`) involves looking up each component: `/`, `home`, `alice`, `report.pdf`. Each lookup is a potential disk read. The **dentry cache** keeps recently resolved path components in memory, making repeated access to the same paths fast (O(1) hash lookup instead of disk reads).

```bash
# Dentry cache statistics
cat /proc/sys/fs/dentry-state

# Force cache drop (testing)
echo 2 > /proc/sys/vm/drop_caches
```

### 8.4 Common Filesystems

| Filesystem | Type | Key Feature |
|---|---|---|
| **ext4** | Disk | Default on many distros; journalling; stable |
| **Btrfs** | Disk | CoW, snapshots, checksums, RAID, subvolumes |
| **XFS** | Disk | High performance at scale; parallel I/O |
| **ZFS** | Disk | CoW, RAID-Z, checksums; via DKMS module |
| **tmpfs** | RAM | Temporary storage in RAM; backed by swap |
| **procfs** | Virtual | Exposes kernel/process info via `/proc` |
| **sysfs** | Virtual | Exposes device and driver info via `/sys` |
| **devtmpfs** | Virtual | Populates `/dev` with device nodes |
| **NFS** | Network | Remote filesystem over TCP/UDP |
| **FUSE** | Userspace | Implement filesystems in user space (sshfs, overlayfs) |
| **OverlayFS** | Layering | Union of lower (read-only) + upper (writable) layers (containers) |

---

## 9. I/O and the Block Layer

### 9.1 The I/O Stack

```
Application
    │ read(fd, buf, len)
    ▼
VFS
    │
    ▼
Page Cache   ← if page is cached, return immediately (no disk I/O)
    │ (cache miss)
    ▼
Filesystem (ext4, Btrfs…)
    │ translates file offset → block addresses
    ▼
Block Layer
    ├── I/O scheduler (merges and reorders requests)
    ├── Device mapper (LVM, dm-crypt, dm-multipath)
    └── Block device driver (NVMe, SATA, SCSI, virtio-blk)
         │
         ▼
    Physical storage (SSD, HDD, NVMe)
```

### 9.2 I/O Schedulers

The I/O scheduler sits between the filesystem and the block driver. It **batches, merges, and reorders** I/O requests to maximise throughput and minimise latency.

| Scheduler | Best For | Algorithm |
|---|---|---|
| **none** | NVMe SSDs (have their own internal queue) | Pass-through, no reordering |
| **mq-deadline** | Mixed workloads, HDDs | Ensures requests don't starve; deadline per request |
| **BFQ** | Desktop, interactive | Budget Fair Queuing; low latency per process |
| **Kyber** | Fast NVMe with multiple queues | Token-bucket; low overhead |

```bash
# View current scheduler for a device
cat /sys/block/sda/queue/scheduler

# Change scheduler
echo mq-deadline > /sys/block/sda/queue/scheduler

# Permanent (via udev rule or kernel parameter)
# elevator=mq-deadline
```

### 9.3 Direct I/O and Buffered I/O

**Buffered I/O** (default): reads and writes go through the page cache. The kernel reads ahead and writes back asynchronously. Application sees high throughput; latency is hidden.

**Direct I/O** (`O_DIRECT`): bypasses page cache. Application owns buffer management. Used by databases (PostgreSQL, MySQL) that implement their own buffer pools and do not want double-caching.

**Memory-mapped I/O** (`mmap`): maps a file or device directly into the process's virtual address space. Accesses appear as memory reads/writes; the kernel handles paging in/out. Used by high-performance databases and JVMs.

### 9.4 /proc and /sys

**`/proc`** (procfs) — process and kernel information as a virtual filesystem:

```bash
/proc/cpuinfo            # CPU details
/proc/meminfo            # memory statistics
/proc/interrupts         # IRQ counts per CPU
/proc/net/               # network statistics
/proc/sys/               # tunable kernel parameters (sysctl)
/proc/<pid>/             # per-process information
/proc/<pid>/maps         # virtual memory map
/proc/<pid>/fd/          # open file descriptors
/proc/<pid>/status       # process state and resource usage
/proc/<pid>/cmdline      # command line
/proc/<pid>/environ      # environment variables
```

**`/sys`** (sysfs) — hardware, driver, and device information:

```bash
/sys/block/              # block devices
/sys/class/net/          # network interfaces
/sys/bus/pci/devices/    # PCI devices
/sys/kernel/mm/          # memory management tunables
/sys/module/             # loaded kernel modules and their parameters
/sys/firmware/efi/       # EFI variables (on UEFI systems)
```

---

## 10. Networking Stack

### 10.1 Layer Architecture

Linux implements the full TCP/IP stack inside the kernel, following the OSI model:

```
Application        write(fd, data, len) / send() / sendmsg()
                              │
Socket layer       struct socket → struct sock
                              │
Transport layer    TCP (tcp_sendmsg) / UDP (udp_sendmsg)
                              │
Network layer      IP routing → ip_output() → ip_finish_output()
                              │
Neighbour layer    ARP / NDP
                              │
Network device     dev_queue_xmit() → driver's ndo_start_xmit()
                              │
Hardware           NIC sends frame
```

### 10.2 The Socket Buffer (sk_buff)

The central data structure of the networking stack is `sk_buff` (socket buffer). A single network packet is represented as one `sk_buff` throughout its journey through all layers.

Each layer adds or removes headers by adjusting pointers into the buffer — no data copying needed:

```
sk_buff:
  head ──► [ethernet header | IP header | TCP header | data payload ] ◄── end
             ▲                 ▲           ▲            ▲
           mac_header        network_   transport_    data
                             header     header
```

### 10.3 Netfilter and iptables/nftables

**Netfilter** is the kernel packet filtering framework. It defines **hooks** at fixed points in the network stack where packets can be inspected, modified, or dropped.

```
PREROUTING → FORWARD → POSTROUTING     (for forwarded packets)
PREROUTING → INPUT                     (for packets destined for this host)
OUTPUT     → POSTROUTING               (for packets from this host)
```

`iptables`, `nftables`, and `firewalld` all write rules into Netfilter hooks.

```bash
# List firewall rules
iptables -L -n -v
nft list ruleset

# View connection tracking
conntrack -L
cat /proc/net/nf_conntrack
```

### 10.4 Network Observability

```bash
# Socket statistics
ss -tulnp                  # listening TCP/UDP sockets with PIDs
ss -s                      # summary statistics

# Interface statistics
ip -s link show eth0
cat /proc/net/dev

# Routing table
ip route show
ip route get 8.8.8.8       # what route would be used?

# ARP / neighbour table
ip neigh show

# Packet capture
tcpdump -i eth0 -n port 80
tcpdump -i eth0 -w capture.pcap
```

---

## 11. Kernel Modules and Drivers

### 11.1 What Is a Kernel Module?

A **kernel module** (`.ko` file — Kernel Object) is a compiled piece of kernel code that can be dynamically inserted into or removed from the running kernel without a reboot. Modules share the kernel's address space and have full kernel privileges.

Modules are used for: device drivers, filesystem implementations, network protocols, and security frameworks.

```bash
# List loaded modules
lsmod

# Example output:
# Module             Size  Used by
# nvidia          56291328  74
# e1000e            294912  0
# usbhid             57344  0
# hid               139264  1 usbhid

# Load a module
modprobe e1000e           # loads with dependencies
insmod /path/to/mymod.ko  # load specific file, no dependency resolution

# Remove a module
modprobe -r e1000e
rmmod e1000e

# Module information
modinfo e1000e
modinfo -F description e1000e

# Module parameters
modprobe e1000e InterruptThrottleRate=1000,1000
# Or at runtime:
echo 1000 > /sys/module/e1000e/parameters/InterruptThrottleRate
```

### 11.2 Module Loading at Boot

```bash
# Modules to load at boot
cat /etc/modules            # Debian/Ubuntu
cat /etc/modules-load.d/    # systemd-based systems

# Module options
cat /etc/modprobe.d/

# Example: /etc/modprobe.d/mydriver.conf
# options mydriver param1=1 param2=0
# blacklist nouveau            # prevent a module from loading
# install nouveau /bin/false   # redirect install to /bin/false (hard block)
```

**Automatic loading:** most modules are loaded automatically via **udev**. When the kernel detects hardware (via PCI IDs, USB IDs, etc.), it emits a `modalias` string. udev calls `modprobe` with that alias, loading the right driver automatically.

```bash
# See modalias for a device
cat /sys/bus/pci/devices/0000:00:1f.2/modalias
# pci:v00008086d00001E03sv000017AAsd000021F6bc01sc06i01

# Find which module handles this modalias
modprobe --resolve-alias pci:v00008086d00001E03sv000017AAsd000021F6bc01sc06i01
# ahci
```

### 11.3 Module Structure

A minimal kernel module:

```c
// hello.c — minimal kernel module

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A minimal example module");
MODULE_VERSION("1.0");

static int __init hello_init(void)
{
    printk(KERN_INFO "hello: module loaded\n");
    return 0;   /* 0 = success; negative = error */
}

static void __exit hello_exit(void)
{
    printk(KERN_INFO "hello: module removed\n");
}

module_init(hello_init);
module_exit(hello_exit);
```

```makefile
# Makefile
obj-m += hello.o
KDIR := /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```

```bash
make
insmod hello.ko
dmesg | tail -3      # see "hello: module loaded"
rmmod hello
```

### 11.4 Driver Model

Kernel drivers interface between the kernel's generic subsystems and physical hardware. The driver model has three components:

**Bus:** the physical or logical bus a device connects to (PCI, USB, I2C, SPI, platform).
**Device:** represents a specific hardware instance (struct `device`, `pci_dev`, `usb_device`).
**Driver:** code that manages a class of devices (struct `pci_driver`, `usb_driver`).

When a device is detected, the kernel matches it against registered drivers using IDs. The matched driver's `probe()` function is called:

```c
static struct pci_driver my_driver = {
    .name       = "my_pci_driver",
    .id_table   = my_pci_ids,     /* PCI vendor/device ID table */
    .probe      = my_probe,        /* called when device found */
    .remove     = my_remove,       /* called when device removed */
    .suspend    = my_suspend,
    .resume     = my_resume,
};

static int my_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
    // Claim the device, map BARs, initialise hardware, register with subsystem
    pci_enable_device(pdev);
    pci_request_regions(pdev, "my_driver");
    // ...
    return 0;
}
```

### 11.5 Character and Block Devices

**Character devices** (`/dev/tty`, `/dev/null`, `/dev/random`): accessed as byte streams; no seek; implement `open`, `read`, `write`, `ioctl`.

**Block devices** (`/dev/sda`, `/dev/nvme0n1`): random access in fixed-size blocks; support filesystems; go through the block I/O layer.

```bash
# List device files with type
ls -la /dev/ | head -20
# c = character device (c rw-rw-rw- ... /dev/null)
# b = block device    (b rw-rw---- ... /dev/sda)

# Major/minor numbers
ls -la /dev/sda /dev/sda1
# brw-rw---- 1 root disk 8, 0 /dev/sda   ← major 8, minor 0
# brw-rw---- 1 root disk 8, 1 /dev/sda1  ← major 8, minor 1
```

---

## 12. Interrupt Handling

### 12.1 What Is an Interrupt?

An **interrupt** is a signal from hardware (or software) that causes the CPU to stop its current work, save state, and execute an **interrupt handler** (ISR — Interrupt Service Routine).

Types:

| Type | Source | Example |
|---|---|---|
| Hardware IRQ | Device signals CPU | NIC receives packet, disk I/O complete, keyboard press |
| Software interrupt (softirq) | Kernel defers work from IRQ | Network packet processing, timer handling |
| Tasklet | Soft, non-concurrent | Driver deferred work |
| Workqueue | Kernel threads | I/O completion, deferred driver work (can sleep) |
| Exceptions | CPU detects condition | Page fault, divide by zero, invalid opcode |
| System call | `syscall` instruction | User program requests kernel service |

### 12.2 Top Half / Bottom Half

IRQ handlers must be **fast** — while an IRQ handler runs, the same IRQ is masked (and often all IRQs). The Linux solution: split handling into two halves.

**Top half (hard IRQ context):**
- Runs immediately when IRQ fires.
- Minimal work: acknowledge the interrupt, copy data from device registers.
- Cannot sleep, cannot call blocking functions.
- Schedules the bottom half.

**Bottom half (deferred):**
- Runs with IRQs re-enabled, in a softer context.
- Does the bulk of processing (packet parsing, disk completion callbacks).
- Three mechanisms: **softirqs** (fixed types, run on same CPU), **tasklets** (built on softirqs, serialised), **workqueues** (kernel threads, can sleep).

```bash
# View interrupt statistics
cat /proc/interrupts

# Example:
#            CPU0       CPU1
#   0:       18         0    IO-APIC   2-edge    timer
#  16:        0         0    IO-APIC  16-fasteoi  ehci_hcd:usb1
#  24:    45312      3219    PCI-MSI 327680-edge  xhci_hcd
# NMI:        2         1    Non-maskable interrupts
# LOC:   483921    512000    Local timer interrupts

# View softirq statistics
cat /proc/softirqs
```

### 12.3 Interrupt Affinity

On SMP systems, IRQs can be pinned to specific CPUs to improve cache locality or isolate latency-sensitive processing:

```bash
# View affinity of IRQ 24
cat /proc/irq/24/smp_affinity         # bitmask
cat /proc/irq/24/smp_affinity_list    # human-readable

# Pin IRQ 24 to CPU 0 only
echo 1 > /proc/irq/24/smp_affinity   # CPU 0 bitmask = 0x1

# irqbalance daemon distributes IRQs automatically
systemctl status irqbalance
```

---

## 13. Synchronisation Primitives

The kernel runs concurrently on multiple CPUs with interrupts firing at any moment. Shared data structures must be protected.

### 13.1 Spinlocks

A **spinlock** is the fundamental kernel lock. A thread waiting for a spinlock **busy-waits** (spins) — it does not sleep. Used when the lock will be held for a very short time and sleeping is not allowed (e.g. interrupt context).

```c
spinlock_t my_lock;
spin_lock_init(&my_lock);

spin_lock(&my_lock);
    /* critical section — cannot sleep here */
    shared_data++;
spin_unlock(&my_lock);

/* IRQ-safe variant (disables local interrupts) */
unsigned long flags;
spin_lock_irqsave(&my_lock, flags);
    shared_data++;
spin_unlock_irqrestore(&my_lock, flags);
```

### 13.2 Mutexes and Semaphores

**Mutexes** can sleep — a thread that cannot acquire the mutex is put to sleep and woken when the mutex is released. Used in process context where sleeping is acceptable.

```c
struct mutex my_mutex;
mutex_init(&my_mutex);

mutex_lock(&my_mutex);    /* may sleep */
    /* critical section */
mutex_unlock(&my_mutex);
```

**Semaphores** generalise mutexes — a counting semaphore with N allows N concurrent holders. Rarely used in modern kernel code (mutexes preferred for mutual exclusion).

### 13.3 RCU (Read-Copy-Update)

**RCU** is a high-performance synchronisation mechanism optimised for **read-heavy workloads**. Readers take no lock at all — reads are wait-free. Writers make a copy of the data, modify the copy, atomically replace the pointer, then wait for all pre-existing readers to finish before freeing the old copy.

Used extensively in the kernel for: routing tables, process list traversal, file system dentries, network filtering rules.

```c
/* Reader — no locking, just RCU read-side lock */
rcu_read_lock();
    p = rcu_dereference(global_ptr);
    if (p)
        use(p->data);
rcu_read_unlock();

/* Writer — copy, modify, publish, then wait for readers */
new_p = kmalloc(sizeof(*new_p), GFP_KERNEL);
*new_p = *old_p;
new_p->data = new_value;
rcu_assign_pointer(global_ptr, new_p);
synchronize_rcu();   /* wait for all readers of old_p to finish */
kfree(old_p);
```

### 13.4 Atomic Operations

For simple shared counters, atomic operations avoid the overhead of full locks:

```c
atomic_t counter = ATOMIC_INIT(0);

atomic_inc(&counter);
atomic_dec(&counter);
int val = atomic_read(&counter);
atomic_add(5, &counter);
int old = atomic_xchg(&counter, 0);  /* swap, return old value */
```

These compile to single hardware instructions (`LOCK XADD`, `LOCK CMPXCHG`) that are atomic on SMP without any software lock.

---

## 14. Versioning and Configuration

### 14.1 Kernel Version Numbers

```
6  .  12  .  3
│     │      └── Stable patch (bug fixes only)
│     └───────── Minor version
└─────────────── Major version

6.12.3-rc2        — release candidate
6.12.3-generic    — Ubuntu packaging suffix
6.12.3-200.fc41   — Fedora packaging suffix
```

```bash
uname -r          # running kernel version
uname -a          # full kernel info + hostname + arch
```

**Kernel flavours (Ubuntu example):**

| Flavour | Use Case |
|---|---|
| `generic` | Standard desktops and servers |
| `lowlatency` | Audio production, real-time |
| `virtual` | Cloud/VM guests (no hardware drivers) |
| `aws` / `azure` / `gcp` | Cloud-provider optimised |
| `hwe` | Hardware Enablement — newer kernel on LTS base |

### 14.2 Kernel Configuration

The kernel has ~16,000 configurable options stored in `.config`. Configuration is done with:

```bash
# Text UI (requires libncurses)
make menuconfig

# Graphical Qt UI
make xconfig

# Command line
make config

# Update a .config for a new kernel version (preserves existing choices)
make olddefconfig

# Start from a minimal config (only what's needed to boot)
make tinyconfig

# Copy current running kernel's config
cp /boot/config-$(uname -r) .config
zcat /proc/config.gz > .config    # if CONFIG_IKCONFIG_PROC=y
```

Key config prefixes:

```
CONFIG_EXT4_FS=y         # built-in (compiled into vmlinuz)
CONFIG_EXT4_FS=m         # module (compiled as .ko, loaded on demand)
# CONFIG_EXT4_FS is not set  # disabled
```

### 14.3 Building and Installing a Custom Kernel

```bash
# Dependencies (Debian/Ubuntu)
apt install build-essential libncurses-dev bison flex libssl-dev libelf-dev

# Get source
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz
tar -xf linux-6.12.tar.xz
cd linux-6.12

# Configure (start from current running config)
cp /boot/config-$(uname -r) .config
make olddefconfig

# Build (use all CPU cores)
make -j$(nproc)

# Install modules
make modules_install

# Install kernel and initramfs
make install        # copies vmlinuz, System.map, updates bootloader
```

### 14.4 sysctl — Runtime Kernel Parameters

Many kernel behaviours are tunable at runtime via `/proc/sys/` (or `sysctl`):

```bash
# View all parameters
sysctl -a

# Read a parameter
sysctl vm.swappiness
cat /proc/sys/vm/swappiness

# Set temporarily (lost on reboot)
sysctl -w vm.swappiness=10
echo 10 > /proc/sys/vm/swappiness

# Set permanently
echo "vm.swappiness = 10" >> /etc/sysctl.d/99-custom.conf
sysctl -p /etc/sysctl.d/99-custom.conf
```

**Important tunables:**

| Parameter | Default | Meaning |
|---|---|---|
| `vm.swappiness` | 60 | Tendency to swap (0 = avoid, 100 = aggressive) |
| `vm.dirty_ratio` | 20 | % RAM that can be dirty before blocking writes |
| `vm.overcommit_memory` | 0 | Memory overcommit policy |
| `net.core.somaxconn` | 4096 | Max socket listen backlog |
| `net.ipv4.ip_forward` | 0 | Enable IP routing (set to 1 for routers/containers) |
| `kernel.pid_max` | 32768 | Maximum PID value |
| `kernel.perf_event_paranoid` | 2 | Who can use perf events |
| `fs.inotify.max_user_watches` | 8192 | Max inotify watches per user |

---

## 15. Observability and Debugging

### 15.1 /proc and /sys

```bash
# Process memory map
cat /proc/1234/maps
pmap -x 1234

# Open file descriptors
ls -la /proc/1234/fd
lsof -p 1234

# CPU and memory summary
cat /proc/cpuinfo
cat /proc/meminfo
cat /proc/loadavg          # 1/5/15 min load, running/total tasks, last PID

# Kernel messages
dmesg -T                   # with human-readable timestamps
dmesg --level=err,warn
dmesg -w                   # follow (like tail -f)
```

### 15.2 Performance Tools

```bash
# CPU usage by process
top
htop

# CPU usage per CPU core
mpstat -P ALL 1

# I/O statistics
iostat -x 1                # extended I/O stats per device
iotop                      # I/O by process

# Memory
vmstat 1                   # virtual memory stats (paging, swapping, CPU)
free -h

# Network
sar -n DEV 1               # network interface stats
nethogs                    # bandwidth per process

# System-wide performance
sar -u 1 10                # CPU 10 samples 1 second apart
```

### 15.3 perf — Linux Performance Counter Tool

`perf` uses hardware performance counters and kernel tracepoints:

```bash
# CPU cycles consumed by a command
perf stat ls

# Record a CPU profile for 30 seconds
perf record -g -p 1234 sleep 30

# View the recorded profile
perf report

# System-wide profile (all CPUs, 10 seconds)
perf record -ag sleep 10
perf report

# Count specific events
perf stat -e cache-misses,cache-references,instructions ls

# Top-like view of kernel functions
perf top
```

### 15.4 eBPF — Extended Berkeley Packet Filter

**eBPF** is one of the most significant additions to the modern Linux kernel. It allows running sandboxed programs inside the kernel — attached to tracepoints, kprobes, network hooks — without modifying kernel source or loading a module.

```bash
# Install BCC tools (eBPF frontends)
apt install bpfcc-tools   # Debian/Ubuntu

# Trace system calls
opensnoop                  # trace open() calls
execsnoop                  # trace exec() calls
bindsnoop                  # trace bind() calls

# I/O latency histogram
biolatency                 # block I/O latency distribution

# Network
tcptracer                  # trace TCP connects/accepts
tcpretrans                 # trace TCP retransmits

# Profiling
profile-bpfcc -F 99 30     # CPU flame graph data, 30 seconds
```

**bpftrace** — high-level eBPF scripting:

```bash
# Trace write() calls showing filename and size
bpftrace -e 'tracepoint:syscalls:sys_enter_write { printf("%s %d\n", comm, args->count); }'

# Histogram of read() return values
bpftrace -e 'tracepoint:syscalls:sys_exit_read { @[comm] = hist(args->ret); }'

# Count syscalls by process
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'
```

### 15.5 ftrace — Function Tracing

**ftrace** is a kernel-internal tracing framework accessible via `/sys/kernel/debug/tracing/`:

```bash
# Mount debugfs if not mounted
mount -t debugfs none /sys/kernel/debug

# Available tracers
cat /sys/kernel/debug/tracing/available_tracers
# function function_graph blk mmiotrace nop

# Trace all kernel functions called during a command
echo function > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/tracing_on
ls /tmp
echo 0 > /sys/kernel/debug/tracing/tracing_on
cat /sys/kernel/debug/tracing/trace | head -50

# Function graph tracer (shows call tree with durations)
echo function_graph > /sys/kernel/debug/tracing/current_tracer
```

`trace-cmd` provides a friendlier interface to ftrace:

```bash
trace-cmd record -p function_graph -g do_sys_open ls
trace-cmd report
```

### 15.6 Kernel Oops and Panics

A **kernel oops** is a recoverable kernel error — the offending code path is killed, but the system continues. A **kernel panic** is unrecoverable — the system halts.

Both produce a **stack trace** in `dmesg`:

```
[ 1234.567890] BUG: unable to handle kernel NULL pointer dereference at (null)
[ 1234.567891] IP: [<ffffffffc0a1b234>] my_driver_read+0x34/0x80 [my_driver]
[ 1234.567892] PGD 0
[ 1234.567893] Oops: 0002 [#1] SMP
...
[ 1234.567900] Call Trace:
[ 1234.567901]  [<ffffffff81234567>] vfs_read+0x97/0x150
[ 1234.567902]  [<ffffffff81235678>] sys_read+0x55/0xa0
```

```bash
# Decode an oops stack trace (converts addresses to symbols)
# Requires: kernel-devel package with vmlinux or System.map

# addr2line approach
addr2line -e vmlinux ffffffffc0a1b234

# scripts/decode_stacktrace.sh (from kernel source)
dmesg | scripts/decode_stacktrace.sh vmlinux

# kdump — capture a kernel crash dump
# Install: apt install kdump-tools crash
# Boot parameter: crashkernel=256M
crash vmlinux /var/crash/vmcore
```

---

## 16. Reference Summary

### Kernel Subsystem Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Linux Kernel                                 │
│                                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐  ┌────────────┐  │
│  │   Process   │  │    Memory    │  │   VFS    │  │  Network   │  │
│  │  Scheduler  │  │  Management  │  │  Layer   │  │   Stack    │  │
│  │    (CFS)    │  │ (MM/SLUB/    │  │(ext4,    │  │(TCP/IP,   │  │
│  │  Namespaces │  │  buddy/swap) │  │ Btrfs,   │  │ Netfilter) │  │
│  │  Cgroups    │  │  Page cache  │  │ tmpfs…)  │  │            │  │
│  └─────────────┘  └──────────────┘  └──────────┘  └────────────┘  │
│                                                                     │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐  ┌────────────┐  │
│  │   System    │  │   Interrupt  │  │  Block   │  │  Security  │  │
│  │   Calls     │  │   Handling   │  │  Layer   │  │(LSM, SEL,  │  │
│  │  Interface  │  │ (IRQ/softirq │  │(I/O sched│  │  AppArmor, │  │
│  │             │  │  /workqueue) │  │ DM/LVM)  │  │  seccomp)  │  │
│  └─────────────┘  └──────────────┘  └──────────┘  └────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │            Device Drivers (char, block, net, GPU…)          │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │     Architecture Code (arch/x86, arch/arm64, arch/riscv…)  │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Key /proc Paths

| Path | Content |
|---|---|
| `/proc/cpuinfo` | CPU model, cores, flags |
| `/proc/meminfo` | RAM usage, buffers, cache |
| `/proc/interrupts` | IRQ counts per CPU |
| `/proc/loadavg` | 1/5/15 min load averages |
| `/proc/slabinfo` | Slab allocator cache stats |
| `/proc/buddyinfo` | Buddy allocator free pages |
| `/proc/sys/` | Tunable kernel parameters |
| `/proc/<pid>/maps` | Process virtual memory map |
| `/proc/<pid>/status` | Process state, memory, threads |
| `/proc/<pid>/fd/` | Open file descriptors |

### Essential Kernel Commands

```bash
# Version and build info
uname -r; uname -a

# Modules
lsmod; modinfo <mod>; modprobe <mod>; modprobe -r <mod>

# Messages
dmesg -T; dmesg -w; dmesg -l err

# Parameters
sysctl -a; sysctl -w key=val

# Process insight
cat /proc/<pid>/status; cat /proc/<pid>/maps; lsof -p <pid>

# Memory
free -h; vmstat 1; cat /proc/meminfo; slabtop

# I/O
iostat -x 1; iotop; cat /sys/block/sda/queue/scheduler

# Network
ss -tulnp; cat /proc/net/dev; ip route; tcpdump -i eth0

# Performance
perf stat <cmd>; perf top; perf record -g; bpftrace; strace -c <cmd>

# Scheduling
chrt -p <pid>; taskset -c 0,1 <cmd>; ps -eo pid,ni,psr,comm
```

---

*Document targets Linux kernel 6.x on x86-64. ARM64 and RISC-V architectures follow the same subsystem design with architecture-specific differences in page table layout, interrupt controllers, and boot protocol.*