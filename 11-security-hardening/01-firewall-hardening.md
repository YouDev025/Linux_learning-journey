# Firewall Hardening

A practical reference for using Linux firewall controls to actually reduce network exposure — default policies, `ufw` for everyday management, and concrete hardening steps for the services most commonly exposed (SSH, HTTP, application ports).

---

## 🧱 Default Policies: The Foundation of Hardening

### Default Deny vs. Default Allow

The single most consequential firewall decision is the **default policy** — what happens to traffic that doesn't match any explicit rule.

| Policy | Behavior | Security posture |
|---|---|---|
| **Default deny** | Block everything not explicitly allowed | Strong — new services are unreachable until deliberately opened |
| **Default allow** | Allow everything not explicitly blocked | Weak — every new service is exposed by default, whether intended or not |

```
Default DENY mindset:
   "Nothing gets through unless I specifically said it could."
   → A new service you forget to firewall stays SAFE (unreachable) until you act.

Default ALLOW mindset:
   "Everything gets through unless I specifically blocked it."
   → A new service you forget to firewall is IMMEDIATELY EXPOSED until you notice.
```

This connects directly to **attack surface reduction** (see the *Linux Security Principles* guide) — a default-deny posture means attack surface only grows through deliberate action, rather than by default/accident.

> **The practical implication:** with default-deny, a mistake (forgetting to add a firewall rule for something) fails *safe* — the thing is just unreachable until fixed. With default-allow, the same kind of mistake fails *open* — exposure happens silently, often discovered only during an audit or, worse, an incident. This asymmetry is why default-deny is the standard recommendation for any system handling real traffic or data.

### Setting a Default-Deny Policy with `ufw`

```bash
sudo ufw default deny incoming      # the foundational rule — set this FIRST
sudo ufw default allow outgoing      # outbound is commonly left open; restricting it is a more advanced, deliberate choice
```

> **Why outbound is usually left open:** restricting outbound traffic (egress filtering) is valuable defense-in-depth — it can limit what a compromised process can reach or exfiltrate to — but it requires explicitly allowing everything the system legitimately needs to reach out for (package updates, DNS, NTP, application dependencies), which is meaningfully more setup effort. Many environments accept open egress as a pragmatic tradeoff; more security-sensitive environments deliberately restrict it too.

---

## 🔰 `ufw` — Beginner-Friendly Firewall Management

`ufw` ("Uncomplicated Firewall") provides a simple command syntax over the same underlying `iptables`/`nftables` engine covered in the *Firewalls and iptables* guide — appropriate for the large majority of single-host firewall needs without needing to write raw rules directly.

### Checking Current Status

```bash
sudo ufw status              # is it even enabled? what rules exist?
sudo ufw status verbose        # more detail, including default policies
sudo ufw status numbered        # numbered rule list — useful for deleting specific rules later
```

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

### Enabling `ufw`

```bash
sudo ufw enable
```

> ⚠️ **Critical caution, especially over SSH:** enabling `ufw` with a default-deny incoming policy and **no SSH rule already in place** will lock you out of a remote system instantly. **Always add and confirm your SSH rule BEFORE enabling the firewall** — see the dedicated SSH section below. This mirrors the exact same risk called out for raw `iptables` in the *Firewalls and iptables* guide.

### Basic Allow/Deny Rules

```bash
sudo ufw allow 22/tcp                    # allow a port, any protocol direction implied as "in"
sudo ufw allow ssh                          # equivalent, using the service name from /etc/services
sudo ufw deny 23                              # explicitly deny a port (Telnet, in this example — see below)
sudo ufw delete allow 23                        # remove a specific rule
```

### Restricting by Source

```bash
sudo ufw allow from 192.168.1.0/24 to any port 22         # only this subnet can reach SSH
sudo ufw allow from 203.0.113.50 to any port 22             # only this SPECIFIC IP
sudo ufw allow from 192.168.1.0/24 to any port 5432 proto tcp  # restrict a database port to an internal subnet
```

> **Tip:** Restricting *source* is one of the highest-value, most underused hardening steps for anything that doesn't genuinely need to be reachable from the entire internet — an admin interface, a database port, an internal API. "Open to everyone" and "open to anyone who legitimately needs it" are very different attack surfaces.

### Rate Limiting (Basic Brute-Force Mitigation)

```bash
sudo ufw limit ssh                  # automatically throttles repeated connection attempts from the same IP
sudo ufw limit 22/tcp
```

`limit` denies an IP if it attempts more than roughly 6 connections within 30 seconds — a basic but genuinely useful mitigation against naive automated brute-force attempts (see the *Authentication and Passwords* guide for more on why offline/online brute-force resistance matters).

### Application Profiles

`ufw` can reference pre-defined application profiles instead of remembering specific port numbers:

```bash
sudo ufw app list                    # list available application profiles
sudo ufw allow "Nginx Full"            # allows both HTTP (80) and HTTPS (443)
sudo ufw allow "OpenSSH"                 # equivalent to allow 22/tcp, but more self-documenting
```

### Logging

```bash
sudo ufw logging on
sudo ufw logging medium       # off / low / medium / high / full
```

```bash
sudo tail -f /var/log/ufw.log    # watch firewall activity live
grep "BLOCK" /var/log/ufw.log      # review what's been blocked
```

> **Tip:** Enable at least `low` or `medium` logging from the start — a firewall with no visibility into what it's actually blocking (or allowing) makes troubleshooting connectivity issues and detecting probing/scanning activity much harder after the fact.

---

## 🔐 Hardening SSH

SSH is almost universally the **highest-value target** to harden specifically — it's the standard remote administration path on most Linux servers, internet-facing by necessity in many deployments, and a constant target of automated scanning/brute-force traffic.

### Firewall-Level Hardening

```bash
sudo ufw limit ssh                                            # rate-limit brute-force attempts
sudo ufw allow from 203.0.113.0/24 to any port 22                # restrict to known admin source ranges, if feasible
```

### Beyond the Firewall: SSH Configuration Itself

Firewall rules control *who can reach* SSH at all — but genuine hardening also requires configuring the SSH daemon itself (`/etc/ssh/sshd_config`), since a reachable-but-misconfigured SSH service is still a major exposure:

```
# /etc/ssh/sshd_config
PermitRootLogin no              # force admins to log in as themselves, then escalate via sudo (see sudo guide)
PasswordAuthentication no         # require key-based auth — far more resistant to brute-force than passwords
PubkeyAuthentication yes
```

```bash
sudo systemctl restart sshd
```

> **Why this section belongs in a firewall-hardening guide too:** firewall rules and service configuration are complementary, not redundant — a firewall that only allows trusted IPs to reach SSH, combined with key-only authentication on SSH itself, is meaningfully stronger than either control alone. This is **defense in depth** in direct practice (see the *Linux Security Principles* guide).

### Considering a Non-Default Port (With Caveats)

```bash
sudo ufw allow 2222/tcp     # if SSH has been moved to a non-standard port
```

> **Honest caveat:** moving SSH off port 22 reduces *casual, automated, port-22-only* scanning noise in logs, but provides essentially no protection against a remotely competent or targeted attacker, who will simply port-scan and find it. Treat this as a minor noise-reduction tactic at best, never as a meaningful security control on its own — it should never be the *only* SSH hardening step taken.

---

## 🌐 Hardening HTTP/HTTPS

### Basic Web Server Exposure

```bash
sudo ufw allow "Nginx Full"          # or: sudo ufw allow 80,443/tcp
```

### Redirecting HTTP to HTTPS (Application-Level, Not Firewall-Level)

The firewall simply controls *reachability* — actually enforcing HTTPS-only access happens in the web server's own configuration (an nginx/Apache redirect rule), which is outside the firewall's scope but worth noting as the natural next hardening step once port 80/443 access is firewall-permitted.

### Restricting Admin/Management Endpoints

A common real-world pattern: the main site is public, but an admin panel or management interface on the same host should not be:

```bash
sudo ufw allow 80,443/tcp                                     # public web traffic — open to everyone
sudo ufw allow from 192.168.1.0/24 to any port 8443              # admin interface — internal subnet only
```

> **Tip:** Don't rely solely on "the admin panel has its own login" as the only protection for a sensitive management interface — combining authentication (defense layer 1) with restricted network reachability (defense layer 2) means a leaked/guessed credential alone isn't sufficient for an external attacker to even reach the login prompt in the first place.

---

## 🎯 Hardening Application-Specific Ports

### The General Pattern

For any application port beyond the universally-exposed web/SSH cases, the same questions apply every time:

1. **Does this genuinely need to be reachable from the public internet at all?** (Often: no — many "ports" are actually meant for internal service-to-service communication.)
2. **If yes, from literally anywhere, or from a known, bounded set of sources?**
3. **Is there an additional layer (application auth, mutual TLS, a VPN) that should also be required, rather than relying on the firewall as the only control?**

### Example: A Database Port

```bash
# WRONG for most deployments — exposes the database to the entire internet:
sudo ufw allow 5432/tcp

# RIGHT — only the application server(s) that actually need it can reach it:
sudo ufw allow from 10.0.1.5 to any port 5432 proto tcp
```

### Example: An Internal API or Cache

```bash
sudo ufw allow from 10.0.0.0/16 to any port 6379 proto tcp    # Redis — internal network range only, never public
```

### Example: A Monitoring/Metrics Endpoint

```bash
sudo ufw allow from 10.0.2.10 to any port 9100 proto tcp    # node_exporter — only the monitoring server needs this
```

> **A useful default assumption:** unless a port is specifically meant to serve the general public (HTTP/HTTPS being the obvious case, SSH being the controlled-administrative case), assume it should be restricted to known internal sources until proven otherwise — not opened broadly "to be safe" or "in case something else needs it later." The earlier *Linux Security Principles* guide's framing applies directly: ask what's the most specific grant that still works, not what definitely won't cause an immediate problem.

---

## 🧭 A Practical Hardening Checklist

```bash
# 1. Confirm current state before changing anything
sudo ufw status verbose

# 2. Set default-deny incoming, default-allow outgoing (the foundational posture)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 3. Allow SSH FIRST, with rate limiting, before enabling — this is the step most likely to lock you out if skipped
sudo ufw limit ssh

# 4. Allow whatever this specific host actually needs to serve publicly
sudo ufw allow "Nginx Full"

# 5. Restrict anything else (databases, admin panels, internal APIs) to known source ranges only
sudo ufw allow from 10.0.0.0/16 to any port 5432

# 6. Enable logging for ongoing visibility
sudo ufw logging medium

# 7. NOW enable the firewall
sudo ufw enable

# 8. Immediately verify you can still reach what you expect, from where you expect
sudo ufw status verbose
ssh -v your-host        # from a SEPARATE session/terminal — don't close your current one until this is confirmed
```

> ⚠️ **Critical operational habit:** never close your current SSH session while testing a new firewall configuration. Open a **second**, separate connection to verify access still works before disconnecting the session you're actively using to make changes — if the new rules lock you out, your original session is still there to fix it.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Check current status | `sudo ufw status verbose` |
| Set default-deny incoming | `sudo ufw default deny incoming` |
| Allow a port | `sudo ufw allow 22/tcp` |
| Allow by service name | `sudo ufw allow ssh` |
| Restrict to a specific source | `sudo ufw allow from IP/CIDR to any port PORT` |
| Rate-limit a port (brute-force mitigation) | `sudo ufw limit ssh` |
| Allow an application profile | `sudo ufw allow "Nginx Full"` |
| Delete a rule | `sudo ufw delete allow PORT` |
| Enable logging | `sudo ufw logging medium` |
| Enable the firewall | `sudo ufw enable` |
| List numbered rules (for deletion) | `sudo ufw status numbered` |

---

## 💡 Best Practices

- Always set default-deny incoming as the foundation — it ensures forgotten/future services fail safe (unreachable) rather than fail open (exposed).
- Add and confirm your SSH rule before ever enabling a default-deny firewall on a remote system — this is the single most common self-inflicted lockout in firewall hardening.
- Keep a second, separate SSH session open while testing new firewall rules — never rely on your only active connection to verify changes didn't lock you out.
- Restrict source IPs/ranges for anything that doesn't need to be reachable by the general public — this is one of the highest-value, most underused hardening steps available.
- Use `ufw limit` on SSH (and any other genuinely brute-forceable service) as a basic, low-effort mitigation against automated attack traffic.
- Treat a non-standard SSH port as noise reduction at best, never as a real security control — pair it with key-only authentication and source restriction, not instead of them.
- Enable firewall logging from the start — visibility into what's being blocked (or allowed) is essential for both troubleshooting and detecting probing activity.
- Default to restricting application-specific ports to known internal sources, and treat "open to everyone" as something that needs active justification, not a safe default.