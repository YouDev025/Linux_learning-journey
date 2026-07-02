# 🌐 Networking Cheat Sheet

> A quick-reference guide to essential Linux networking commands — interfaces, connectivity, DNS, ports, and firewalls — with syntax, explanations, and real examples.

---

## Table of Contents

- [Interface](#-interface)
- [Connectivity](#-connectivity)
- [DNS](#-dns)
- [Ports](#-ports)
- [Firewall](#-firewall)
- [Quick Reference Table](#-quick-reference-table)

---

## 🔌 Interface

Commands for viewing and managing network interfaces, IP addresses, and routes.

### `ip addr`
Show IP addresses assigned to all network interfaces.
```bash
ip addr show           # list all interfaces and their IPs
ip addr show eth0      # show only the eth0 interface
```

### `ip link`
Show or modify the status of network interfaces (up/down, MTU, etc.).
```bash
ip link show            # list interfaces and their state
sudo ip link set eth0 up    # bring interface eth0 up
sudo ip link set eth0 down  # bring interface eth0 down
```

### `ip route`
Show or modify the system's routing table.
```bash
ip route show                          # display the routing table
sudo ip route add default via 192.168.1.1  # set a default gateway
```

---

## 📡 Connectivity

Commands for testing whether a host is reachable and how traffic gets there.

### `ping`
Send ICMP echo requests to check if a host is reachable and measure latency.
```bash
ping google.com         # ping continuously
ping -c 4 google.com    # send only 4 packets
```

### `traceroute`
Show the path (hop by hop) packets take to reach a destination.
```bash
traceroute google.com
```

### `curl`
Transfer data to/from a URL; useful for testing HTTP(S) endpoints and APIs.
```bash
curl https://example.com              # fetch a page
curl -I https://example.com           # fetch only response headers
curl -X POST -d "key=value" https://api.example.com  # send POST data
```

### `wget`
Download files from the web via HTTP, HTTPS, or FTP.
```bash
wget https://example.com/file.zip     # download a file
wget -c https://example.com/file.zip  # resume an interrupted download
```

---

## 🧭 DNS

Commands for querying the Domain Name System.

### `dig`
Query DNS servers for detailed information about a domain (A, MX, TXT records, etc.).
```bash
dig example.com          # get the A record
dig example.com MX       # get mail server records
dig +short example.com   # concise output (just the IP)
```

### `host`
Simple DNS lookup tool; quickly resolves a hostname to an IP address.
```bash
host example.com
```

### `nslookup`
Interactive/non-interactive tool for querying DNS servers (older, still widely used).
```bash
nslookup example.com
```

---

## 🔎 Ports

Commands for inspecting open ports and active network connections.

### `ss`
Show socket statistics; modern replacement for `netstat`, lists listening/established connections.
```bash
ss -tuln         # show listening TCP/UDP ports
ss -tunp         # show connections with process info
```

### `netstat`
Show network connections, routing tables, and interface statistics (legacy tool).
```bash
netstat -tuln    # list listening ports
netstat -r       # show the routing table
```

### `nmap`
Network scanner used to discover hosts and open ports on a network.
```bash
nmap 192.168.1.1         # scan a single host
nmap -p 1-1000 192.168.1.1   # scan a range of ports
nmap -sV 192.168.1.1     # detect service versions
```

---

## 🛡️ Firewall

Commands for managing firewall rules and packet filtering.

### `iptables`
Legacy Linux firewall tool for defining packet filtering rules (being replaced by `nft`).
```bash
sudo iptables -L                          # list current rules
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # allow SSH
```

### `nft`
Modern Linux firewall framework (nftables) that replaces `iptables`.
```bash
sudo nft list ruleset      # show current rules
sudo nft add rule inet filter input tcp dport 22 accept  # allow SSH
```

### `ufw`
"Uncomplicated Firewall"; a simplified front-end for managing `iptables` rules.
```bash
sudo ufw enable            # turn the firewall on
sudo ufw allow 22/tcp      # allow SSH
sudo ufw status            # check current rules
```

### `firewalld`
Dynamic firewall management tool (common on RHEL/CentOS/Fedora) with zone-based rules.
```bash
sudo firewall-cmd --state                       # check if running
sudo firewall-cmd --add-service=ssh --permanent  # allow SSH permanently
sudo firewall-cmd --reload                       # apply changes
```

---

## 📋 Quick Reference Table

| Category     | Tools                                  | Typical Use              |
|--------------|------------------------------------------|---------------------------|
| Interface    | `ip addr`, `ip link`, `ip route`         | Configure/inspect NICs and routes |
| Connectivity | `ping`, `traceroute`, `curl`, `wget`     | Test reachability and fetch data |
| DNS          | `dig`, `host`, `nslookup`                | Resolve domain names |
| Ports        | `ss`, `netstat`, `nmap`                  | Inspect open ports and connections |
| Firewall     | `iptables`, `nft`, `ufw`, `firewalld`    | Filter and secure network traffic |

---

*💡 Tip: Most of these commands require root privileges (`sudo`) when modifying system state, but not when only viewing information.*s