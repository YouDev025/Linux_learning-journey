# SELinux and AppArmor

A reference guide to Linux's two major Mandatory Access Control (MAC) systems — how they extend beyond standard permissions, SELinux modes and contexts, AppArmor profiles, and troubleshooting access denials from either system.

---

## 🧱 Mandatory Access Control: Why It Exists Beyond Standard Permissions

### The Limitation of Discretionary Access Control (DAC)

Standard Linux permissions (`rwx`, ownership — see the *Permissions and Modes* and *Ownership* guides) are a form of **Discretionary Access Control**: the **owner** of a resource decides who can access it, and any process running as that owner can do anything that owner is allowed to do, system-wide, with no further constraint.

```
Standard permissions (DAC):
   A process running as "www-data" can access ANYTHING www-data has
   permission to access — there's no additional restriction on WHICH
   specific files a web server process "should" need, beyond ownership/mode.
```

This is the gap MAC closes: even if a process runs as a legitimate user with broad nominal permissions, MAC can additionally restrict **what that specific process is actually allowed to do**, based on policy the system administrator defines — independent of, and layered on top of, standard DAC.

### Mandatory vs. Discretionary

| | DAC (standard permissions) | MAC (SELinux/AppArmor) |
|---|---|---|
| Who decides access | The resource's owner | A system-wide policy, not overridable by the resource owner |
| Granularity | Per file/directory, by user/group/other | Per process, often per specific action/resource combination |
| Can the application override it | Effectively yes (it just uses what its owning user can access) | No — MAC policy applies regardless of what the process or its owning user could otherwise do |

> **Why this matters for compromised processes:** if a web server process is compromised (e.g. via an application vulnerability), DAC alone limits it to whatever the `www-data` user can access — which is often still a meaningful amount. A well-configured MAC policy can additionally confine that *specific process* to only the files and actions a web server actually needs, even though `www-data` as a user might nominally be permitted more. This is **defense in depth** (see the *Linux Security Principles* guide) applied at the kernel-enforcement level.

### SELinux vs. AppArmor: High-Level Comparison

| | SELinux | AppArmor |
|---|---|---|
| Default on | RHEL, Fedora, CentOS, Rocky, AlmaLinux | Ubuntu, SUSE, Debian (optional) |
| Access model | Label-based — every process and file gets a security context | Path-based — rules reference filesystem paths directly |
| Granularity | Generally finer-grained | Generally simpler, somewhat coarser |
| Learning curve | Steeper — context model takes time to internalize | Gentler — profiles read closer to plain permission rules |
| Policy format | Type Enforcement policies, often complex | Profiles per-application, more directly readable |

> **Neither is "better" in absolute terms** — they reflect different design philosophies (label-based vs. path-based) and different tradeoffs between granularity and approachability. Which one you're working with is determined by your distribution, not a choice you typically make independently.

---

## 🔴 SELinux

### SELinux Modes

SELinux operates in one of three modes, system-wide:

| Mode | Behavior |
|---|---|
| `enforcing` | Policy violations are BLOCKED and logged |
| `permissive` | Policy violations are ONLY logged, not blocked — useful for testing/troubleshooting policy without breaking anything |
| `disabled` | SELinux is fully off — no contexts applied, no checks performed |

```bash
getenforce                    # show current mode
sudo setenforce 0               # switch to permissive (temporary, until reboot or another setenforce)
sudo setenforce 1                # switch to enforcing
```

### Making a Mode Change Persistent

```bash
sudo nano /etc/selinux/config
```

```
SELINUX=enforcing
```

> ⚠️ **Caution:** `setenforce 0`/`1` only changes the **current runtime** mode — it does not survive a reboot unless `/etc/selinux/config` is also updated. A common mistake is testing in permissive mode, fixing the immediate symptom, and forgetting that a reboot will silently return to whatever `/etc/selinux/config` says — which may not be what was intended.

> **Disabling entirely is generally discouraged:** `disabled` mode means re-enabling later requires a full filesystem relabel (since files won't have been getting contexts applied while disabled) — `permissive` is almost always the better choice for troubleshooting, since it keeps contexts current while just not enforcing blocks.

### SELinux Contexts

Every process and file has a **security context** — a label describing its security-relevant identity, distinct from standard ownership.

```bash
ls -Z /var/www/html/index.html
# unconfined_u:object_r:httpd_sys_content_t:s0  index.html
```

```
unconfined_u : object_r : httpd_sys_content_t : s0
     │              │              │              │
     │              │              │              └── sensitivity level (relevant mainly in MLS configurations)
     │              │              └── TYPE — the most operationally important field for typical troubleshooting
     │              └── role
     └── SELinux user (distinct from the Linux user)
```

```bash
ps -eZ | grep nginx
# system_u:system_r:httpd_t:s0    1234 ?  nginx
```

| Field | Meaning |
|---|---|
| User | An SELinux-specific identity, distinct from the Linux account |
| Role | Groups related permissions, used in role-based policy designs |
| Type | The field that drives most policy decisions in practice — e.g. `httpd_t` (the process type) can access `httpd_sys_content_t` (the file type) |
| Level | Sensitivity/category, relevant in Multi-Level Security configurations (less common in typical deployments) |

> **The core enforcement idea:** SELinux policy largely works by defining which **process types** can interact with which **file/resource types** — `httpd_t` is allowed to read `httpd_sys_content_t`, for example, but not arbitrary other types, regardless of standard Unix permissions saying the `www-data` user could otherwise read that file.

### Managing Contexts

```bash
sudo chcon -t httpd_sys_content_t /var/www/html/newfile.html      # change a file's TYPE context
sudo restorecon -v /var/www/html/newfile.html                       # reset to whatever the POLICY says it should be
sudo restorecon -Rv /var/www/html/                                     # recursively, for an entire directory tree
```

> **`chcon` vs. `restorecon`:** `chcon` sets an arbitrary context you specify manually — useful for a one-off, but it won't survive certain operations (a full relabel, some package updates) since it's not derived from policy. `restorecon` instead applies whatever the **policy's own file-context rules** say a given path *should* have — generally the safer, more durable choice, since it stays consistent with policy rather than diverging from it.

### Common SELinux Booleans

SELinux policy includes many toggleable booleans for enabling/disabling specific behaviors without writing custom policy:

```bash
getsebool -a | grep httpd          # list httpd-related booleans and their current state
sudo setsebool -P httpd_can_network_connect on    # allow httpd to make outbound network connections, PERSISTENTLY (-P)
```

> **Tip:** Always use `-P` with `setsebool` when the change should persist — without it, the change is lost on reboot, similar to the `setenforce` persistence caveat above.

---

## 🟢 AppArmor

### AppArmor Profile Modes

AppArmor profiles (not the whole system at once, like SELinux's global mode) are individually set to one of two modes:

| Mode | Behavior |
|---|---|
| `enforce` | Policy violations are BLOCKED and logged |
| `complain` | Policy violations are ONLY logged, not blocked — the AppArmor equivalent of SELinux's permissive mode, but per-profile |

```bash
sudo aa-status            # overview of all profiles and their current mode
```

```
apparmor module is loaded.
32 profiles are loaded.
28 profiles are in enforce mode.
   /usr/sbin/nginx
   /usr/sbin/sshd
   ...
4 profiles are in complain mode.
   /usr/sbin/some-app
```

### Switching a Profile's Mode

```bash
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx       # switch ONE profile to enforce
sudo aa-complain /etc/apparmor.d/usr.sbin.nginx        # switch ONE profile to complain
sudo aa-disable /etc/apparmor.d/usr.sbin.nginx           # disable a profile entirely for this application
```

> **Key difference from SELinux right away:** AppArmor's enforce/complain switching is **per-profile**, not a single global system mode — you can have some applications strictly enforced while troubleshooting another in complain mode, simultaneously.

### AppArmor Profiles: Path-Based Rules

Unlike SELinux's label/type model, AppArmor profiles directly reference filesystem paths and specific capabilities:

```bash
cat /etc/apparmor.d/usr.sbin.nginx
```

```
#include <tunables/global>

/usr/sbin/nginx {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  network inet stream,
  network inet6 stream,

  /etc/nginx/** r,
  /var/log/nginx/*.log w,
  /var/www/html/** r,
  /usr/sbin/nginx mr,

  deny /etc/shadow r,
}
```

| Syntax element | Meaning |
|---|---|
| `r` | Read |
| `w` | Write |
| `x` | Execute |
| `m` | Memory-map executable (needed for the binary to run itself, typically) |
| `**` | Match any path depth (recursive glob) |
| `deny` | Explicitly deny, even if something else might otherwise allow it |
| `#include` | Pull in shared rule sets (abstractions) rather than rewriting common patterns per-profile |

> **Why this often feels more approachable than SELinux:** the rules read close to plain-English permission statements tied to actual filesystem paths — there's no separate label/type vocabulary to learn first, which is a meaningful part of why distributions like Ubuntu favor AppArmor as the default.

### Reloading a Profile After Editing

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx
```

```bash
sudo systemctl reload apparmor      # reload ALL profiles, alternative to reloading one at a time
```

### Generating a Profile from Observed Behavior

For a new application without an existing profile, `aa-genprof`/`aa-logprof` can build one interactively by observing what the application actually does:

```bash
sudo aa-genprof /usr/local/bin/myapp
# run the application normally while this is active, exercising its typical functionality,
# then return to the genprof prompt to review and approve/deny each observed action
```

```bash
sudo aa-logprof      # similar, but reviews EXISTING complain-mode log entries to refine an existing profile
```

> **Tip:** Building a profile this way (start in `complain`, exercise normal application behavior, then promote to `enforce` once the profile looks complete) is a common, practical workflow for confining a custom or third-party application that doesn't ship with its own profile.

---

## 🚨 Troubleshooting Access Denials

### SELinux: Reading Denials

```bash
sudo ausearch -m avc -ts recent              # AVC = Access Vector Cache — SELinux's denial-logging mechanism (see the Linux Audit and Hardening guide for ausearch generally)
sudo journalctl -t setroubleshoot              # if setroubleshoot is installed, human-readable denial summaries
```

```
type=AVC msg=audit(...): avc:  denied  { read } for  pid=1234 comm="nginx"
  name="secret.conf" dev="sda1" ino=5678
  scontext=system_u:system_r:httpd_t:s0
  tcontext=system_u:object_r:admin_home_t:s0
  tclass=file
```

| Field | Meaning |
|---|---|
| `denied { read }` | The specific action that was blocked |
| `scontext` | The SOURCE context (the process attempting the action) |
| `tcontext` | The TARGET context (the file/resource being accessed) |
| `tclass` | The object class involved (file, socket, etc.) |

> **Reading this denial:** `httpd_t` (nginx's process type) tried to `read` something with type `admin_home_t` (a type meant for admin home directory content, NOT web content) — policy correctly blocked this, because nginx genuinely shouldn't be reading arbitrary admin home directory files, regardless of standard Unix permissions potentially allowing it.

### Generating a Suggested Fix: `audit2allow`

```bash
sudo ausearch -m avc -ts recent | audit2allow -M mypolicy
```

This analyzes recent denials and generates a **custom policy module** that would have allowed the observed action(s):

```bash
sudo semodule -i mypolicy.pp        # install the generated policy module
```

> ⚠️ **Caution:** `audit2allow` tells you what policy **would silence the denial** — it does not tell you whether granting that access is actually a good idea. Blindly applying every `audit2allow` suggestion can recreate exactly the kind of broad, unjustified access MAC is designed to prevent in the first place. Review what's actually being granted, and prefer the more targeted fix (usually `restorecon`, fixing an incorrectly-applied context) over a custom policy module when the real issue is simply a mislabeled file.

### The Most Common Real Fix: `restorecon`, Not New Policy

In practice, the majority of SELinux "denials" on a system that was working before stem from a file having the **wrong context** — often because it was created, moved, or copied in a way that didn't preserve or correctly assign the expected type — rather than a genuine policy gap requiring a new rule.

```bash
sudo restorecon -Rv /var/www/html/        # the first thing to try, before reaching for audit2allow
```

### AppArmor: Reading Denials

```bash
sudo journalctl -k | grep -i apparmor
sudo dmesg | grep -i apparmor
```

```
audit: type=1400 audit(...): apparmor="DENIED" operation="open"
  profile="/usr/sbin/nginx" name="/etc/shadow" pid=1234 comm="nginx"
  requested_mask="r" denied_mask="r"
```

| Field | Meaning |
|---|---|
| `apparmor="DENIED"` | Confirms this was an AppArmor policy block |
| `profile=` | Which profile issued the denial |
| `name=` | The specific path being accessed |
| `requested_mask` / `denied_mask` | What access was attempted vs. what was actually denied |

> **Reading this denial:** the `nginx` profile attempted to `open`/`read` `/etc/shadow`, and was denied — correctly, since nothing about serving web content should ever require reading the shadow password file (see the *Authentication and Passwords* guide).

### Fixing an AppArmor Denial

```bash
sudo aa-logprof      # interactively review recent denials and decide whether to add a corresponding ALLOW rule
```

Or manually edit the profile to add the specific access that's genuinely needed, then reload:

```
/path/that/should/be/allowed/** r,
```

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
```

> **The same caution applies here as with `audit2allow`:** every denial is an opportunity to ask "does this application genuinely need this access," not just "how do I make the error go away." A denial blocking something the application legitimately needs is a configuration gap to fix; a denial blocking something unexpected is potentially a sign of misbehavior or compromise worth investigating before simply allowing it.

---

## 🧭 A General Troubleshooting Workflow (Either System)

```bash
# 1. Confirm the system/profile is even active, and in which mode
getenforce                          # SELinux
sudo aa-status                        # AppArmor

# 2. Reproduce the issue, then immediately check for a recent denial
sudo ausearch -m avc -ts recent                  # SELinux
sudo journalctl -k --since "5 min ago" | grep -i apparmor    # AppArmor

# 3. Determine: is this a CONTEXT/PATH problem, or a genuine missing-permission problem?
sudo restorecon -Rv /path/in/question            # SELinux — try this FIRST
# (AppArmor has no direct equivalent — it's purely rule-based, not context-based)

# 4. If restorecon didn't help (SELinux) or the access is genuinely new (AppArmor),
#    generate/review a targeted fix rather than disabling enforcement entirely
sudo ausearch -m avc -ts recent | audit2allow -M fixname    # SELinux
sudo aa-logprof                                                # AppArmor

# 5. Review what's actually being granted before applying it
cat fixname.te          # SELinux — read the generated policy BEFORE installing it
# (aa-logprof shows proposed rules interactively before you confirm each one)

# 6. Apply the reviewed fix, re-test
sudo semodule -i fixname.pp           # SELinux
sudo apparmor_parser -r /path/to/profile   # AppArmor
```

> **The single most important habit:** resist the reflex to disable MAC entirely (`setenforce 0` permanently, or `aa-disable` broadly) the moment something doesn't work. Use the temporary, diagnostic versions of these tools (`permissive`/`complain` modes) to identify the *specific* denial, fix that specific thing, and return to full enforcement — rather than abandoning the control altogether because troubleshooting it takes more effort than standard DAC permissions did.

---

## ⚡ Quick Reference

| Task | SELinux | AppArmor |
|---|---|---|
| Check current mode | `getenforce` | `sudo aa-status` |
| Temporarily relax enforcement | `sudo setenforce 0` | `sudo aa-complain /path/to/profile` |
| Restore full enforcement | `sudo setenforce 1` | `sudo aa-enforce /path/to/profile` |
| View a file/process's security label | `ls -Z` / `ps -eZ` | (path-based — no per-file label to inspect) |
| Fix an incorrectly labeled file | `sudo restorecon -Rv /path` | N/A (no context system) |
| View recent denials | `sudo ausearch -m avc -ts recent` | `sudo journalctl -k \| grep apparmor` |
| Generate a suggested policy fix | `audit2allow` | `sudo aa-logprof` |
| Build a profile for a new app | (uses existing distro policy) | `sudo aa-genprof /path/to/app` |
| Reload after editing | `sudo semodule -i file.pp` | `sudo apparmor_parser -r /path/to/profile` |

---

## 💡 Best Practices

- Never permanently disable SELinux/AppArmor as a first response to a denial — use `permissive`/`complain` mode temporarily to diagnose, then return to full enforcement once the specific issue is understood and fixed.
- Try `restorecon` before `audit2allow` for SELinux denials — most real-world denials on a previously-working system are mislabeled files, not genuine policy gaps.
- Review every `audit2allow`-generated policy and every `aa-logprof`-proposed rule before applying it — these tools tell you what would silence the denial, not whether granting that access is actually appropriate.
- Remember `setenforce`/`aa-enforce` mode changes are runtime-only — update `/etc/selinux/config` (SELinux) for persistence, or be aware AppArmor profile mode is generally set via the profile file itself or `aa-enforce`/`aa-complain` consistently.
- For new/custom applications under AppArmor, use the `aa-genprof` → exercise normal behavior → `enforce` workflow rather than writing a profile from scratch blind.
- Treat MAC denials as informative, not just obstacles — a denial blocking genuinely unexpected behavior may be a sign of compromise or misconfiguration worth investigating, not just clearing.
- Recognize that SELinux's label-based model and AppArmor's path-based model solve the same underlying problem differently — don't expect concepts (like contexts) to transfer directly between them when working across distributions.