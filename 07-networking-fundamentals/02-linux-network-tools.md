# Linux Network Tools

A reference guide to the essential command-line tools for testing connectivity, inspecting active connections, capturing traffic, scanning networks, and troubleshooting DNS on Linux.

---

## 📶 `ping` — Basic Reachability Testing

`ping` sends ICMP Echo Request packets and waits for Echo Replies, confirming whether a host is reachable and roughly how long round-trips take.

```bash
ping google.com
ping -c 4 8.8.8.8          # send exactly 4 packets, then stop
ping -i 0.5 8.8.8.8         # send every 0.5 seconds instead of the default 1 second
ping -s 1000 8.8.8.8         # use a larger packet size (1000 bytes)
ping6 ::1                    # IPv6 (or just `ping` on systems where it auto-detects)
```

```
64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=14.2 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=13.8 ms
--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 13.8/14.0/14.2/0.2 ms
```

| Field | Meaning |
|---|---|
| `icmp_seq` | Sequence number of this packet |
| `ttl` | Time To Live remaining when it arrived — drops by 1 per router hop |
| `time` | Round-trip time |
| `packet loss` | Percentage of packets that got no reply — any loss on a LAN is worth investigating |

> **Note:** Some networks and hosts deliberately block ICMP for security reasons — a failed `ping` doesn't always mean the host is down; it might mean ICMP specifically is filtered while other protocols (like HTTP) work fine. Don't treat `ping` failure alone as conclusive.

---

## 🛤️ `traceroute` — Mapping the Path

`traceroute` reveals every router (hop) a packet passes through en route to a destination, by sending packets with increasing TTL values and noting who responds at each TTL limit.

```bash
traceroute google.com
traceroute -n google.com       # skip reverse DNS lookups — much faster output
traceroute -I google.com        # use ICMP instead of the default UDP probes
```

```
 1  192.168.1.1 (192.168.1.1)  1.123 ms
 2  10.20.0.1 (10.20.0.1)      8.402 ms
 3  * * *
 4  72.14.215.85 (72.14.215.85)  15.221 ms
```

### Reading the Output

- Each numbered line is one **hop** (one router) along the path.
- `* * *` means that hop didn't respond — often because that router blocks the probe type, **not necessarily** that the path is broken (traffic can still be flowing through it successfully).
- A sudden, sustained increase in latency at a specific hop, with all subsequent hops slow too, often points to congestion or a problem at *that* hop specifically.

### `mtr` — A More Interactive Alternative

```bash
mtr google.com          # combines ping + traceroute, continuously, with live stats per hop
```

`mtr` re-probes every hop repeatedly and shows loss percentage and latency per hop in real time — generally more useful than a single `traceroute` snapshot for diagnosing intermittent issues.

---

## 🔌 `ss` — Inspecting Sockets and Connections

`ss` ("socket statistics") shows active network connections and listening ports — the modern replacement for `netstat`.

```bash
ss -tuln          # TCP + UDP, listening, numeric (no name resolution) — the most common combo
ss -tunp           # same, but show the owning Process instead of Listening-only
ss -t               # TCP connections only
ss -u               # UDP only
ss -a               # all sockets (listening + established)
```

| Flag | Meaning |
|---|---|
| `-t` | TCP sockets |
| `-u` | UDP sockets |
| `-l` | Listening sockets only |
| `-n` | Numeric — skip resolving ports/addresses to names (faster, often clearer) |
| `-p` | Show the process (PID/name) owning each socket — usually needs `sudo` for other users' processes |
| `-a` | All sockets, not just listening |

```bash
sudo ss -tulnp
```

```
Netid  State    Local Address:Port    Peer Address:Port   Process
tcp    LISTEN   0.0.0.0:22             0.0.0.0:*           users:(("sshd",pid=812,fd=3))
tcp    LISTEN   127.0.0.1:5432         0.0.0.0:*           users:(("postgres",pid=1203,fd=5))
```

### Common Filters

```bash
ss -tlnp | grep :80          # what's listening on port 80?
ss -tn state established      # show only established TCP connections
ss -tn dst 8.8.8.8              # connections to a specific destination
```

---

## 🔌 `netstat` — The Legacy Tool

`netstat` predates `ss` and is **deprecated** on most modern distributions (often not installed by default), but is still common enough in scripts, documentation, and older systems to be worth recognizing.

```bash
netstat -tuln       # same intent as `ss -tuln`
netstat -tunp        # same intent as `ss -tunp`
netstat -r            # show routing table (use `ip route` instead on modern systems)
```

| `netstat` | `ss` equivalent |
|---|---|
| `netstat -tuln` | `ss -tuln` |
| `netstat -tunp` | `ss -tunp` |
| `netstat -r` | `ip route show` |
| `netstat -i` | `ip -s link` |

> **Tip:** If `netstat` isn't installed and you can't add packages, `ss` covers virtually every common `netstat` use case with equal or better performance — there's rarely a reason to specifically seek out `netstat` on a modern system.

---

## 🕵️ `tcpdump` — Packet Capture

`tcpdump` captures and displays raw network packets passing through an interface — the most direct way to see exactly what's actually being sent and received.

```bash
sudo tcpdump -i eth0                    # capture on a specific interface
sudo tcpdump -i any                      # capture on all interfaces
sudo tcpdump -i eth0 -n                   # don't resolve hostnames/ports — faster, clearer
sudo tcpdump -i eth0 -c 50                 # capture exactly 50 packets, then stop
sudo tcpdump -i eth0 -w capture.pcap        # write to a file instead of printing live
tcpdump -r capture.pcap                      # read back a previously saved capture
```

### Filtering Captures

```bash
sudo tcpdump -i eth0 port 80                  # only traffic on port 80
sudo tcpdump -i eth0 host 192.168.1.50          # only traffic to/from a specific host
sudo tcpdump -i eth0 src 192.168.1.50            # only traffic FROM that host
sudo tcpdump -i eth0 dst 192.168.1.50            # only traffic TO that host
sudo tcpdump -i eth0 tcp and port 443             # combine protocol + port filters
sudo tcpdump -i eth0 'port 80 or port 443'         # combine with OR (quote it for the shell)
```

### Reading Output

```
14:32:01.123456 IP 192.168.1.50.54321 > 142.250.80.46.443: Flags [S], seq 123456789, ...
```

```
time            source-IP.port  >  dest-IP.port   :  flags, sequence info
```

| TCP Flag | Meaning |
|---|---|
| `S` | SYN — connection initiation |
| `S.` | SYN-ACK — connection acknowledgment |
| `.` | ACK — plain acknowledgment |
| `P` | PSH — data being pushed to the application |
| `F` | FIN — connection closing |
| `R` | RST — connection reset/refused |

> ⚠️ **Caution:** `tcpdump` captures raw traffic, which can include sensitive data (credentials, session tokens) if it's unencrypted. Treat capture files as sensitive, restrict who can read them, and avoid capturing more than you actually need to diagnose the issue at hand. Capturing on a network you don't own or have authorization to monitor can also have legal implications — only capture traffic you're authorized to inspect.

---

## 🛰️ `nmap` — Network and Port Scanning

`nmap` discovers hosts on a network and probes which ports are open on them — a core tool for network inventory, troubleshooting, and security auditing.

```bash
nmap 192.168.1.1                    # scan common ports on a single host
nmap 192.168.1.0/24                  # scan an entire subnet for live hosts
nmap -p 22,80,443 192.168.1.50         # scan specific ports only
nmap -p- 192.168.1.50                   # scan ALL 65535 ports (slow)
nmap -sV 192.168.1.50                    # attempt to identify service/version on open ports
nmap -O 192.168.1.50                      # attempt OS detection (often needs sudo)
```

### Common Scan Types

```bash
sudo nmap -sS 192.168.1.50     # TCP SYN scan ("stealth" scan) — default for privileged users, doesn't complete the handshake
nmap -sT 192.168.1.50           # TCP connect scan — completes the full handshake, used when not running as root
sudo nmap -sU 192.168.1.50      # UDP scan — slower, often less reliable due to UDP's nature
```

### Reading Output

```
PORT     STATE  SERVICE
22/tcp   open   ssh
80/tcp   open   http
443/tcp  open   https
3306/tcp closed mysql
```

| State | Meaning |
|---|---|
| `open` | A service is actively listening and responding |
| `closed` | The port is reachable, but nothing is listening |
| `filtered` | A firewall is dropping/blocking probes — `nmap` can't tell if it's open or closed |

> ⚠️ **Caution:** Only scan networks and hosts you own or have **explicit authorization** to test. Port scanning systems you don't control can be considered hostile reconnaissance and may violate laws or terms of service, even when intent is benign curiosity. Use `nmap` against your own lab, home network, or systems you've been explicitly authorized to assess.

---

## 🌐 DNS Troubleshooting: `dig` and `host`

### `dig` — Detailed DNS Queries

```bash
dig example.com                  # full DNS query + answer + timing
dig example.com +short            # just the resolved IP, nothing else
dig example.com MX                 # query a specific record type
dig example.com ANY                 # query all record types (less reliable on many servers now)
dig @8.8.8.8 example.com             # query a SPECIFIC DNS server, bypassing your configured default
dig -x 8.8.8.8                        # reverse lookup — IP to hostname
```

```
;; ANSWER SECTION:
example.com.    300    IN    A    93.184.216.34
```

| Field | Meaning |
|---|---|
| `300` | TTL — seconds this record can be cached before re-querying |
| `IN` | Class — "Internet" (essentially always this) |
| `A` | Record type — IPv4 address |
| `93.184.216.34` | The actual answer |

### Common Record Types

| Type | Purpose |
|---|---|
| `A` | IPv4 address |
| `AAAA` | IPv6 address |
| `MX` | Mail server(s) for the domain |
| `NS` | Authoritative name servers for the domain |
| `TXT` | Arbitrary text — often used for verification/SPF/DKIM |
| `CNAME` | Alias pointing to another hostname |
| `SOA` | Start of Authority — zone administrative info |

### `host` — Simpler, Quicker Lookups

```bash
host example.com                  # quick A record lookup
host -t MX example.com             # specific record type
host 93.184.216.34                  # reverse lookup
```

> **Tip:** `dig` gives far more detail (timing, full response sections, authority records) and is the better choice for genuine troubleshooting. `host` is faster to type and read for a quick "what does this resolve to" check.

### Diagnosing Common DNS Problems

```bash
# Is the problem DNS, or routing? Compare these two:
ping 8.8.8.8           # works? → routing/IP connectivity is fine
ping google.com         # fails? → likely a DNS-specific problem

# Which DNS server is actually being used?
cat /etc/resolv.conf
resolvectl status        # systemd-resolved systems — shows per-interface DNS config

# Does a DIFFERENT DNS server resolve it correctly?
dig @1.1.1.1 example.com    # if this works but your default server doesn't, the problem is your configured resolver
```

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Basic reachability test | `ping -c 4 host` |
| Trace the path to a host | `traceroute host` or `mtr host` |
| List listening ports | `ss -tuln` |
| List listening ports + process | `sudo ss -tulnp` |
| Legacy connection listing | `netstat -tuln` |
| Capture packets on an interface | `sudo tcpdump -i eth0` |
| Capture filtered by port | `sudo tcpdump -i eth0 port 80` |
| Scan a host's open ports | `nmap host` |
| Scan a subnet for live hosts | `nmap 192.168.1.0/24` |
| Resolve a hostname (detailed) | `dig hostname` |
| Resolve a hostname (quick) | `host hostname` |
| Query a specific DNS server | `dig @server hostname` |
| Reverse DNS lookup | `dig -x IP` or `host IP` |

---

## 💡 Best Practices

- Don't treat a failed `ping` as conclusive proof a host is down — ICMP is often filtered independently of other protocols actually working.
- Use `ss` instead of `netstat` on modern systems — it's faster, actively maintained, and covers the same use cases.
- Always use `-n` with `tcpdump`/`traceroute` when troubleshooting interactively — skipping DNS resolution speeds up output significantly and avoids DNS issues confusing a network-layer investigation.
- Treat `tcpdump` captures as sensitive data, and only capture on networks/hosts you're authorized to monitor.
- Only run `nmap` scans against systems and networks you own or have explicit permission to test — unauthorized scanning can have legal consequences.
- When debugging "the internet doesn't work," isolate DNS from routing early: `ping` an IP directly, then `ping` a hostname — if only the second fails, focus entirely on DNS (`dig`, `/etc/resolv.conf`, `resolvectl status`), not your routing table.
- Use `dig @8.8.8.8` (or another known-good resolver) to quickly determine whether a DNS problem is in your local resolver configuration or further upstream.