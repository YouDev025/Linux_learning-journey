# Logs and Metrics

A reference guide to collecting and interpreting logs and metrics on Linux, with a focus on building a workflow that genuinely supports both troubleshooting and security monitoring — not just data collection for its own sake.

---

## 🧱 Two Goals, One Pipeline

Logs and metrics serve **two distinct but overlapping purposes** that are easy to conflate:

| Goal | Primary question | Primary audience |
|---|---|---|
| **Troubleshooting** | "Why did this break, and how do I fix it?" | Operators, engineers |
| **Security monitoring** | "Did something happen that shouldn't have, and who did it?" | Security/audit-focused review |

The same underlying data — system logs, application logs, resource metrics — often serves both purposes, but the *retention*, *access controls*, and *alerting* built around it need to account for both uses, not just whichever one motivated the initial setup. A logging pipeline built purely for troubleshooting (short retention, broad access, no tamper protection) is poorly suited for security review; one built purely for security (locked down, long retention, restricted access) can be cumbersome for routine operational debugging. A good workflow deliberately serves both.

---

## 🌐 Centralized Logging: Why and How

### The Single-Host Limitation

Everything in the *Logs and journald* guide works well for **one host** — `journalctl -u nginx` is fast and precise when you're logged into that specific machine. This breaks down the moment you have more than a handful of hosts: an incident affecting a load-balanced service might have logs scattered across ten different machines, and manually SSHing into each one to check `journalctl` doesn't scale, especially under time pressure during an active incident.

### The Centralization Pattern

```
Host A (journald) ──┐
Host B (journald) ──┼──forward──> Central log store ──> Query/search/dashboard layer
Host C (journald) ──┘
```

Centralizing logs means every host ships its logs to a shared destination, where they can be searched, correlated, and retained **independent of any individual host's lifecycle** — critical when a compromised or crashed host might have its local logs tampered with or lost entirely (see the tamper-resistance discussion below).

### Common Forwarding Mechanisms

```bash
# journald can forward to syslog, which can then forward onward (see the Logs and journald guide)
# /etc/systemd/journald.conf
ForwardToSyslog=yes
```

```bash
# rsyslog forwarding to a remote collector
# /etc/rsyslog.conf
*.* @@logserver.internal:514      # @@  = TCP (reliable); @ alone = UDP (faster, can drop messages)
```

```yaml
# A Promtail (Loki's shipping agent) config snippet — see the Monitoring Basics guide
scrape_configs:
  - job_name: system
    static_configs:
      - targets: [localhost]
        labels:
          job: varlogs
          __path__: /var/log/*.log
```

| Mechanism | Notes |
|---|---|
| `rsyslog`/`syslog-ng` forwarding | Long-established, widely supported, simple TCP/UDP forwarding |
| `journald` → syslog → remote | Leverages existing syslog infrastructure for journald-managed logs |
| Dedicated shipping agents (Promtail, Filebeat, Fluentd) | Purpose-built for forwarding into modern log aggregation stacks (Loki, Elasticsearch) |
| `systemd-journal-upload`/`-remote` | journald's own native remote-upload mechanism, less common but avoids a syslog intermediary |

> **TCP vs. UDP forwarding matters:** UDP (`@`) forwarding is simpler and lower-overhead, but can silently drop log messages under network congestion or packet loss — for logs you might need for security review or compliance, prefer TCP (`@@`) or a shipping agent with built-in retry/acknowledgment, where the cost of a dropped log message is higher than the cost of slightly more overhead.

### Why Tamper Resistance Matters for Security Use

If an attacker compromises a host, **local logs on that same host are not trustworthy** — a sufficiently capable attacker can edit or delete them to cover their tracks. Centralizing logs to a separate system, ideally one the compromised host can only *write* to (not read back or modify after the fact), is a meaningful security control in its own right, independent of the operational convenience of centralization.

```
Local-only logging:
   Compromised host → logs live ON that host → attacker can edit/delete them

Centralized, write-only forwarding:
   Compromised host → forwards logs OUT → attacker can stop NEW logs,
   but can't retroactively alter what's already landed on the central store
```

> **Tip:** For genuinely security-sensitive environments, configure log shipping such that hosts have no read/delete access to the central store — only append/write. This connects directly to the audit logging concerns raised in the *Linux Audit and Hardening* guide: an audit trail that the audited system itself can erase provides much weaker assurance than one it can't touch.

---

## 📈 System Metrics and Resource Counters

### Where the Kernel Exposes Raw Metrics

Before any monitoring tool gets involved, the Linux kernel itself exposes a wealth of resource data directly through the `/proc` and `/sys` virtual filesystems — this is the actual source data that tools like `top`, `node_exporter`, and `vmstat` all ultimately read from.

```bash
cat /proc/loadavg                  # load average (see the Signals and Scheduling guide)
cat /proc/meminfo                    # detailed memory statistics
cat /proc/stat                         # CPU time breakdown, boot time, process counts
cat /proc/diskstats                      # per-disk I/O statistics
cat /proc/net/dev                          # per-interface network statistics
```

### Interactive Tools: Reading Resource Counters Live

```bash
top                  # classic, near-universal process/resource viewer
htop                   # friendlier, colorized alternative (if installed)
vmstat 2                 # virtual memory/CPU/IO stats, refreshed every 2 seconds
iostat -x 2                # detailed per-disk I/O statistics
mpstat -P ALL 2               # per-CPU-core utilization breakdown
free -h                         # memory usage, human-readable
```

### Interpreting Key Metrics

#### CPU

```bash
mpstat 2
```

```
CPU    %usr   %sys  %iowait   %idle
all    23.4   8.1     2.3      66.2
```

| Field | Meaning |
|---|---|
| `%usr` | Time spent in user-space processes |
| `%sys` | Time spent in kernel/system calls |
| `%iowait` | Time spent waiting on I/O — high values suggest a storage bottleneck, not necessarily a CPU one |
| `%idle` | Genuinely idle time |

> **A common misreading:** high `%iowait` is sometimes mistaken for a CPU problem, when it actually indicates the CPU is sitting idle, waiting on slow disk/network I/O — the fix is almost always storage/network-focused, not CPU-focused. See the *Block Devices* and *Linux Network Tools* guides for the actual diagnostic next steps in that direction.

#### Memory

```bash
free -h
```

```
              total        used        free      shared  buff/cache   available
Mem:           16Gi        4.2Gi       2.1Gi       0.3Gi       9.4Gi        11Gi
```

> **The classic memory-reading mistake:** "free" looking low isn't necessarily a problem — Linux deliberately uses otherwise-idle memory for disk **cache** (`buff/cache`), since cached data speeds up subsequent access and gets reclaimed instantly if an application actually needs that memory. The `available` column is the more meaningful number — it represents memory genuinely available for new allocations, accounting for reclaimable cache.

#### Disk I/O

```bash
iostat -x 2
```

```
Device   r/s    w/s    rkB/s    wkB/s   await  %util
sda       12.3   45.2    340.1   2048.3   8.4    62.1
```

| Field | Meaning |
|---|---|
| `await` | Average time (ms) for I/O requests to complete — rising values suggest the disk is struggling to keep up |
| `%util` | Percentage of time the device was busy servicing requests — consistently near 100% suggests the disk is a bottleneck |

#### Network

```bash
ss -s                       # socket summary statistics
cat /proc/net/dev             # per-interface byte/packet counters
```

```bash
sar -n DEV 2          # network throughput per interface, if sysstat is installed
```

### Why Raw Counters Aren't Enough on Their Own

A single snapshot of any of these metrics has limited value without **context** — is `iowait` of 15% normal for this workload, or a clear anomaly? This is precisely why dedicated monitoring tools (see the *Monitoring Basics* guide) collect these same underlying counters **continuously**, building a historical baseline that makes "is this normal" an answerable question rather than a guess based on a single point-in-time read.

---

## 🗄️ Log Retention and Aggregation

### Retention: How Long, and Why It Varies by Purpose

| Log type / purpose | Typical retention consideration |
|---|---|
| Operational/debugging logs | Days to a few weeks — mostly useful for recent troubleshooting |
| Security/audit logs | Often months to years — driven by compliance requirements, incident investigation windows, and the reality that breaches are frequently discovered long after they occurred |
| Compliance-mandated logs | Whatever the specific regulatory framework requires (varies significantly — PCI-DSS, HIPAA, SOC 2, and others each specify different minimums) |

> **Why security logs need longer retention than operational logs:** a typical troubleshooting need ("why did this crash an hour ago") is resolved quickly, and old debug logs lose relevance fast. A security investigation, by contrast, frequently needs to reconstruct events from **weeks or months before** a breach was actually discovered — attacker dwell time (the gap between initial compromise and detection) is often measured in months in real-world incidents, which is precisely why short retention windows can leave security teams with literally nothing to investigate by the time an incident is discovered.

### Configuring Retention

```bash
# journald — see the Logs and journald guide for the full breakdown
# /etc/systemd/journald.conf
[Journal]
MaxRetentionSec=1month
SystemMaxUse=2G
```

```
# logrotate — for traditional flat-file logs
/var/log/nginx/*.log {
    daily
    rotate 90        # keep 90 daily rotations ≈ 90 days
    compress
}
```

```yaml
# Loki retention config example
limits_config:
  retention_period: 2160h   # 90 days, expressed in hours
```

> **Tip:** Compression (`compress` in logrotate, or built into most centralized log stores) substantially reduces the storage cost of longer retention — extending retention from weeks to months is often far cheaper than it initially sounds, especially for compressible plain-text logs.

### Aggregation: Bringing It Together for Actual Use

Centralization (covered above) gets logs to one place; **aggregation** in the broader sense also means structuring and indexing that data so it's actually searchable and correlatable — not just a larger pile of the same scattered text files.

```bash
# Without aggregation: manually grep across files, one host/file at a time
grep "user_id=12345" /var/log/app/*.log

# With aggregation: query across ALL hosts/services/time at once
# (conceptually, via a tool like Grafana/Loki or Kibana — see the Monitoring Basics guide)
```

### Combining Logs and Metrics in a Single Workflow

A genuinely useful operational/security workflow uses metrics to **detect** something worth investigating, then logs to **explain** it — exactly the pattern introduced in the *Monitoring Basics* guide's metrics/logs/traces discussion, applied specifically here:

```
1. Metric anomaly detected: "Failed login rate spiked 50x in the last 10 minutes"
2. Pivot to logs, scoped to that exact time window and the relevant host(s)/service
3. journalctl/centralized log query: "show me failed SSH auth attempts in this window"
4. Identify: a single source IP attempting many usernames — likely a brute-force attempt
5. Cross-reference with the User Security guide's pam_faillock lockout status for affected accounts
6. Take action: confirm accounts are appropriately locked/rate-limited, consider firewall-level
   blocking of the source (see the Firewall Hardening guide), and log this as a security event
```

> **The throughline:** this workflow only works if both halves are actually in place — metrics that surface an anomaly worth investigating, and logs with sufficient retention and detail to actually explain what happened once you go looking. Either half alone leaves a gap: metrics without adequate logs tell you *something* happened but not *what*; logs without metrics-driven alerting mean no one necessarily goes looking until it's too late.

---

## 🔒 Access Control for Logs and Metrics Themselves

A point easy to overlook: log and metrics data is itself sensitive and deserves the same access-control thinking applied throughout this series.

```bash
ls -l /var/log/auth.log
# -rw-r----- 1 syslog adm     ...    auth.log
```

> **Why this matters:** logs frequently contain sensitive details — usernames, IP addresses, sometimes inadvertently logged secrets or tokens, and certainly enough detail to map out a system's internal structure and behavior. Treating a centralized log store as "just operational data" and leaving it broadly readable contradicts the least-privilege principle covered in the *Linux Security Principles* guide — apply the same access-restriction thinking here as anywhere else handling sensitive data.

```bash
# Restricting access to a centralized log query interface, conceptually
# (specific mechanism varies — Grafana/Kibana user roles, network-level restriction, etc.)
```

---

## ⚡ Quick Reference

| Task | Command/Concept |
|---|---|
| View raw kernel-level CPU/memory stats | `cat /proc/stat`, `cat /proc/meminfo` |
| Live resource overview | `top` / `htop` |
| Memory, with the meaningful "available" figure | `free -h` |
| Per-CPU breakdown, including iowait | `mpstat -P ALL 2` |
| Disk I/O detail (await, %util) | `iostat -x 2` |
| Network interface stats | `cat /proc/net/dev`, `sar -n DEV 2` |
| Forward journald logs to syslog | `ForwardToSyslog=yes` in `journald.conf` |
| Reliable remote forwarding | `@@host:port` (TCP) in rsyslog, vs. `@` (UDP) |
| Configure journald retention | `MaxRetentionSec=`, `SystemMaxUse=` in `journald.conf` |
| Configure flat-file log retention | `rotate N` in a logrotate config |

---

## 💡 Best Practices

- Design log/metrics retention and access control around BOTH troubleshooting and security needs — a setup optimized purely for one tends to underserve the other.
- Centralize logs off of individual hosts, especially for anything security-relevant — local-only logs on a compromised host are not trustworthy, since an attacker with sufficient access can alter or delete them.
- Prefer TCP-based or acknowledged log forwarding over plain UDP for anything you can't afford to silently lose, even though UDP is simpler and lower-overhead.
- Read `free -h`'s `available` column, not just `free` — high `buff/cache` usage is normal, reclaimable, and not itself a sign of memory pressure.
- Distinguish `%iowait` from genuine CPU load when diagnosing performance issues — high iowait points toward storage/network bottlenecks, not CPU capacity.
- Set security/audit log retention meaningfully longer than operational log retention — real-world attacker dwell time often exceeds typical short operational retention windows, leaving nothing to investigate if retention is too short.
- Treat centralized log/metrics stores as sensitive data requiring their own access controls — they frequently contain enough detail to map system structure and behavior, and sometimes inadvertently logged secrets.
- Build workflows that move fluidly between metrics (detect) and logs (explain) — neither alone provides a complete picture during actual troubleshooting or incident investigation.