# Storage Encryption

A reference guide to encrypting data at rest on Linux — LUKS and `cryptsetup` fundamentals, encrypted boot/root setups, and key/passphrase management.

---

## 🔐 Why Encrypt Storage At Rest

Encryption at rest protects data when the *running system's* access controls are no longer relevant — most notably when a physical disk is lost, stolen, or improperly disposed of. Filesystem permissions and `chmod`/`chown` (see the *Ownership* guide) only matter while the OS is mediating access; if someone removes a disk and reads it directly with different tools, those protections do nothing. Encryption ensures the *raw bytes on disk* are unreadable without the correct key, regardless of how they're accessed.

> **Important scope:** disk encryption protects data **at rest** — it does not protect a *running, unlocked* system from someone with access to it, and it doesn't substitute for normal account security, network security, or backups. Think of it specifically as "what happens if this disk ends up in the wrong hands while powered off."

---

## 🧱 LUKS — Linux Unified Key Setup

**LUKS** is the standard Linux disk-encryption specification — not a tool itself, but a defined on-disk format that `cryptsetup` (and other tools) implement. Standardizing the format means an encrypted volume created on one Linux system can be opened on any other LUKS-compatible system, given the right key.

### What LUKS Actually Encrypts

LUKS encrypts an entire **block device** (a partition, a whole disk, or an LVM logical volume) at the block level — everything written to it is encrypted, and everything read from it is decrypted, transparently, once it's been "unlocked." The filesystem (ext4, XFS, etc.) is then created *on top of* the decrypted, unlocked device, with no awareness that encryption is even happening underneath.

```
Partition (/dev/sdb1)
     │
     ▼
LUKS encryption layer  ← cryptsetup operates here
     │
     ▼
Decrypted mapped device (/dev/mapper/secure_data)  ← appears once "unlocked"
     │
     ▼
Filesystem (ext4, XFS, ...)  ← created/mounted on the decrypted device, same as any normal partition
```

### LUKS Key Slots

LUKS doesn't encrypt data directly with your passphrase. Instead, it generates one strong, random **master key**, encrypts the *actual data* with that, and then stores the master key itself — encrypted separately by each passphrase/keyfile you configure — in one of up to **8 key slots** (LUKS1) or more (LUKS2, depending on configuration).

This indirection is why you can have **multiple independent passphrases** unlock the same volume, and why you can **change a passphrase** without re-encrypting the entire dataset — you're only re-wrapping the master key in that slot, not touching the bulk data at all.

---

## 🛠️ `cryptsetup` — Creating and Using LUKS Volumes

### Creating a New Encrypted Volume

```bash
sudo cryptsetup luksFormat /dev/sdb1
```

```
WARNING!
========
This will overwrite data on /dev/sdb1 irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for /dev/sdb1:
Verify passphrase:
```

> ⚠️ **Caution:** `luksFormat` is destructive — it overwrites the target device's header and effectively destroys any prior data/filesystem on it. Confirm the target device with `lsblk -f`/`blkid` (see the *Block Devices* guide) before running it.

### Opening (Unlocking) an Encrypted Volume

```bash
sudo cryptsetup luksOpen /dev/sdb1 secure_data
# prompts for the passphrase, then exposes the decrypted device at:
# /dev/mapper/secure_data
```

### Formatting and Mounting the Decrypted Device

Once unlocked, the mapped device behaves exactly like any other block device for formatting/mounting purposes (see the *Partitioning and Filesystems* guide):

```bash
sudo mkfs.ext4 /dev/mapper/secure_data
sudo mkdir -p /mnt/secure
sudo mount /dev/mapper/secure_data /mnt/secure
```

### Closing (Locking) the Volume

```bash
sudo umount /mnt/secure
sudo cryptsetup luksClose secure_data
```

Once closed, `/dev/mapper/secure_data` disappears, and the underlying partition is once again unreadable without re-opening it with a valid key.

### Inspecting LUKS Header Info

```bash
sudo cryptsetup luksDump /dev/sdb1          # show header info, key slots, cipher details
sudo cryptsetup isLuks /dev/sdb1 && echo "Yes, this is a LUKS volume"
sudo cryptsetup status secure_data            # show status of an OPEN mapping
```

---

## 🔑 Key Management

### Adding an Additional Passphrase

```bash
sudo cryptsetup luksAddKey /dev/sdb1
# prompts for an EXISTING valid passphrase first, then the NEW one to add
```

This is how you support multiple people unlocking the same volume with their own separate passphrase, or maintain a personal passphrase alongside a recovery one.

### Removing a Passphrase

```bash
sudo cryptsetup luksRemoveKey /dev/sdb1
# prompts for the passphrase to REMOVE
```

> ⚠️ **Caution:** Removing the *last remaining* key slot makes the volume permanently unrecoverable — always confirm at least one other valid passphrase or keyfile exists before removing one, and never remove the only key without a tested backup key in place first.

### Using a Keyfile Instead of (or Alongside) a Passphrase

A **keyfile** is a regular file whose contents serve as the unlock credential — useful for automated/unattended unlocking (e.g. a boot script reading a keyfile from a separate, trusted device) where typing a passphrase interactively isn't practical.

```bash
sudo dd if=/dev/urandom of=/root/secure_data.key bs=512 count=4    # generate a random keyfile
sudo chmod 600 /root/secure_data.key                                   # restrict access tightly
sudo cryptsetup luksAddKey /dev/sdb1 /root/secure_data.key               # add it as a new key slot
```

```bash
sudo cryptsetup luksOpen /dev/sdb1 secure_data --key-file /root/secure_data.key   # unlock without a prompt
```

> ⚠️ **Caution:** A keyfile is only as secure as the protections around the file itself — anyone who can read it can unlock the volume, with no passphrase needed at all. Restrict its permissions tightly (`600`, owned by root), and consider whether storing it on the *same* machine defeats the purpose if that machine is the asset you're protecting against theft.

### Viewing and Managing Key Slots

```bash
sudo cryptsetup luksDump /dev/sdb1 | grep -A2 "Key Slot"
```

```
Key Slot 0: ENABLED
Key Slot 1: ENABLED
Key Slot 2: DISABLED
...
```

### Backing Up the LUKS Header

The LUKS header contains the encrypted master key copies — if it's corrupted or lost, **the entire volume becomes unrecoverable**, even with a correct passphrase, since there's nothing left describing how to derive the actual encryption key.

```bash
sudo cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file /root/sdb1-header-backup.img
```

```bash
sudo cryptsetup luksHeaderRestore /dev/sdb1 --header-backup-file /root/sdb1-header-backup.img
```

> **Tip:** Store this header backup somewhere genuinely separate from the encrypted volume itself — if both live on the same disk, a single hardware failure takes out your only recovery path along with the data it was meant to protect.

---

## 🚀 Encrypted Boot and Root Partitions

### Why the Boot Partition Is Usually NOT Encrypted

The bootloader needs to read kernel and initramfs files *before* any decryption can happen — there's a practical chicken-and-egg problem in encrypting the very files needed to start the decryption process. Most setups leave `/boot` **unencrypted**, while encrypting `/` (root) and everything else.

```
/boot         ← unencrypted; bootloader and kernel must be readable before decryption starts
/  (root)     ← LUKS-encrypted; unlocked during early boot via a passphrase prompt
/home, /var   ← can be separate LUKS volumes, or part of the encrypted root
swap          ← should ALSO be encrypted; otherwise sensitive memory contents can leak to disk unencrypted
```

> **Why swap matters:** if swap isn't encrypted, sensitive data that gets paged out of RAM (which can include passphrases, keys, or other secrets briefly held in memory) ends up written to disk in the clear — defeating much of the purpose of encrypting everything else. Always encrypt swap alongside root.

### The Unlock-at-Boot Flow

```
1. Bootloader (GRUB) reads kernel/initramfs from unencrypted /boot
2. Kernel boots into the initramfs (a minimal early environment)
3. initramfs prompts for the LUKS passphrase
4. Once unlocked, the real root filesystem is mounted, and boot continues normally
```

### Configuring This: `/etc/crypttab`

`/etc/crypttab` is to encrypted volumes roughly what `/etc/fstab` is to regular filesystems — it defines which encrypted devices should be unlocked at boot.

```
# /etc/crypttab
# name           device                            keyfile      options
secure_root      UUID=1234abcd-5678-90ef-ghij       none         luks
secure_swap      UUID=90ab-cdef-1234-5678            /dev/urandom  swap,cipher=aes-xts-plain64
```

| Field | Meaning |
|---|---|
| 1 | Name to give the mapped device (appears as `/dev/mapper/name`) |
| 2 | The underlying encrypted device, ideally by `UUID=` |
| 3 | Keyfile path, or `none` to prompt interactively at boot |
| 4 | Options — e.g. `luks` for a standard volume, or `swap` for an encrypted swap that's re-randomized fresh on every boot |

> **Note on encrypted swap specifically:** using `/dev/urandom` as the "keyfile" with the `swap` option means a brand-new random key is generated every single boot — swap contents are never expected to persist across reboots anyway, so there's no need for a stable, memorable key; this approach avoids needing to enter a second passphrase just for swap.

### Setting This Up Typically Happens at Install Time

Most distributions' installers offer "encrypt my disk" as a guided option during initial OS installation, which correctly handles the `/boot`-unencrypted/`root`-encrypted split, crypttab generation, and initramfs configuration automatically. Manually converting an already-installed, unencrypted system to full-disk encryption after the fact is possible but significantly more involved — generally easier to reinstall with encryption enabled from the start if that's the goal.

---

## 🔒 Passphrase Policies

### What Makes a Strong LUKS Passphrase

Unlike a typical login password (rate-limited, often hashed with deliberately slow algorithms — see the *Authentication and Passwords* guide), a LUKS passphrase protecting an **offline** disk faces a different threat model: an attacker with the disk in hand can attempt unlimited offline guesses, limited only by computational cost — there's no live system to lock them out after failed attempts.

| Factor | Why it matters more for disk encryption |
|---|---|
| Length | Offline brute-force can be extremely fast per-guess; length matters even more than for online-rate-limited logins |
| Avoiding dictionary words/patterns | Offline attacks commonly use large precomputed wordlists/rules |
| Uniqueness | A passphrase reused elsewhere ties this disk's security to every other place that phrase has ever been used |

### Practical Recommendations

- Favor a long passphrase (a multi-word passphrase, not just a single complex "password," is often both stronger and easier to remember).
- Treat it as distinct from any other password you use — disk encryption passphrases shouldn't be reused.
- Store a backup of the passphrase (and the LUKS header backup) somewhere secure and genuinely separate from the machine itself — a password manager, a sealed physical record in a safe, or an organizational secrets-management system, depending on context.

### Key Derivation: Why LUKS Slows Down Passphrase Checking

LUKS deliberately uses a slow, memory-hard key derivation function (PBKDF2 historically, **Argon2** by default in LUKS2) to turn your passphrase into the key needed to unlock a key slot. This is conceptually the same idea as password hash salting/slowness (see the *Authentication and Passwords* guide) — it makes each individual guess computationally expensive, which matters enormously against an offline attacker who can otherwise try guesses as fast as their hardware allows.

```bash
sudo cryptsetup luksDump /dev/sdb1 | grep -A3 "PBKDF"
```

```
PBKDF:      argon2id
Iterations: 4
Memory:     1048576
```

> **Tip:** LUKS2's default Argon2-based settings are tuned to take roughly 1-2 seconds to unlock on typical hardware — slow enough to meaningfully throttle offline brute-force, fast enough not to be annoying for legitimate unlocking. There's rarely a good reason to weaken this for convenience.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Create a new LUKS volume | `sudo cryptsetup luksFormat /dev/sdb1` |
| Unlock (open) a volume | `sudo cryptsetup luksOpen /dev/sdb1 name` |
| Lock (close) a volume | `sudo cryptsetup luksClose name` |
| Check status of an open mapping | `sudo cryptsetup status name` |
| Show header/key slot info | `sudo cryptsetup luksDump /dev/sdb1` |
| Check if a device is LUKS | `sudo cryptsetup isLuks /dev/sdb1` |
| Add a passphrase/keyfile | `sudo cryptsetup luksAddKey /dev/sdb1` |
| Remove a passphrase/keyfile | `sudo cryptsetup luksRemoveKey /dev/sdb1` |
| Back up the LUKS header | `sudo cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file FILE` |
| Restore the LUKS header | `sudo cryptsetup luksHeaderRestore /dev/sdb1 --header-backup-file FILE` |
| Configure boot-time unlocking | edit `/etc/crypttab` |

---

## 💡 Best Practices

- Always confirm the target device before `luksFormat` — it's destructive and irreversible without a pre-existing backup.
- Always encrypt swap alongside the root filesystem — unencrypted swap can leak sensitive in-memory data to disk.
- Back up the LUKS header to separate, independent storage — losing it makes the encrypted volume permanently unrecoverable, even with a correct passphrase.
- Maintain at least one backup passphrase or keyfile in a secure, separate location before removing or changing your primary one — never reduce to zero recovery paths.
- Treat keyfiles with the same care as passwords: restrict permissions tightly, and think carefully about where they're stored relative to the disk they protect.
- Use a long, unique passphrase for disk encryption specifically — offline brute-force attacks have a very different cost profile than online, rate-limited login attempts.
- Prefer setting up encryption at install time rather than retrofitting it onto an already-installed unencrypted system — it's far less error-prone.
- Don't weaken LUKS2's default Argon2 KDF settings for convenience — the deliberate slowness is a core part of its protection against offline attacks.