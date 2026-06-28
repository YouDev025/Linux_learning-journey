# Logs and journald

A reference guide to Linux logging via the systemd journal — querying with `journalctl`, configuring persistent storage, log rotation, and how journald relates to traditional syslog.

---

## 🧱 What journald Is

**journald** is systemd's logging service — it collects log data from the kernel, system services, and user processes, storing it in a structured, indexed binary format rather than the traditional plain-text log files of older syslog implementations.

### Why a Structured Format

Traditional syslog stores log lines as plain text — searchable with `grep`, but with no inherent structure beyond whatever format each program chose to write. journald stores each log entry as a set of **fields** (timestamp, unit, PID, priority, message, and more), making structured queries — like "show me only this service's errors from the last hour" — fast and precise, without needing to parse free-text lines.

```bash
journalctl -u nginx -p err --since "1 hour ago"
```

This single command relies on journald already knowing, per entry, which unit it came from, its priority level, and its timestamp — information a plain-text grep over a flat file would have to reconstruct heuristically, if at all.

---

## 🔍 `journalctl` — Querying the Journal

### Basic Usage

```bash
journalctl                      # show the ENTIRE journal, oldest first (use sparingly on a long-running system)
journalctl -e                     # jump to the END (most recent entries) — usually what you want first
journalctl -f                       # FOLLOW live, like `tail -f`
journalctl -r                         # REVERSE order — newest first
```

### Filtering by Unit/Service

```bash
journalctl -u nginx                    # all logs for one specific unit
journalctl -u nginx -u postgresql        # multiple units at once
journalctl --user -u mysync               # a USER service (see the systemd Service Files guide)
```

### Filtering by Time

```bash
journalctl --since "2026-06-20"
journalctl --since "1 hour ago"
journalctl --since "09:00" --until "10:00"
journalctl --since yesterday
journalctl -u nginx --since "10 min ago"
```

### Filtering by Priority

journald uses the standard syslog priority levels:

| Level | Number | Meaning |
|---|---|---|
| `emerg` | 0 | System is unusable |
| `alert` | 1 | Action must be taken immediately |
| `crit` | 2 | Critical conditions |
| `err` | 3 | Error conditions |
| `warning` | 4 | Warning conditions |
| `notice` | 5 | Normal but significant |
| `info` | 6 | Informational |
| `debug` | 7 | Debug-level messages |

```bash
journalctl -p err                  # show err AND everything MORE severe (err, crit, alert, emerg)
journalctl -p warning..err           # show a SPECIFIC RANGE — warning through err only
journalctl -u nginx -p err -e          # combine: this unit, this severity, jump to most recent
```

> **Note:** `-p LEVEL` shows that level **and everything more severe**, not an exact match — `-p err` includes `crit`, `alert`, and `emerg` too, since they're all "at least as bad" as `err`. Use the `level1..level2` range syntax if you need a bounded window instead.

### Filtering by Boot

```bash
journalctl -b                      # logs from the CURRENT boot only
journalctl -b -1                     # logs from the PREVIOUS boot
journalctl --list-boots                # list all boots journald has records for
```

> **Tip:** `-b -1` is invaluable for diagnosing a crash or unexpected reboot — it shows you exactly what was happening right up until the system went down, in the PREVIOUS boot's log, separate from anything that's happened since.

### Filtering by Process/Other Fields

```bash
journalctl _PID=1234                 # logs from a specific PID
journalctl _UID=1000                   # logs from a specific user ID (see the User Account Basics guide)
journalctl _COMM=sshd                    # logs from processes with a specific command name
journalctl /usr/sbin/nginx                 # logs from a specific executable path
```

```bash
journalctl -F _SYSTEMD_UNIT             # list ALL distinct values journald has for a given field — useful for discovering what's queryable
```

### Output Formats

```bash
journalctl -u nginx -o json              # structured JSON, one object per line
journalctl -u nginx -o json-pretty         # same, but human-readable formatting
journalctl -u nginx -o short-iso             # ISO 8601 timestamps instead of the default locale-based format
journalctl -u nginx -o cat                     # JUST the message text, no metadata prefix
```

```bash
journalctl -u nginx -o json | jq '.MESSAGE'    # combine JSON output with `jq` for further processing
```

### Useful Combinations

```bash
journalctl -u nginx --since today -p err -e        # today's errors, jump to the most recent
journalctl -k                                          # KERNEL messages only (equivalent to old `dmesg`)
journalctl -k -b                                          # kernel messages from the current boot
journalctl --disk-usage                                    # how much disk space the journal is currently using
```

---

## 💾 Persistent vs. Volatile Journal Storage

### The Default Can Vary by Distribution

By default, some distributions keep the journal **volatile** (in `/run/log/journal/`, which is `tmpfs` — wiped on every reboot), while others enable **persistent** storage (`/var/log/journal/`) out of the box. Don't assume either way — check explicitly.

```bash
ls -ld /var/log/journal      # if this exists and journald is configured for it, storage is persistent
journalctl --disk-usage        # also confirms the journal is actually retaining data across time
```

### Making Storage Persistent

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

Alternatively (or additionally), set it explicitly in the configuration file:

```bash
sudo nano /etc/systemd/journald.conf
```

```ini
[Journal]
Storage=persistent
```

```bash
sudo systemctl restart systemd-journald
```

| `Storage=` value | Behavior |
|---|---|
| `volatile` | Journal lives only in memory (`/run/`) — lost on reboot |
| `persistent` | Journal lives on disk (`/var/log/journal/`) — survives reboots |
| `auto` | Persistent IF `/var/log/journal/` already exists, volatile otherwise (often the actual default) |
| `none` | Logging disabled entirely (rare, generally inadvisable) |

> ⚠️ **Caution:** If you rely on `-b -1` (previous boot logs) for troubleshooting unexpected reboots/crashes, confirm persistent storage is actually enabled — on a volatile configuration, the very logs you'd need to diagnose a crash are wiped out by the reboot the crash caused.

---

## 🗑️ Log Rotation and Size Limits

journald manages its own size limits internally (distinct from the older `logrotate` mechanism used for traditional flat-file logs) — old entries are automatically removed once configured limits are reached.

### Key Size-Related Settings (`/etc/systemd/journald.conf`)

```ini
[Journal]
SystemMaxUse=500M            # maximum total disk space the journal may use
SystemKeepFree=1G              # always leave at least this much disk space free, regardless of SystemMaxUse
SystemMaxFileSize=50M            # maximum size of an individual journal file before rotating to a new one
MaxRetentionSec=1month             # automatically remove entries older than this, regardless of size
```

```bash
sudo systemctl restart systemd-journald     # apply changes after editing journald.conf
```

### Manually Reclaiming Space

```bash
journalctl --disk-usage                       # check current usage first
sudo journalctl --vacuum-size=200M               # shrink the journal down to at most 200M
sudo journalctl --vacuum-time=2weeks               # remove entries older than 2 weeks
sudo journalctl --vacuum-files=5                     # keep only the 5 most recent journal FILES
```

> **Tip:** Set `SystemMaxUse` deliberately on systems with limited disk space — an unbounded or very generously sized journal can quietly consume significant disk space over a long uptime, especially on a chatty/high-log-volume service.

### Traditional `logrotate` Still Matters

Many applications (and `rsyslog`, where still used) write to traditional flat-text files in `/var/log/`, which `logrotate` manages separately from journald's own internal size management — the two systems coexist rather than one fully replacing the other on most distributions.

```bash
cat /etc/logrotate.conf
ls /etc/logrotate.d/                  # per-application rotation configs
```

```
/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
```

> **Note:** journald-managed services don't need `logrotate` for their *own* journal entries — journald handles that internally via the settings above. `logrotate` remains relevant for applications still writing directly to flat files in `/var/log/`, independent of whether journald is also running.

---

## 🔄 Syslog vs. journal Logging

### Historical Context

**Syslog** is a long-standing logging protocol/convention (and family of daemons — `syslogd`, `rsyslog`, `syslog-ng`) that predates systemd by decades — plain-text log files, typically in `/var/log/`, with a relatively loose, line-based format that varies somewhat between applications.

### How They Coexist on Modern Systems

On most current distributions, `journald` is the **primary** logging system, but compatibility with syslog is typically maintained in one of two ways:

```
Option A: journald forwards to rsyslog/syslog-ng
   journald (collects everything) ──forwards──> rsyslog ──writes──> /var/log/*.log (flat text)

Option B: rsyslog reads FROM the journal directly
   journald (collects everything) <──reads─── rsyslog ──writes──> /var/log/*.log (flat text)
```

```bash
systemctl status rsyslog          # check if a traditional syslog daemon is ALSO running alongside journald
```

### Forwarding Configuration

```ini
# /etc/systemd/journald.conf
[Journal]
ForwardToSyslog=yes      # send journal entries onward to a syslog daemon, if present
```

### Comparison

| | journald | Traditional syslog (rsyslog/syslog-ng) |
|---|---|---|
| Storage format | Structured binary, indexed | Plain text |
| Querying | `journalctl` with rich filters (unit, priority, time, PID, etc.) | `grep`/`awk`/`sed` over flat files (see the *Text Processing* guide) |
| Per-entry metadata | Extensive (PID, UID, unit, boot ID, executable path, etc.) | Whatever the application chose to write in the line itself |
| Network log forwarding | Possible, but less native | Long-established, widely supported (remote syslog servers) |
| Human-readable without tooling | No (binary format) | Yes (plain text) |
| Default on most current distros | Yes | Often still present alongside, for compatibility/network forwarding |

> **Practical takeaway:** for **local** troubleshooting on a modern systemd-based distribution, `journalctl` is almost always the better starting point — richer filtering, less manual text-parsing. For **centralized/remote** log aggregation across many machines, traditional syslog forwarding (or journald's own remote-upload capabilities, `systemd-journal-upload`/`systemd-journal-remote`, where configured) often still plays a role.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Jump to most recent entries | `journalctl -e` |
| Follow live | `journalctl -f` |
| Filter by unit | `journalctl -u name` |
| Filter by time | `journalctl --since "1 hour ago"` |
| Filter by priority (and worse) | `journalctl -p err` |
| Filter by priority range | `journalctl -p warning..err` |
| Logs from current/previous boot | `journalctl -b` / `journalctl -b -1` |
| Kernel messages only | `journalctl -k` |
| JSON output | `journalctl -o json` |
| Check journal disk usage | `journalctl --disk-usage` |
| Shrink journal to a size | `sudo journalctl --vacuum-size=200M` |
| Remove entries older than X | `sudo journalctl --vacuum-time=2weeks` |
| Make storage persistent | set `Storage=persistent` in `journald.conf` + restart |
| Apply journald.conf changes | `sudo systemctl restart systemd-journald` |

---

## 💡 Best Practices

- Confirm whether journal storage is persistent or volatile before relying on it for post-crash diagnosis — `journalctl -b -1` only works if logs actually survived the reboot.
- Use `-p LEVEL` to filter noise during troubleshooting — most investigations don't need `debug`/`info` level entries cluttering the output.
- Set `SystemMaxUse`/`MaxRetentionSec` deliberately on space-constrained systems rather than relying on undocumented defaults — unbounded journal growth is a quiet, easy-to-miss disk usage problem.
- Reach for `journalctl -u name --since "X" -p LEVEL` as a fast, targeted combination rather than scrolling through the entire unfiltered journal.
- Remember `-b -1` exists for diagnosing crashes/unexpected reboots — it's one of the most valuable, underused journalctl features for exactly that scenario.
- For applications still writing flat-text logs to `/var/log/`, don't forget `logrotate` is a separate, still-relevant mechanism — journald's internal vacuuming doesn't manage those files.
- For multi-machine environments, plan log aggregation deliberately (syslog forwarding or journal remote upload) rather than assuming `journalctl` alone scales to centralized, cross-host troubleshooting.