# Firewalls and iptables

A reference guide to Linux packet filtering — how stateful firewalls work conceptually, how to configure `iptables` chains and rules, and how `nftables` succeeds it as the modern standard.

---

## 🧱 Packet Filtering vs. Stateful Inspection

### Stateless Packet Filtering

A **stateless** firewall examines each packet in isolation, deciding allow/deny based solely on that packet's own header fields (source/destination IP, port, protocol) — with no memory of any previous packets.

```
Packet arrives → check rules against THIS packet alone → allow or deny
```

**Limitation:** to allow a normal request/response conversation (e.g. you browsing a website), a stateless firewall needs *separate explicit rules* for both the outbound request and the inbound reply — and a reply rule that's too permissive becomes a security gap of its own (e.g. allowing all inbound traffic on port 80, regardless of whether you actually requested anything).

### Stateful Inspection

A **stateful** firewall tracks active connections in a **connection state table**, and can match traffic based on its *relationship* to a connection already underway — not just its raw header fields.

```
Packet arrives → is this part of an EXISTING tracked connection?
   YES → allow automatically (it's a legitimate reply/continuation)
   NO  → evaluate against the actual rule set
```

This lets you write one simple rule — "allow outbound connections, and allow anything that's a response to a connection *we* initiated" — instead of separately reasoning about every possible reply scenario.

### Connection States

| State | Meaning |
|---|---|
| `NEW` | First packet of a new connection |
| `ESTABLISHED` | Part of a connection that's already exchanged traffic in both directions |
| `RELATED` | Not part of the connection itself, but logically associated with one (e.g. an FTP data channel related to its control connection) |
| `INVALID` | Doesn't fit any tracked connection and doesn't look like a valid new one either — usually safe to drop |

Both `iptables` and `nftables` are stateful by default when configured with connection tracking (`conntrack`) — which is the standard, recommended approach on virtually all modern Linux firewalls.

---

## 🔗 `iptables` — Chains and Tables

### The Conceptual Model

`iptables` organizes rules into **tables**, each containing **chains**, each containing an ordered list of **rules**. A packet is checked against the rules in a chain, in order, until one matches (or it falls through to the chain's default policy).

```
Table (e.g. "filter")
  └── Chain (e.g. "INPUT")
        └── Rule 1 → Rule 2 → Rule 3 → ... → default policy
```

### The Tables

| Table | Purpose |
|---|---|
| `filter` | The default table — allow/deny decisions (most common use case) |
| `nat` | Network address translation — rewriting source/destination addresses |
| `mangle` | Specialized packet alteration (TTL, marking packets for later matching, etc.) |
| `raw` | Configuring exemptions from connection tracking |

### The Built-In Chains (in the `filter` table)

| Chain | Applies to |
|---|---|
| `INPUT` | Packets destined **for this machine** |
| `OUTPUT` | Packets **originating from this machine** |
| `FORWARD` | Packets passing **through** this machine to somewhere else (routing/gateway scenarios) |

```
            ┌──────────┐
 packet --> │  INPUT   │ --> local process on this machine
            └──────────┘

            ┌──────────┐
local --> │  OUTPUT  │ --> packet leaves this machine
process    └──────────┘

            ┌──────────┐
 packet --> │ FORWARD  │ --> packet continues to another machine
(routed)    └──────────┘
```

---

## 📝 Basic `iptables` Rules

### Viewing Current Rules

```bash
sudo iptables -L                  # list rules in the filter table (default)
sudo iptables -L -v -n             # verbose, numeric (skip slow DNS lookups)
sudo iptables -t nat -L             # list rules in a specific table
sudo iptables -S                    # list rules in "iptables-save" format — useful for scripting/backup
```

### Rule Syntax

```bash
iptables -A CHAIN -p PROTOCOL --dport PORT -j TARGET
```

| Flag | Meaning |
|---|---|
| `-A` | Append a rule to the end of a chain |
| `-I` | Insert a rule (at a specific position, default is the top) |
| `-D` | Delete a matching rule |
| `-p` | Protocol (`tcp`, `udp`, `icmp`) |
| `-s` / `-d` | Source / destination address |
| `--sport` / `--dport` | Source / destination port |
| `-j` | Jump to a target (the action: `ACCEPT`, `DROP`, `REJECT`, or another chain) |
| `-m state` / `-m conntrack` | Match based on connection state |

### Common Targets

| Target | Behavior |
|---|---|
| `ACCEPT` | Allow the packet through |
| `DROP` | Silently discard — sender gets no response at all |
| `REJECT` | Discard, but send back an explicit rejection (e.g. ICMP port unreachable) |

> **`DROP` vs. `REJECT`:** `DROP` is generally preferred for security-facing rules, since it doesn't confirm to a potential attacker that anything is even listening at that address/port. `REJECT` is more useful internally, where a clear, fast failure (rather than a silent timeout) helps legitimate troubleshooting.

### Example: A Basic Stateful Firewall

```bash
# Allow loopback traffic (essential — many local services rely on it)
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established/related inbound traffic (replies to connections WE initiated)
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow inbound SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow inbound HTTP/HTTPS
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Drop everything else inbound that wasn't explicitly allowed above
sudo iptables -A INPUT -j DROP
```

> ⚠️ **Caution:** Order matters enormously in `iptables` — rules are evaluated top to bottom, and the first match wins. A blanket `DROP` rule placed too early in the chain will silently block everything below it, including rules you intended to take effect. Always add broad deny rules **last**.

> ⚠️ **Critical caution for remote systems:** If you're configuring this over SSH, **always ensure your SSH rule is in place and tested before adding any default-deny rule** — getting this order wrong can instantly lock you out of a remote machine with no way back in except physical/console access.

### Setting Default Policies (Alternative to a Trailing DROP Rule)

```bash
sudo iptables -P INPUT DROP        # default: drop anything not explicitly accepted
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT      # commonly left open — restricting outbound is a more advanced, deliberate choice
```

### Deleting and Flushing Rules

```bash
sudo iptables -D INPUT -p tcp --dport 22 -j ACCEPT   # delete one specific rule
sudo iptables -F INPUT                                  # flush ALL rules in one chain
sudo iptables -F                                         # flush ALL rules in ALL chains of the current table — use with extreme care
```

### Persisting Rules Across Reboots

`iptables` rules are **not persistent by default** — they're held in kernel memory and lost on reboot unless explicitly saved.

```bash
# Debian/Ubuntu
sudo apt install iptables-persistent
sudo netfilter-persistent save

# RHEL/Fedora (if using iptables-services rather than firewalld/nftables)
sudo service iptables save
```

---

## 🛡️ Higher-Level Frontends: `ufw` and `firewalld`

Most day-to-day administration uses a friendlier frontend rather than raw `iptables`/`nftables` syntax directly.

### `ufw` (Uncomplicated Firewall) — Debian/Ubuntu

```bash
sudo ufw status
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.1.0/24 to any port 22
sudo ufw deny 23
sudo ufw enable
```

### `firewalld` — RHEL/Fedora

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=22/tcp --permanent
sudo firewall-cmd --reload
```

> **Note:** Both `ufw` and `firewalld` ultimately configure the same underlying `nftables`/`iptables` infrastructure — they just provide a simpler command surface. Understanding raw `iptables`/`nftables` is still valuable for troubleshooting, advanced rules, or systems where the frontend tools aren't installed.

---

## 🆕 `nftables` — The Modern Successor

### Why `nftables` Replaced `iptables`

`iptables` (and its IPv6 counterpart `ip6tables`, plus separate `arptables`/`ebtables`) required **separate tools and rule sets per protocol family**, and its rule-matching engine had accumulated complexity over decades. `nftables` unifies all of this into a single framework, with a more consistent syntax and a more efficient in-kernel rule evaluation engine.

| | `iptables` | `nftables` |
|---|---|---|
| Protocol families | Separate tools (`iptables`, `ip6tables`, etc.) | Unified — one tool handles IPv4, IPv6, ARP, bridging |
| Rule evaluation | Linear, rule-by-rule | More efficient set/map-based matching |
| Syntax | Older, more verbose | More structured, supports variables and native sets |
| Default on modern distros | Legacy / compatibility layer | Default backend on current Debian, Ubuntu, RHEL, Fedora |

### Current State: `iptables` as a Compatibility Layer

On most current distributions, the `iptables` *command* still works, but is implemented as a translation layer (`iptables-nft`) on top of an actual `nftables` backend — meaning your familiar `iptables` syntax keeps working even though the kernel-level implementation underneath has moved on.

```bash
iptables --version
# iptables v1.8.x (nf_tables)    ← the "(nf_tables)" confirms it's running on the nftables backend
```

### Basic `nftables` Concepts

`nftables` organizes rules into **tables** and **chains** much like `iptables`, but tables are explicitly tied to a protocol family, and chains have a `type` and `hook` you define yourself rather than relying on fixed built-ins.

```bash
sudo nft list ruleset                  # show the entire current ruleset
sudo nft list tables                    # list defined tables
```

### A Basic `nftables` Configuration

```bash
sudo nft add table inet filter
sudo nft add chain inet filter input { type filter hook input priority 0 \; policy drop \; }

sudo nft add rule inet filter input iif lo accept
sudo nft add rule inet filter input ct state established,related accept
sudo nft add rule inet filter input tcp dport 22 accept
sudo nft add rule inet filter input tcp dport { 80, 443 } accept
```

| Concept | `iptables` equivalent |
|---|---|
| `table inet filter` | The `filter` table, but `inet` covers both IPv4 and IPv6 at once |
| `chain ... hook input` | Roughly equivalent to the built-in `INPUT` chain, but explicitly declared |
| `ct state established,related` | `-m state --state ESTABLISHED,RELATED` |
| `tcp dport { 80, 443 }` | Native set syntax — one rule instead of two separate `--dport` rules |

### Persisting `nftables` Rules

```bash
sudo nft list ruleset > /etc/nftables.conf      # save current rules to a file
sudo systemctl enable nftables                    # load /etc/nftables.conf automatically on boot
```

### Migration Concepts: Translating `iptables` to `nftables`

A built-in translation tool can convert existing `iptables` rules directly:

```bash
iptables-translate -A INPUT -p tcp --dport 22 -j ACCEPT
# nft add rule ip filter INPUT tcp dport 22 counter accept
```

```bash
iptables-restore-translate -f /etc/iptables/rules.v4   # translate an entire saved ruleset
```

> **Tip:** These translation tools handle the mechanical syntax conversion well, but it's worth manually reviewing the result — `nftables`' native sets, maps, and unified `inet` family support often let you express the same intent more cleanly than a literal rule-by-rule translation would produce.

---

## ⚡ Quick Reference

| Task | `iptables` | `nftables` |
|---|---|---|
| List current rules | `sudo iptables -L -v -n` | `sudo nft list ruleset` |
| Allow established/related | `-m state --state ESTABLISHED,RELATED -j ACCEPT` | `ct state established,related accept` |
| Allow a port | `-A INPUT -p tcp --dport 22 -j ACCEPT` | `add rule inet filter input tcp dport 22 accept` |
| Set default deny | `iptables -P INPUT DROP` | `policy drop` (set on the chain itself) |
| Flush rules | `iptables -F` | `nft flush ruleset` |
| Persist rules | `netfilter-persistent save` | `nft list ruleset > /etc/nftables.conf` |
| Translate old syntax | — | `iptables-translate ...` |

---

## 💡 Best Practices

- Always allow loopback traffic (`lo` interface) explicitly — many local services rely on it, and forgetting it is a common, confusing self-inflicted outage.
- Always allow `ESTABLISHED,RELATED` traffic early in the `INPUT` chain — without it, every reply to your own outbound connections gets blocked too.
- When configuring remotely over SSH, confirm your SSH access rule is in place and tested *before* adding any default-deny policy or trailing `DROP` rule — order mistakes here can lock you out entirely.
- Prefer `DROP` over `REJECT` for rules facing untrusted networks, to avoid confirming to scanners that a host exists and is listening.
- Save your rules explicitly (`netfilter-persistent save`, or write an `/etc/nftables.conf` and enable the service) — neither `iptables` nor raw `nftables` rules persist across reboots by default.
- Use `ufw`/`firewalld` for routine administration unless you have a specific reason to manage raw rules — they reduce the chance of ordering mistakes while still configuring the same underlying engine.
- When migrating from `iptables` to native `nftables` syntax, use `iptables-translate` as a starting point, then refine using `nftables`' native sets/maps rather than keeping a literal one-rule-per-line translation.