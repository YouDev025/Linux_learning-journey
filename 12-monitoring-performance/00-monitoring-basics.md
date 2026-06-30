# Monitoring Basics

A reference guide to why monitoring matters for Linux operations, the core conceptual building blocks (availability, performance, alerting), how metrics/logs/traces relate to each other, and the common open-source tools used to implement all of it.

---

## 🎯 Why Monitoring Matters

Every guide in this series so far covers *configuring* a system correctly — permissions, services, networking, security. Monitoring answers a different question: **is the system actually behaving as configured, right now, and will I find out if it stops?** A correctly configured system that silently degrades or fails, with no one aware until a user complains, has effectively the same operational impact as a misconfigured one — the gap is **visibility**, and that's what monitoring exists to close.

This is conceptually the same gap that motivated the *Linux Audit and Hardening* guide's framing: configuration is the prevention layer, monitoring (like auditing) is part of the detection layer — except monitoring's scope is operational health generally, not specifically security events.

---

## 📊 Core Concepts: Availability, Performance, Alerts

### Availability

**Availability** answers the simplest possible question: **is this service up, and reachable, right now?** It's typically the first thing monitored for any service, since nothing else matters if the answer is no.

```bash
# The crudest possible availability check — and a legitimate starting point
curl -sf https://example.com/health || echo "DOWN"
```

Availability is often expressed as a percentage over time — "99.9% uptime" means roughly 8.7 hours of downtime tolerated per year. This connects to the concept of an **SLA** (Service Level Agreement, a commitment to a customer) or **SLO** (Service Level Objective, an internal target) — see the *Quick Reference* section below for the common availability/downtime table.

### Performance

**Performance** goes beyond "is it up" to **"is it working well"** — response times, throughput, resource utilization, error rates. A service can be technically "available" (responding to requests) while performing so poorly that it's effectively unusable — slow page loads, timeouts under load, elevated error rates.

```bash
# A simple performance check alongside availability
curl -o /dev/null -s -w "Response time: %{time_total}s\n" https://example.com
```

| Metric type | Example |
|---|---|
| Latency | How long a request takes to complete |
| Throughput | Requests/transactions processed per second |
| Error rate | Percentage of requests failing or returning errors |
| Resource utilization | CPU, memory, disk, network usage (see the *Process Lifecycle* and *Signals and Scheduling* guides for the underlying OS concepts) |

### Alerts

**Alerting** is the mechanism that turns "we're collecting this data" into "a human gets notified when something needs attention" — without it, monitoring data is just a record nobody's actively watching, similar to the unreviewed-FIM-check problem raised in the *Linux Audit and Hardening* guide.

```
Metric/condition crosses a defined threshold
     │
     ▼
Alert RULE evaluates true
     │
     ▼
Notification fires (email, Slack, PagerDuty, SMS, etc.)
     │
     ▼
A human (or automated remediation) responds
```

### Designing Good Alerts: Avoiding Alert Fatigue

A poorly designed alerting setup is arguably worse than none at all — if alerts fire constantly for non-actionable conditions, people learn to ignore them, and a genuine critical alert gets lost in the noise (a well-documented phenomenon called **alert fatigue**).

| Good alert characteristics | Why it matters |
|---|---|
| Actionable | Someone receiving it should know what to actually DO, not just that something looks wrong |
| Appropriately urgent | A genuinely critical issue (service down) shouldn't use the same channel/urgency as a minor warning |
| Based on symptoms, not just causes | Alert on "users are experiencing errors," not necessarily every individual internal metric fluctuation that might (or might not) lead there |
| Has a reasonable threshold | Too sensitive → constant noise; too lax → real problems go unnoticed |

> **Tip:** A useful design test for any new alert: "if this fires at 3 AM, does the person receiving it need to wake up and act immediately, or could it reasonably wait until morning?" Route accordingly — not everything that's worth knowing about is worth an urgent page.

---

## 🧩 Metrics vs. Logs vs. Traces

These are often called the **three pillars of observability** — distinct but complementary types of operational data, each answering a different kind of question.

### Metrics

**Numeric measurements, sampled or aggregated over time** — CPU usage, request count, memory consumption, queue depth. Metrics are compact, efficient to store long-term, and excellent for trends, dashboards, and threshold-based alerting.

```
timestamp           cpu_usage_percent
10:00:00             45.2
10:00:10              47.8
10:00:20               52.1
```

> **Best for:** "is this trending in a concerning direction," "is this currently above/below a threshold," dashboards showing system health at a glance over time.

### Logs

**Discrete, timestamped event records** — covered extensively in the *Logs and journald* and *Text Processing* guides. Logs capture what specifically happened, often with rich contextual detail a metric alone can't express.

```
2026-06-29 10:00:15 ERROR Failed to connect to database: connection timeout after 30s
```

> **Best for:** "what exactly happened, and why" — the detailed forensic record once you already know something needs investigating (often after a metric or alert pointed you there).

### Traces

**A record of a single request's journey through a system**, especially across multiple services — showing how long each step took and where time was actually spent, end to end.

```
Request abc-123:
  └─ API Gateway        (2ms)
       └─ Auth Service    (15ms)
       └─ Database Query    (340ms)  ← the slow part
       └─ Response Formatting (3ms)
  Total: 360ms
```

> **Best for:** "where exactly in a multi-service request is the time actually going" — especially valuable in microservice/distributed architectures where a single user-facing request might touch many internal services, and a slow response could originate anywhere along that chain.

### How They Work Together in Practice

```
1. A METRIC alert fires: "API response time p99 > 2 seconds"
2. You check a TRACE for a slow recent request: "ah, the database query step is the bottleneck"
3. You check LOGS from that database query timeframe: "connection pool exhausted — here's the specific error"
```

> **The throughline:** metrics tell you *something* is wrong and roughly *where* to look first; traces narrow down *which specific step* in a request is the problem; logs tell you the detailed *why*, once you know where to look. Relying on only one of the three typically leaves a real gap — metrics alone don't explain root cause, logs alone don't scale well for "is everything OK right now," and traces alone don't capture the system-wide trends a dashboard provides.

---

## 🛠️ Common Open-Source Monitoring Tools

### Metrics Collection and Storage: Prometheus

**Prometheus** is the dominant open-source metrics system in current Linux/cloud-native environments — it **pulls** (scrapes) metrics from configured targets at regular intervals, storing them in its own time-series database.

```yaml
# prometheus.yml — a minimal scrape config
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

```bash
# node_exporter exposes host-level metrics (CPU, memory, disk, network) for Prometheus to scrape
curl http://localhost:9100/metrics | head -20
```

```
node_cpu_seconds_total{cpu="0",mode="idle"} 145823.4
node_memory_MemAvailable_bytes 8589934592
```

> **Prometheus's "pull" model, briefly:** rather than each host pushing data somewhere, Prometheus itself periodically requests (scrapes) metrics from each target's `/metrics` HTTP endpoint — this makes it straightforward to see at a glance whether a target is even reachable (a failed scrape is itself informative), and avoids needing every monitored host to know where to push data to.

### Visualization: Grafana

**Grafana** doesn't collect data itself — it queries data sources (Prometheus being the most common pairing) and renders dashboards, graphs, and visualizations on top of that data.

```
Prometheus (collects + stores metrics)
        │
        ▼
   Grafana (queries Prometheus, renders dashboards)
```

A typical Grafana panel might query Prometheus for `node_cpu_seconds_total` over the last 24 hours and render it as a time-series graph, with configurable thresholds for visual warning/critical coloring.

### Alerting: Alertmanager

**Alertmanager** typically pairs with Prometheus — Prometheus evaluates alert rules against incoming metrics, and when a rule's condition is met, hands the resulting alert to Alertmanager, which handles routing, deduplication, grouping, and actually notifying the right channel.

```yaml
# A Prometheus alert rule example
groups:
  - name: example
    rules:
      - alert: HighCPUUsage
        expr: node_cpu_seconds_total{mode="idle"} < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage is critically high"
```

> **Why `for: 5m` matters:** without a sustained-duration requirement, a brief, harmless CPU spike could trigger an alert immediately — `for: 5m` requires the condition to remain true for 5 continuous minutes before actually firing, directly addressing the alert-fatigue concern raised earlier by filtering out transient noise.

### Logging Aggregation: The ELK/EFK Stack and Loki

For centralizing logs across many hosts (extending beyond a single host's `journalctl`, covered in the *Logs and journald* guide):

| Component | Role |
|---|---|
| **Elasticsearch** | Stores and indexes log data for fast searching |
| **Logstash** (or **Fluentd**, forming "EFK") | Collects, parses, and ships logs from hosts into Elasticsearch |
| **Kibana** | Visualization/search UI on top of Elasticsearch, analogous to Grafana for logs |
| **Loki** | A more lightweight alternative from the Prometheus ecosystem — indexes only metadata/labels (not full text), making it cheaper to run; pairs naturally with Grafana for visualization |

```bash
# A Promtail config snippet (Loki's log-shipping agent) — conceptually similar to journald forwarding
```

> **ELK/EFK vs. Loki, briefly:** Elasticsearch indexes full log content, enabling very flexible search but at meaningfully higher storage/compute cost. Loki deliberately indexes only labels/metadata (not full text), trading some search flexibility for substantially lower resource requirements — a common choice when the existing toolchain is already Prometheus/Grafana-centric.

### Distributed Tracing: Jaeger and Zipkin

For tracing requests across multiple services in distributed/microservice architectures:

| Tool | Notes |
|---|---|
| **Jaeger** | Originated at Uber, now a CNCF project; widely used, integrates with OpenTelemetry |
| **Zipkin** | An earlier, comparable distributed tracing system, originated at Twitter |
| **OpenTelemetry** | An increasingly standard, vendor-neutral instrumentation framework/protocol — not a backend itself, but a common way applications emit trace (and metric/log) data that Jaeger, Zipkin, or other backends can then consume |

### All-in-One / Simpler Alternatives

For smaller environments where running a full Prometheus/Grafana/Loki/Jaeger stack is more operational overhead than the use case warrants:

| Tool | Notes |
|---|---|
| **Nagios** / **Icinga** | Older, well-established check-based monitoring (is this service up, run this check script) — simpler conceptual model than Prometheus's metrics-everywhere approach |
| **Zabbix** | An all-in-one monitoring platform combining metrics, alerting, and some visualization without needing to assemble separate components |
| **Netdata** | Lightweight, real-time, per-host monitoring with minimal setup — useful for quick visibility into a single host without standing up a full stack |

> **Choosing a starting point:** for a single host or small number of servers, something like Netdata or a simple Nagios/Icinga setup may be entirely sufficient and far less operational overhead than standing up Prometheus + Grafana + Alertmanager + Loki. The full cloud-native stack earns its complexity at larger scale — many independently scaling services, dynamic infrastructure, a genuine need for the metrics/logs/traces correlation described above.

---

## 🔧 A Minimal Practical Starting Point (Single Host)

Before reaching for a full monitoring stack, useful host-level visibility is available with tools already covered elsewhere in this series:

```bash
# Availability — is the expected process even running? (see the Service Management guide)
systemctl is-active nginx

# Performance — basic resource usage right now
top                      # or: htop
free -h                    # memory
df -h                        # disk
ss -tulnp                      # what's listening (see the Linux Network Tools guide)

# Logs for investigation (see the Logs and journald guide)
journalctl -u nginx -p err --since "1 hour ago"
```

```bash
# A simple cron-based "is it up" check, as a genuinely minimal starting point
*/5 * * * * curl -sf https://example.com/health || echo "DOWN at $(date)" >> /var/log/health-check.log
```

> **Tip:** Even this minimal approach embodies the same metrics/logs split described above — `top`/`free`/`df` are ad hoc metrics checks, `journalctl` is the logs layer — just without the automated collection, dashboards, and alerting a dedicated tool would add. It's a reasonable starting point, and a useful way to understand what a full monitoring stack is actually automating before adopting one.

---

## ⚡ Quick Reference

### Concept Summary

| Concept | Answers |
|---|---|
| Availability | Is it up and reachable, right now? |
| Performance | Is it working well — fast enough, low error rate? |
| Metrics | What's the numeric trend over time? |
| Logs | What specifically happened, and why? |
| Traces | Where did time go across a multi-service request? |
| Alerting | Who gets notified, and how urgently, when something crosses a threshold? |

### Availability Percentage Reference

| Uptime % | Approximate downtime/year |
|---|---|
| 99% | ~3.65 days |
| 99.9% | ~8.7 hours |
| 99.99% | ~52 minutes |
| 99.999% | ~5 minutes |

### Tool Summary

| Category | Common tools |
|---|---|
| Metrics collection/storage | Prometheus |
| Visualization | Grafana |
| Alerting | Alertmanager |
| Log aggregation | ELK/EFK stack, Loki |
| Distributed tracing | Jaeger, Zipkin, OpenTelemetry |
| All-in-one / simpler | Nagios, Icinga, Zabbix, Netdata |

---

## 💡 Best Practices

- Start monitoring with availability before performance, and performance before deep tracing — build up from "is it up" to more sophisticated observability as actual need (and scale) justifies the added complexity.
- Design alerts around actionable, symptom-level conditions rather than every possible internal metric fluctuation — alert fatigue from noisy, non-actionable alerts is a well-documented way for genuinely critical alerts to get missed.
- Use a sustained-duration requirement (like Prometheus's `for:`) on alert rules to filter out brief, non-actionable spikes rather than alerting on every momentary threshold crossing.
- Match tooling complexity to actual scale — a single host or small fleet rarely needs a full Prometheus/Grafana/Loki/Jaeger stack; simpler tools (Netdata, Nagios, basic cron health checks) are often genuinely sufficient and far less operational overhead.
- Treat metrics, logs, and traces as complementary, not redundant — each answers a different question, and relying on only one tends to leave a real diagnostic gap when investigating an actual incident.
- Remember that collected data with no one watching or alerted provides limited value — the same principle raised for FIM checks in the *Linux Audit and Hardening* guide applies directly to monitoring data generally.
- Test alert routing and urgency deliberately ("would this need to wake someone up at 3 AM") rather than defaulting everything to the same channel/severity.