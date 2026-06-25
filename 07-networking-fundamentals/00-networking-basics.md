# Networking Basics

A reference guide to how Linux handles networking fundamentals — the conceptual model behind it all, IP addressing, hostnames, and how interfaces are named and configured.

---

## 🧱 The OSI Model

The **OSI model** is a conceptual framework describing networking as seven distinct layers, each responsible for a specific part of getting data from one machine to another. Real-world Linux networking maps onto it loosely but usefully — it's the shared vocabulary most networking tools, documentation, and troubleshooting workflows assume.

| Layer | Name | Examples | Linux-relevant concepts |
|---|---|---|---|
| 7 | Application | HTTP, DNS, SSH | The actual programs using the network |
| 6 | Presentation | TLS/SSL, encoding | Encryption, data formatting |
| 5 | Session | — | Connection state management |
| 4 | Transport | TCP, UDP | Ports, reliable vs. unreliable delivery |
| 3 | Network | IP, ICMP | IP addresses, routing |
| 2 | Data Link | Ethernet, Wi-Fi (802.11) | MAC addresses, switches, network interfaces |
| 1 | Physical | Cables, radio signals | Actual electrical/optical/radio transmission |

### Why This Layering Matters Practically

Troubleshooting connectivity issues is far more efficient when you think in layers, **working bottom-up**:

```
Is the cable/interface up?         → Layer 1/2
Does the interface have an IP?     → Layer 3
Can I reach the gateway/destination? → Layer 3
Is the right port open/listening?  → Layer 4
Does the actual application respond? → Layer 7
```

A common mistake is jumping straight to "the website won't load" (Layer 7) without first confirming Layer 1–3 basics (cable connected, interface up, IP address assigned, gateway reachable) are actually fine.

```bash
ip link show          # Layer 1/2 — is the interface physically up?
ip addr show           # Layer 3 — does it have an IP address?
ping 8.8.8.8            # Layer 3 — can we reach something by IP?
ping google.com          # Layer 3 + DNS — can we reach something by NAME?
curl -v https://example.com   # Layer 4–7 — full connection + application response
```

---

## 🔢 IPv4 Fundamentals

### Address Structure

An IPv4 address is 32 bits, written as four 8-bit numbers (0–255) separated by dots:

```
192.168.1.10
 │    │   │  │
 8 bits each, four total = 32 bits
```

### Network vs. Host Portion

Every IPv4 address is split into a **network portion** (identifying which network it belongs to) and a **host portion** (identifying the specific device on that network) — where the split happens is determined by the **subnet mask** or **CIDR notation**.

```
192.168.1.10/24
              │
              └── CIDR notation: first 24 bits are the network portion
```

| CIDR | Subnet Mask | Usable Hosts | Common Use |
|---|---|---|---|
| `/24` | `255.255.255.0` | 254 | Typical home/small office LAN |
| `/16` | `255.255.0.0` | 65,534 | Larger private network |
| `/8` | `255.0.0.0` | ~16.7 million | Very large allocations |
| `/30` | `255.255.255.252` | 2 | Point-to-point links |
| `/32` | `255.255.255.255` | 1 | A single specific host |

### Private vs. Public Address Ranges

| Range | CIDR | Scope |
|---|---|---|
| `10.0.0.0 – 10.255.255.255` | `10.0.0.0/8` | Private |
| `172.16.0.0 – 172.31.255.255` | `172.16.0.0/12` | Private |
| `192.168.0.0 – 192.168.255.255` | `192.168.0.0/16` | Private |
| `127.0.0.0 – 127.255.255.255` | `127.0.0.0/8` | Loopback (localhost) |
| Everything else (mostly) | — | Publicly routable |

Private addresses aren't routable on the public internet directly — devices using them typically reach the internet through **NAT (Network Address Translation)** at a router/gateway, which rewrites private source addresses to a shared public one.

### Special Addresses

```bash
127.0.0.1        # loopback — always refers to "this machine"
0.0.0.0           # "any address" — used in configs to mean "listen on all interfaces"
255.255.255.255   # broadcast — "every device on this local network"
```

---

## 🔢 IPv6 Fundamentals

### Why IPv6 Exists

IPv4's 32-bit address space provides roughly 4.3 billion addresses — long since exhausted given global device growth. IPv6 uses **128-bit** addresses, providing an astronomically larger space (roughly 340 undecillion addresses) that's expected to remain sufficient indefinitely.

### Address Structure

```
2001:0db8:85a3:0000:0000:8a2e:0370:7334
```

Eight groups of four hexadecimal digits, separated by colons. Two shorthand rules make these more manageable:

1. **Leading zeros in a group can be dropped:** `0db8` → `db8`
2. **One run of consecutive all-zero groups can be collapsed to `::`** (only once per address):

```
2001:0db8:0000:0000:0000:0000:1428:57ab
→ 2001:db8::1428:57ab
```

### Common IPv6 Address Types

| Type | Prefix | Scope |
|---|---|---|
| Loopback | `::1` | This machine only |
| Link-local | `fe80::/10` | Local network segment only, auto-assigned |
| Unique local | `fc00::/7` | Private, similar role to IPv4 private ranges |
| Global unicast | `2000::/3` | Publicly routable |

### Key Differences from IPv4 in Practice

- **No NAT requirement:** with enough addresses for every device to have a genuinely public one, IPv6 networks often don't need NAT — though firewalls still control what's actually reachable.
- **No broadcast:** IPv6 replaces broadcast with **multicast** for similar "reach a group of devices" use cases.
- **Auto-configuration is more central:** link-local addresses are mandatory and self-assigned, and stateless address autoconfiguration (SLAAC) is common for assigning global addresses without DHCP.

```bash
ip -6 addr show          # show IPv6 addresses on this machine
ping6 ::1                 # ping loopback over IPv6 (or just: ping ::1 on modern systems)
```

---

## 🏷️ Hostnames

A **hostname** is the human-readable name identifying a machine, used alongside (or instead of) its IP address.

```bash
hostname                 # show current hostname
hostnamectl               # show detailed hostname + related system info (systemd systems)
sudo hostnamectl set-hostname new-name
```

### Where Hostnames Are Configured

```bash
cat /etc/hostname     # the machine's configured hostname
cat /etc/hosts          # local static name-to-IP mappings
```

A typical `/etc/hosts`:

```
127.0.0.1   localhost
127.0.1.1   my-machine
192.168.1.50  fileserver.local  fileserver
```

`/etc/hosts` is checked **before** DNS for name resolution on most systems — useful for local overrides, testing, or small networks without a dedicated DNS server.

### Fully Qualified Domain Names (FQDN)

```
hostname.subdomain.domain.tld
   │           │        │    │
   │           │        │    └── top-level domain
   │           │        └── domain
   │           └── optional subdomain
   └── the specific host
```

```bash
hostname -f      # show the fully qualified domain name, if configured
```

---

## 🔌 Network Interfaces

### What an Interface Is

A **network interface** is the kernel's representation of a network connection point — physical (an Ethernet port, a Wi-Fi radio) or virtual (a VPN tunnel, a container's virtual link).

```bash
ip link show
ip addr show
```

```
1: lo: <LOOPBACK,UP> ...
2: eth0: <BROADCAST,MULTICAST,UP> ...
3: wlan0: <BROADCAST,MULTICAST> ...
```

### Modern Interface Naming: Predictable Network Interface Names

Older systems named interfaces simply `eth0`, `eth1`, `wlan0` in the order the kernel happened to detect them — which could change unpredictably across reboots, especially with multiple NICs. Modern `systemd`-based distributions instead use **predictable names** derived from physical bus location, firmware information, or MAC address, so a given physical port keeps the same name reliably.

| Naming pattern | Meaning |
|---|---|
| `eth0`, `wlan0` | Legacy kernel-assigned naming (still seen on older/simpler systems) |
| `enp3s0` | **e**thernet, **p**ci bus 3, **s**lot 0 |
| `wlp2s0` | **w**ireless **l**an, **p**ci bus 2, **s**lot 0 |
| `eno1` | **e**thernet, **o**nboard, index 1 |
| `ens33` | **e**thernet, **s**lot 33 (common in virtualized environments, e.g. VMware) |

```bash
ip link show          # see your actual interface names on this system
udevadm test-builtin net_id /sys/class/net/eth0   # show how a name was derived (advanced)
```

> **Tip:** If interface names seem cryptic, they're encoding *where* the hardware sits in the system (bus/slot/onboard) rather than just an arbitrary counter — which is precisely what makes them stable across reboots and hardware reordering.

---

## ⚙️ Network Configuration Files

Configuration location and tooling vary meaningfully across distributions — this is one of the more fragmented areas of Linux system administration.

### Debian/Ubuntu: Netplan (modern) and `/etc/network/interfaces` (legacy)

```bash
cat /etc/netplan/*.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
    enp3s0:
      addresses: [192.168.1.50/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
sudo netplan apply       # apply changes from netplan YAML config
```

Older Debian-based systems instead used `/etc/network/interfaces` directly:

```
auto eth0
iface eth0 inet static
    address 192.168.1.50
    netmask 255.255.255.0
    gateway 192.168.1.1
```

### RHEL/Fedora: NetworkManager

```bash
nmcli device show              # show all devices and their current config
nmcli connection show           # show configured connection profiles
nmcli connection show "eth0" | grep IP4
```

Configuration is typically stored as keyfiles:

```bash
cat /etc/NetworkManager/system-connections/eth0.nmconnection
```

```ini
[ipv4]
method=manual
address1=192.168.1.50/24,192.168.1.1
dns=8.8.8.8;1.1.1.1;
```

```bash
sudo nmcli connection modify eth0 ipv4.addresses 192.168.1.50/24
sudo nmcli connection up eth0
```

### Universal Inspection Commands (Work Regardless of Distro/Tooling)

```bash
ip addr show              # current IP addresses on all interfaces
ip route show               # current routing table
cat /etc/resolv.conf         # currently active DNS servers (may be managed automatically)
resolvectl status            # DNS configuration on systemd-resolved systems
```

> **Note:** `ip` (from `iproute2`) is the modern standard for inspecting and configuring networking interactively, replacing the older `ifconfig`/`route`/`netstat` toolset, which is deprecated on most current distributions. Configuration *persistence* across reboots, however, still depends on the distro-specific tools above (Netplan, NetworkManager, etc.) — changes made with plain `ip` commands are typically temporary unless also written into the persistent config.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Show interfaces (link state) | `ip link show` |
| Show IP addresses | `ip addr show` |
| Show IPv6 addresses | `ip -6 addr show` |
| Show routing table | `ip route show` |
| Show hostname | `hostname` or `hostnamectl` |
| Set hostname | `sudo hostnamectl set-hostname name` |
| Show DNS config (systemd) | `resolvectl status` |
| Test connectivity by IP | `ping 8.8.8.8` |
| Test connectivity + DNS | `ping google.com` |
| Apply Netplan config (Debian/Ubuntu) | `sudo netplan apply` |
| Show NetworkManager connections | `nmcli connection show` |
| Bring up a NetworkManager connection | `sudo nmcli connection up name` |

---

## 💡 Best Practices

- Troubleshoot bottom-up through the OSI layers — confirm the interface is up and has an IP before investigating application-level failures.
- Use `ip` commands for live inspection and temporary changes; use your distro's persistent config tool (Netplan, NetworkManager) for anything that should survive a reboot.
- Don't assume `eth0`/`wlan0` naming on modern systems — check `ip link show` for the actual predictable names in use (`enp3s0`, `wlp2s0`, etc.).
- Remember `/etc/hosts` is checked before DNS — useful for local overrides, but a forgotten stale entry there is a classic, hard-to-spot cause of "wrong server" connectivity issues.
- When debugging "internet doesn't work," separate IP-level reachability (`ping <IP>`) from DNS resolution (`ping <hostname>`) — they fail for very different reasons.
- For IPv6, remember NAT typically isn't in play — reachability issues are more likely to be firewall rules than address translation.