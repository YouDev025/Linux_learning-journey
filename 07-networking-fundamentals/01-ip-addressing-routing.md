# IP Addressing and Routing

A reference guide to assigning IP addresses and configuring routing on Linux — subnetting math, static vs. dynamic addressing, routing tables, and the tools to inspect and troubleshoot all of it.

---

## 🧮 Subnetting Fundamentals

### Network Mask and CIDR

A **subnet mask** divides an IP address into a network portion and a host portion. **CIDR notation** (`/24`) expresses the same thing more compactly — the number of leading bits that make up the network portion.

```
192.168.1.10/24
              │
              └── 24 bits = network portion; remaining 8 bits = host portion
```

| CIDR | Subnet Mask | Binary (last octet) | Total Addresses | Usable Hosts |
|---|---|---|---|---|
| `/24` | `255.255.255.0` | `00000000` | 256 | 254 |
| `/25` | `255.255.255.128` | `10000000` | 128 | 126 |
| `/26` | `255.255.255.192` | `11000000` | 64 | 62 |
| `/27` | `255.255.255.224` | `11100000` | 32 | 30 |
| `/28` | `255.255.255.240` | `11110000` | 16 | 14 |
| `/30` | `255.255.255.252` | `11111100` | 4 | 2 |

> **Why "usable" is 2 less than "total":** every subnet reserves its **first address** as the network identifier and its **last address** as the broadcast address — neither is assignable to a host. A `/30` (4 total addresses) is the smallest subnet that still has 2 usable hosts, which is why it's the standard choice for point-to-point links.

### Working Out a Subnet by Hand

Given `192.168.1.0/26`:

```
/26 → 6 bits for hosts → 2^6 = 64 total addresses
Network address:    192.168.1.0      (first address — reserved)
Usable range:        192.168.1.1  →  192.168.1.62
Broadcast address:   192.168.1.63    (last address — reserved)
```

The next subnet would start immediately after: `192.168.1.64/26`.

### Quick Reference: Powers of Two

| Host bits | Total addresses | Usable hosts |
|---|---|---|
| 1 | 2 | 0 |
| 2 | 4 | 2 |
| 3 | 8 | 6 |
| 4 | 16 | 14 |
| 5 | 32 | 30 |
| 6 | 64 | 62 |
| 7 | 128 | 126 |
| 8 | 256 | 254 |

> **Tip:** Most subnetting questions reduce to "how many host bits do I have, and what's `2^n - 2`?" — once that's automatic, deriving network/broadcast addresses for any CIDR becomes fast.

### Using Tools Instead of Hand Math

```bash
ipcalc 192.168.1.0/26          # full breakdown: network, broadcast, range, mask (install if missing)
sipcalc 192.168.1.0/26          # alternative calculator, also supports IPv6
```

```bash
# ipcalc output example:
Address:   192.168.1.0
Netmask:   255.255.255.192 = 26
Network:   192.168.1.0/26
HostMin:   192.168.1.1
HostMax:   192.168.1.62
Broadcast: 192.168.1.63
```

---

## 🔍 Inspecting Addresses: `ip addr`

```bash
ip addr show              # all interfaces
ip addr show eth0          # one specific interface
ip -4 addr show             # IPv4 only
ip -6 addr show             # IPv6 only
```

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 192.168.1.50/24 brd 192.168.1.255 scope global eth0
    inet6 fe80::a00:27ff:fe4e:66a3/64 scope link
```

| Field | Meaning |
|---|---|
| `inet` | IPv4 address assigned to this interface |
| `inet6` | IPv6 address assigned to this interface |
| `brd` | Broadcast address for this subnet |
| `scope global` | Routable beyond the local link |
| `scope link` | Only valid on this local network segment |

### Adding and Removing Addresses (Temporary)

```bash
sudo ip addr add 192.168.1.51/24 dev eth0      # add an address — lost on reboot
sudo ip addr del 192.168.1.51/24 dev eth0      # remove it
sudo ip link set eth0 up                        # bring an interface up
sudo ip link set eth0 down                       # bring it down
```

> **Note:** Changes made with `ip addr add`/`del` are **not persistent** — they vanish on reboot or interface reset. For permanent configuration, use your distribution's config tool (Netplan, NetworkManager) — see the *Networking Basics* guide.

---

## 🛣️ Routing Tables: `ip route`

A **routing table** tells the kernel which interface (and which next-hop, if any) to use for traffic destined for a given network.

```bash
ip route show
ip route show table main      # explicit, equivalent to plain "ip route show" on most systems
```

```
default via 192.168.1.1 dev eth0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.50
10.0.0.0/8 via 192.168.1.1 dev eth0
```

### Reading a Route Entry

```
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.50
       │            │              │                    │
       │            │              │                    └── source address used for packets via this route
       │            │              └── scope: reachable directly, no gateway needed
       │            └── outgoing interface
       └── destination network
```

```
default via 192.168.1.1 dev eth0
   │            │              │
   │            │              └── outgoing interface
   │            └── next-hop gateway IP
   └── matches ANY destination not matched by a more specific route
```

### How the Kernel Chooses a Route: Longest Prefix Match

When multiple routes could match a destination, the kernel picks the **most specific** one — the route with the longest matching prefix (highest CIDR number) wins, falling back to less specific routes, and ultimately to `default` if nothing else matches.

```
Destination: 192.168.1.75

Candidate routes:
  192.168.1.0/24   ← matches, /24 prefix
  192.168.0.0/16   ← also matches, but /16 is LESS specific
  default (0.0.0.0/0) ← always matches, least specific

Winner: 192.168.1.0/24 (longest matching prefix)
```

### Adding and Removing Routes (Temporary)

```bash
sudo ip route add 10.0.0.0/8 via 192.168.1.1            # route a specific network via a gateway
sudo ip route add 192.168.2.0/24 dev eth1                # route via a specific interface directly
sudo ip route del 10.0.0.0/8                              # remove a route
sudo ip route add default via 192.168.1.1                 # set a default gateway
```

> ⚠️ **Caution:** Like `ip addr`, routes added with `ip route add` are **temporary** — gone after reboot unless also written into persistent configuration (Netplan, NetworkManager, or `/etc/network/interfaces`, depending on distro).

---

## 🌐 The Default Gateway

The **default gateway** is the route used when no more specific route matches — typically your router, responsible for forwarding traffic onward to the wider network/internet.

```bash
ip route show default
# default via 192.168.1.1 dev eth0
```

### Why It's Called "Default"

Every host on a subnet can usually reach other hosts on that *same* subnet directly (no gateway needed — see `scope link` above). But reaching anything **outside** the local subnet requires forwarding through a device that has a path elsewhere — that device is the default gateway.

```
Your machine: 192.168.1.50/24
Destination:   8.8.8.8           ← outside the local subnet
                                  → no specific route matches
                                  → falls through to default route
                                  → forwarded to gateway 192.168.1.1
                                  → gateway forwards it onward
```

### Common Troubleshooting Pattern

```bash
ip route show default                    # is a default gateway even configured?
ping -c 3 192.168.1.1                     # can we reach the gateway itself?
ping -c 3 8.8.8.8                          # can the gateway forward us further?
traceroute 8.8.8.8                          # where exactly does the path break, if it does?
```

If you can reach the gateway but not beyond it, the problem is likely on the gateway/ISP side, not your local configuration.

---

## 📌 Static vs. Dynamic Addressing

### Static Addressing

The administrator manually assigns a fixed IP, subnet mask, gateway, and DNS servers — the address never changes unless someone changes it.

**When to use it:** servers, printers, network infrastructure (routers, switches) — anything other devices need to reliably find at a consistent, predictable address.

```yaml
# Netplan example (Debian/Ubuntu)
network:
  ethernets:
    eth0:
      addresses: [192.168.1.50/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8]
```

### Dynamic Addressing (DHCP)

A **DHCP server** automatically assigns an IP address (and gateway, DNS, etc.) to devices when they join the network, typically leasing the address for a limited time and renewing it periodically.

**When to use it:** laptops, phones, general end-user devices — anything that doesn't need a predictable address and benefits from zero manual configuration.

```yaml
# Netplan example
network:
  ethernets:
    eth0:
      dhcp4: true
```

```bash
sudo dhclient eth0           # manually request/renew a DHCP lease
ip addr show eth0 | grep inet # check the address that was actually assigned
cat /var/lib/dhcp/dhclient.leases   # (varies by distro) view current lease details
```

### Comparison

| | Static | Dynamic (DHCP) |
|---|---|---|
| Address stability | Fixed, predictable | Can change between leases |
| Setup effort | Manual, per device | Automatic |
| Best for | Servers, infrastructure | End-user devices |
| Central management | None built-in | DHCP server controls assignment/leases |
| Renaming/reorganizing a network | Requires touching every device | Just update the DHCP server config |

### DHCP Reservations: A Middle Ground

Many DHCP servers support **reservations** — binding a specific IP to a device's MAC address, so it always receives the same address via DHCP without static configuration on the device itself. This combines DHCP's zero-config convenience with static addressing's predictability, and is common for things like network printers or home servers.

---

## 🔧 Troubleshooting Workflow

A practical, layered troubleshooting sequence for "this machine can't reach something":

```bash
# 1. Does the interface have an address at all?
ip addr show

# 2. Is there a default route?
ip route show default

# 3. Can we reach the gateway? (tests local network/Layer 2-3)
ping -c 3 <gateway-ip>

# 4. Can we reach something outside the network by IP? (tests routing beyond the gateway)
ping -c 3 8.8.8.8

# 5. Can we resolve names? (tests DNS specifically, separate from IP routing)
ping -c 3 google.com

# 6. Where exactly does the path break, if any step above fails?
traceroute 8.8.8.8
mtr 8.8.8.8          # combines ping + traceroute, continuously, if installed
```

> **Tip:** This sequence deliberately separates "can I route at all" (steps 1–4) from "does DNS work" (step 5) — a huge share of "the internet is down" reports turn out to be DNS-only failures, where raw IP connectivity is actually fine.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Show all IP addresses | `ip addr show` |
| Show one interface's address | `ip addr show eth0` |
| Add a temporary address | `sudo ip addr add IP/CIDR dev iface` |
| Show routing table | `ip route show` |
| Show just the default route | `ip route show default` |
| Add a temporary route | `sudo ip route add NETWORK via GATEWAY` |
| Set a temporary default gateway | `sudo ip route add default via GATEWAY` |
| Calculate subnet details | `ipcalc IP/CIDR` |
| Request/renew a DHCP lease | `sudo dhclient eth0` |
| Test reachability | `ping -c 3 TARGET` |
| Trace the path to a destination | `traceroute TARGET` or `mtr TARGET` |

---

## 💡 Best Practices

- Remember `ip addr`/`ip route` changes are temporary — always also update persistent config (Netplan, NetworkManager) for anything that should survive a reboot.
- Use `ipcalc`/`sipcalc` to double-check subnet math rather than hand-calculating for anything beyond a quick `/24`-style sanity check — off-by-one errors in network/broadcast addresses are a common source of subtle bugs.
- Reserve static addressing for servers and infrastructure; use DHCP (with reservations where predictability is needed) for everything else — it scales far better as a network grows.
- Troubleshoot connectivity in layered order: address → default route → gateway reachability → beyond-gateway reachability → DNS. Skipping ahead tends to misdiagnose DNS issues as "the network is down" or vice versa.
- When multiple routes could apply, remember the kernel always prefers the most specific (longest prefix) match — useful for predicting which route will actually be used before you test it.
- Use DHCP reservations for devices that need a stable address (printers, home servers) but don't warrant full manual static configuration.