# Linux Security Principles

A reference guide to the foundational concepts underlying Linux hardening — least privilege, defense in depth, attack surface reduction, and secure configuration baselines. These ideas don't map to single commands; they're the reasoning behind why the commands in other guides matter.

---

## 🔑 Principle of Least Privilege

### The Core Idea

Every user, process, and service should have **only the access it actually needs to do its job** — nothing more. Excess privilege doesn't add value when everything is working correctly; it only adds risk when something goes wrong, since whatever excess access exists becomes available to whatever compromises that account or process.

### Where This Shows Up Across Linux

| Mechanism | How it implements least privilege |
|---|---|
| Dedicated service accounts | A web server runs as `www-data`, not root — a compromise of the web server doesn't hand over the whole system (see *User Account Basics*) |
| File permissions | A config file containing secrets is `600`, readable only by its owner, not world-readable `644` (see *Permissions and Modes*) |
| `sudo` scoping | A deploy account can run one specific script as root, not `ALL=(ALL) ALL` (see *sudo and Privilege Management*) |
| Group-based access | A `developers` group gets write access to a shared directory; everyone else gets read-only or nothing (see *Group Management*) |
| systemd service hardening | `User=`/`Group=` directives run a service as an unprivileged account rather than defaulting to root (see *systemd Service Files*) |

### Why "It's Easier With More Access" Is the Wrong Frame

Granting broad access (running everything as root, `chmod 777`-ing a directory to "make the permission errors go away") often *feels* like the pragmic choice under time pressure — it removes an immediate friction point. But it converts a contained, well-understood risk (this specific process can fail or be compromised, with bounded consequences) into an open-ended one (this specific process failing or being compromised now means *everything* is compromised). The friction that least-privilege configuration introduces is, in a meaningful sense, the entire point — it's bounding the blast radius of an eventual mistake or compromise that hasn't happened yet, but should be assumed to be possible.

### A Practical Test

Before granting any access — a `sudo` rule, a file permission, a group membership — ask: **"What's the most specific grant that still lets this work?"** rather than **"What grant definitely won't cause a problem?"** The first question converges on least privilege; the second tends to converge on "just give it everything," since broad access is rarely the thing that visibly "causes a problem" in the moment it's granted — only later, if and when something goes wrong.

---

## 🧱 Defense in Depth

### The Core Idea

No single security control is perfect — every mechanism has failure modes, bypasses, or simply hasn't been discovered yet. **Defense in depth** means layering multiple, independent controls so that the failure of any *one* layer doesn't equal a full compromise — the next layer is still there.

### A Layered View of a Typical Linux Server

```
┌─────────────────────────────────────────────┐
│ Network firewall / cloud security group       │  ← outermost layer
├─────────────────────────────────────────────┤
│ Host firewall (iptables/nftables)               │
├─────────────────────────────────────────────┤
│ SSH hardening (key-only auth, no root login)      │
├─────────────────────────────────────────────┤
│ sudo (scoped privilege escalation, not shared root)│
├─────────────────────────────────────────────┤
│ File permissions / ownership                        │
├─────────────────────────────────────────────┤
│ Application-level authentication/authorization        │
├─────────────────────────────────────────────┤
│ Encryption at rest (LUKS)                                │  ← innermost layer
└─────────────────────────────────────────────┘
```

Each layer connects to a guide elsewhere in this series: *Firewalls and iptables*, *Authentication and Passwords*, *sudo and Privilege Management*, *Permissions and Modes*, *Storage Encryption*.

### Why Layering Matters in Practice

Consider what happens if an attacker bypasses just the **network firewall** (e.g. via a misconfigured cloud security group, or a legitimately exposed port):

- **Without defense in depth:** if that's the only control, the attacker now has direct access to whatever's listening.
- **With defense in depth:** they still face the host firewall, then SSH key-only authentication, then `sudo` scoping even if they get a foothold, then file permissions even if they get a shell, then encryption if they somehow get raw disk access.

No individual layer needs to be "unbreakable" — the layering itself is what provides resilience. This is also why a security mindset resists "we have a firewall, so we don't need to worry about X" reasoning — defense in depth specifically assumes any *one* layer might fail or be bypassed.

### Defense in Depth Doesn't Mean "More Controls Are Always Better"

Layering has to be **coherent**, not just numerous — five redundant, unmonitored controls add complexity (and potential for misconfiguration) without necessarily adding resilience, while operational overhead and false confidence are real costs. The goal is *independent* layers that fail differently from each other, not duplicated versions of the same control.

---

## 🎯 Attack Surface Reduction

### The Core Idea

**Attack surface** is the sum of everything an attacker could potentially target — every open port, every running service, every installed package, every enabled feature. Reducing it means removing or disabling anything that isn't actually needed, on the reasoning that **code/services that don't exist or aren't running can't be exploited**, regardless of how well-defended they might otherwise be.

### Where This Shows Up Practically

```bash
# What's actually listening right now? (see the Linux Network Tools guide)
sudo ss -tulnp

# What services are enabled, even if not currently visible as a problem?
systemctl list-units --type=service --state=running

# What's installed that might not be needed? (see the Package Management guides)
apt list --installed     # or: dnf list installed
```

| Reduction tactic | Effect |
|---|---|
| Disable unused services | A service that isn't running can't be exploited, regardless of how vulnerable it might theoretically be |
| Close unused ports (firewall rules) | Even a running service becomes unreachable from outside if nothing can route to its port |
| Uninstall unnecessary packages | Removes the *possibility* of a vulnerability in that package mattering at all — see *Package Security and Updates* |
| Disable unused kernel modules/features | Reduces kernel-level attack surface, relevant for more advanced hardening |
| Remove default/sample accounts and content | Many default installs ship example users, default credentials, or sample apps not meant for production — these are common, well-known targets |

### Why This Complements (Rather Than Replaces) Patching

Keeping software updated (see *Package Security and Updates*) addresses **known vulnerabilities in things you've decided to run**. Attack surface reduction addresses a different question: **do you need to be running this at all?** A service you've fully removed has zero ongoing patching burden and zero exposure, regardless of what vulnerabilities are later discovered in it — this is generally a stronger position than "patched quickly" for anything genuinely unnecessary.

### A Practical Heuristic

For any running service, open port, or installed package on a system you're responsible for, ask: **"Do I know specifically why this needs to be here?"** If the honest answer is "it came with the default install" or "someone set this up a long time ago and I'm not sure," that's a candidate for removal, not a vote of confidence in keeping it — unused surface accumulates silently over a system's lifetime unless someone periodically reviews and prunes it.

---

## ⚙️ Secure Configuration Baselines

### The Core Idea

A **secure baseline** is a documented, repeatable starting configuration that's deliberately hardened before a system is exposed to any real use — rather than starting from whatever a default install happens to ship with (which is typically optimized for ease of initial setup, not security) and hardening reactively after something goes wrong.

### Why Defaults Are Often Not Secure-By-Default

Default configurations across most software prioritize **minimizing friction during initial setup** — broad permissions, permissive firewall rules (or none), sample content, verbose error messages, debug modes left on. These choices make sense for getting something running quickly during evaluation, but are frequently the wrong choices for a system handling real data or real traffic. Treating "the defaults" as "the secure choice" is one of the most common gaps between a fresh install and a genuinely hardened one.

### Established Baseline Frameworks

Rather than improvising hardening steps from scratch, several widely recognized frameworks codify secure baselines for specific operating systems and applications:

| Framework | What it provides |
|---|---|
| **CIS Benchmarks** (Center for Internet Security) | Detailed, versioned hardening guides for specific OS/application versions, with explicit rationale per recommendation |
| **DISA STIGs** (Security Technical Implementation Guides) | Similar in spirit, used heavily in U.S. government/defense contexts |
| **NIST guidelines** | Broader security framework guidance, often referenced by the above |
| Vendor hardening guides | Distribution-specific guidance (e.g. from Red Hat, Canonical) tailored to that specific OS |

```bash
# OpenSCAP can audit a system against a CIS or STIG profile directly (see the Package Security and Updates guide)
sudo oscap xccdf eval --profile cis_level1 --results results.xml /path/to/scap-content.xml
```

> **Note:** These frameworks are extensive, and not every recommendation applies equally to every environment — they're a structured starting point and a way to systematically evaluate gaps, not a checklist to apply blindly without considering your specific system's actual requirements.

### Establishing Your Own Baseline

For environments without a formal compliance requirement, a practical baseline still benefits from being **explicit and repeatable** rather than ad hoc:

- A documented list of what should be installed, enabled, and configured on a "standard" system of a given type.
- A way to provision new systems consistently against that baseline (configuration management tools, base images, automated provisioning scripts) rather than manually configuring each one slightly differently.
- A periodic process for reviewing whether the baseline itself still reflects current best practice, since "secure" is a moving target as new vulnerability classes and mitigations emerge.

### Baseline Drift

Even a system provisioned correctly against a good baseline tends to **drift** over time — a port opened temporarily for debugging and never closed, a package installed for a one-off task and never removed, a permission loosened to unblock something urgent and never tightened back. None of these individual changes looks alarming in isolation; the risk is cumulative and gradual.

```bash
# Periodically re-comparing current state against the intended baseline catches drift
# (Specific tooling varies — configuration management systems, OpenSCAP re-scans,
#  or simply a scheduled manual review against the documented baseline.)
```

> **Tip:** Treat a secure baseline as something requiring periodic re-verification, not a one-time setup task — the gap between "configured securely once" and "still configured securely now" tends to widen continuously and invisibly unless something actively checks for it.

---

## 🧭 How These Principles Relate to Each Other

These four ideas aren't independent checklist items — they reinforce each other:

- **Least privilege** limits what any single compromised account/process can do.
- **Defense in depth** ensures that even if least privilege fails at one layer (a service does have more access than ideal), other layers still constrain the damage.
- **Attack surface reduction** shrinks the number of places where a failure in either of the above could even be triggered in the first place.
- **Secure baselines** are how you actually *operationalize* the other three — turning "we should do least privilege" into a concrete, repeatable, auditable starting configuration, rather than a principle everyone agrees with but no one consistently applies.

> **The throughline:** none of these principles assume a system is perfectly secure. They all assume failures, mistakes, and compromises are *possible* and *eventually likely* over a long enough timeline — and they're each, in a different way, about bounding the consequences when that happens, rather than betting everything on prevention alone.

---

## ⚡ Quick Reference

| Principle | One-line summary | Where it's implemented |
|---|---|---|
| Least privilege | Grant only the access actually needed | Service accounts, permissions, sudo scoping, group design |
| Defense in depth | Layer independent controls so no single failure is total | Firewalls, auth, sudo, permissions, encryption together |
| Attack surface reduction | Remove what isn't needed; it can't be exploited if it doesn't exist | Disabling unused services, closing ports, uninstalling packages |
| Secure baselines | Start hardened, don't harden reactively after exposure | CIS/STIG frameworks, documented and repeatable provisioning |

---

## 💡 Best Practices

- Ask "what's the most specific grant that still works" rather than "what grant definitely won't cause problems" when configuring any access control — the framing shapes the outcome.
- Build layered defenses deliberately, but keep them coherent — independent layers that fail differently are more valuable than many redundant copies of the same control.
- Periodically audit running services, open ports, and installed packages against "do I know why this is here" — unused attack surface accumulates silently without active review.
- Treat default configurations as a starting point for hardening, not as an already-secure state — most defaults optimize for ease of initial setup, not security.
- Adopt an established framework (CIS Benchmarks, vendor hardening guides) as a structured starting point rather than improvising a baseline from scratch.
- Schedule periodic re-verification against your baseline — configuration drift is gradual, cumulative, and easy to miss without an active, recurring check.
- Remember all four principles assume eventual failure is possible — they're about bounding consequences, not promising perfect prevention.