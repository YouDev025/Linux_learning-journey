# LVM and Snapshots

A reference guide to Logical Volume Manager (LVM) — the abstraction layer that decouples Linux storage from fixed physical partition boundaries, enabling flexible resizing and point-in-time snapshots.

---

## 🧱 The LVM Layering Model

LVM introduces three layers between raw storage and the filesystems you actually use, each more flexible than the one below it:

```
Physical Volume(s) (PV)       ← raw disks or partitions, "registered" with LVM
        │
        ▼
Volume Group (VG)              ← a pool combining one or more PVs into shared storage
        │
        ▼
Logical Volume(s) (LV)         ← flexible "virtual partitions" carved out of the VG
        │
        ▼
Filesystem (ext4, XFS, etc.)   ← formatted onto each LV, same as a normal partition
```

### Why This Indirection Is Useful

With traditional partitions, a partition's size is fixed at creation and bounded by its physical location on disk — resizing is awkward, and you can't easily combine multiple physical disks into one logical storage pool. LVM solves both problems: a **volume group** can span multiple physical disks, and a **logical volume** can be resized (grown or, with caveats, shrunk) without needing to move other partitions around or care about its physical placement on disk.

---

## 💾 Physical Volumes: `pvcreate`

A **Physical Volume (PV)** is a disk or partition that's been initialized for LVM use — essentially, "registering" that block device as raw material LVM can allocate from.

```bash
sudo pvcreate /dev/sdb              # use a whole disk as a PV
sudo pvcreate /dev/sdc1               # or a specific partition
sudo pvcreate /dev/sdb /dev/sdc1       # initialize multiple devices at once
```

### Inspecting Physical Volumes

```bash
sudo pvs                  # brief summary of all PVs
sudo pvdisplay             # detailed info on all PVs
sudo pvdisplay /dev/sdb      # detailed info on one specific PV
```

```
PV         VG       Fmt  Attr PSize    PFree
/dev/sdb   data_vg  lvm2 a--  500.00g  100.00g
```

> ⚠️ **Caution:** `pvcreate` writes LVM metadata to the start of the device, which can destroy any existing partition table or filesystem signature on it. Confirm the target device with `lsblk -f`/`blkid` (see the *Block Devices* guide) before running it on anything that might contain data you need.

---

## 🗂️ Volume Groups: `vgcreate`

A **Volume Group (VG)** pools one or more Physical Volumes into a single allocatable storage space, from which Logical Volumes are later carved.

```bash
sudo vgcreate data_vg /dev/sdb /dev/sdc1     # create a VG from two PVs
```

### Inspecting Volume Groups

```bash
sudo vgs                 # brief summary
sudo vgdisplay             # detailed info on all VGs
sudo vgdisplay data_vg      # detailed info on one specific VG
```

```
VG       #PV  #LV  #SN  Attr   VSize    VFree
data_vg    2    3    1  wz--n  900.00g  150.00g
```

### Extending a Volume Group

One of LVM's central advantages: adding more raw storage to an existing pool without disrupting anything already using it.

```bash
sudo pvcreate /dev/sdd            # initialize a new disk as a PV first
sudo vgextend data_vg /dev/sdd      # add it to the existing volume group
```

### Removing a Physical Volume from a Group

```bash
sudo pvmove /dev/sdc1                  # migrate any data off this PV onto other PVs in the VG first
sudo vgreduce data_vg /dev/sdc1          # then remove it from the VG
sudo pvremove /dev/sdc1                   # finally, un-initialize it as an LVM PV entirely
```

---

## 📦 Logical Volumes: `lvcreate`

A **Logical Volume (LV)** is the actual "virtual partition" you format and mount — carved out of a Volume Group's pooled space.

```bash
sudo lvcreate -n web_lv -L 50G data_vg          # create a 50GB LV named "web_lv" in "data_vg"
sudo lvcreate -n logs_lv -l 100%FREE data_vg      # use ALL remaining free space in the VG
sudo lvcreate -n cache_lv -L 10G -i 2 data_vg       # striped across 2 PVs, for performance
```

| Flag | Meaning |
|---|---|
| `-n` | Name for the new LV |
| `-L` | Size, in absolute units (e.g. `50G`) |
| `-l` | Size, as a percentage of available space (e.g. `100%FREE`) |
| `-i` | Number of stripes (spread data across multiple PVs) |

### The Resulting Device Path

```bash
ls /dev/data_vg/web_lv
# or, the older-style equivalent path:
ls /dev/mapper/data_vg-web_lv
```

### Formatting and Mounting an LV (Same as Any Partition)

```bash
sudo mkfs.ext4 /dev/data_vg/web_lv
sudo mkdir -p /mnt/web
sudo mount /dev/data_vg/web_lv /mnt/web
```

> **Note:** Once formatted and mounted, an LV behaves exactly like a regular partition for everyday use — the flexibility LVM provides is specifically around *creating, resizing, and snapshotting*, not in how the resulting filesystem is used day to day.

### Inspecting Logical Volumes

```bash
sudo lvs                  # brief summary of all LVs
sudo lvdisplay              # detailed info on all LVs
sudo lvdisplay /dev/data_vg/web_lv   # detailed info on one specific LV
```

---

## 📏 Resizing Logical Volumes

### Growing a Logical Volume

```bash
sudo lvextend -L +20G /dev/data_vg/web_lv        # grow by 20GB
sudo lvextend -l +100%FREE /dev/data_vg/web_lv     # grow to use all remaining free space in the VG
```

Growing the LV alone doesn't grow the **filesystem** sitting on top of it — that's a separate step:

```bash
sudo resize2fs /dev/data_vg/web_lv      # for ext4
sudo xfs_growfs /mnt/web                  # for XFS (note: operates on the MOUNT POINT, not the device)
```

A common shortcut combines both steps:

```bash
sudo lvextend -r -L +20G /dev/data_vg/web_lv    # -r automatically resizes the filesystem too, if supported
```

### Shrinking a Logical Volume

Shrinking is riskier and requires more care — the filesystem must be shrunk **before** the LV, never after, to avoid truncating data that's still in use.

```bash
sudo umount /mnt/web                              # 1. unmount first
sudo e2fsck -f /dev/data_vg/web_lv                  # 2. check filesystem integrity
sudo resize2fs /dev/data_vg/web_lv 30G                # 3. shrink the FILESYSTEM first
sudo lvreduce -L 30G /dev/data_vg/web_lv               # 4. THEN shrink the logical volume to match
```

> ⚠️ **Caution:** Shrinking in the wrong order — reducing the LV before the filesystem — can truncate live data instantly and irrecoverably. Always shrink filesystem-first, LV-second, and never skip the integrity check. Also note: **XFS does not support shrinking at all** — an XFS-backed LV can only grow, never shrink (consistent with the limitation noted in the *Partitioning and Filesystems* guide).

---

## 📸 Snapshots

An LVM **snapshot** captures the exact state of a Logical Volume at a specific moment, without copying all its data immediately — making it fast to create even for very large volumes.

### How Snapshots Work: Copy-on-Write

A snapshot starts out referencing the *same* underlying data blocks as its origin volume. As the origin volume is modified afterward, LVM copies each block being changed to the snapshot's reserved space **before** overwriting it — preserving the original data at the moment the snapshot was taken. This is conceptually the same copy-on-write idea used by `fork()` (see the *Process Lifecycle* guide), applied to disk blocks instead of memory pages.

```
Snapshot taken at T0:
   origin LV  ──────┐
                      ├── share the same blocks initially
   snapshot LV ──────┘

After T0, origin LV is modified:
   origin LV:    [new data]
   snapshot LV:  [old data, copied aside before being overwritten]
```

### Creating a Snapshot

```bash
sudo lvcreate -s -n web_lv_snapshot -L 5G /dev/data_vg/web_lv
```

| Flag | Meaning |
|---|---|
| `-s` | Create a snapshot (rather than a regular LV) |
| `-n` | Name for the snapshot |
| `-L` | Reserved space for tracking *changes* — not the full size of the origin volume |

> **Sizing a snapshot:** the `-L` size only needs to cover how much data will *change* on the origin volume while the snapshot exists — not the origin's full size. If changes exceed the reserved space, the snapshot becomes invalid and unusable. Size generously for how long you intend to keep the snapshot and how write-heavy the origin volume is during that window.

### Mounting and Inspecting a Snapshot

```bash
sudo mkdir -p /mnt/web-snapshot
sudo mount /dev/data_vg/web_lv_snapshot /mnt/web-snapshot   # mount read-only is also common: -o ro
```

This lets you browse the volume's state *at the moment the snapshot was taken*, even while the live origin volume continues changing.

### Restoring (Reverting) from a Snapshot

```bash
sudo umount /mnt/web                          # unmount the ORIGIN volume first
sudo lvconvert --merge /dev/data_vg/web_lv_snapshot
# the merge completes on next activation — often requires a reboot, or reactivating the VG
```

> **Note:** `lvconvert --merge` reverts the origin volume back to the snapshot's state and **removes the snapshot** in the process — it's a one-way restore operation, not a way to keep both versions side by side.

### Removing a Snapshot (Without Restoring)

```bash
sudo lvremove /dev/data_vg/web_lv_snapshot
```

> **Tip:** Snapshots are commonly used as a safety net immediately before a risky operation (a system upgrade, a database migration, a major config change) — take the snapshot, perform the operation, and either remove the snapshot once you've confirmed success, or merge/restore it if something went wrong.

---

## 🧪 Use Cases: Labs vs. Production

### Lab / Testing Environments

- **Rapid experimentation:** snapshot before trying something risky, revert instantly if it breaks.
- **Flexible disk simulation:** resize volumes on the fly to test how an application behaves under different storage constraints, without re-partitioning physical disks.
- **Disposable test states:** snapshot a "known good" baseline, run a test, discard the snapshot (or revert to it) regardless of outcome.

### Production Environments

- **Pre-upgrade safety net:** snapshot before a major OS/application upgrade; if the upgrade fails, revert quickly instead of restoring from a slower full backup.
- **Backup consistency:** snapshot a volume, then back up *from the snapshot* (which is frozen in time) while the live volume continues serving traffic unaffected — avoids backing up a filesystem that's actively changing mid-backup.
- **Storage growth without downtime:** extend a volume group with new physical disks and grow logical volumes/filesystems live, without needing to take services offline to repartition.
- **Database-specific snapshotting:** many production database setups pair LVM snapshots with brief application-level flush/freeze commands to guarantee a consistent, crash-recoverable snapshot point.

> ⚠️ **Caution for production use:** LVM snapshots are **not a substitute for real backups**. A snapshot lives on the *same* physical storage as its origin — if the underlying disk fails entirely, the snapshot is lost along with everything else. Snapshots protect against logical mistakes (bad upgrades, accidental deletions) on a short time horizon; they don't protect against hardware failure, theft, or site-level disasters the way an independent, off-system backup does.

---

## ⚡ Quick Reference

| Task | Command |
|---|---|
| Initialize a disk as a PV | `sudo pvcreate /dev/sdb` |
| List PVs | `sudo pvs` |
| Create a VG from PVs | `sudo vgcreate vg_name /dev/sdb /dev/sdc1` |
| Extend a VG with a new PV | `sudo vgextend vg_name /dev/sdd` |
| List VGs | `sudo vgs` |
| Create an LV | `sudo lvcreate -n lv_name -L 50G vg_name` |
| List LVs | `sudo lvs` |
| Grow an LV + filesystem together | `sudo lvextend -r -L +20G /dev/vg_name/lv_name` |
| Shrink filesystem (ext4 only, before LV) | `sudo resize2fs /dev/vg_name/lv_name SIZE` |
| Shrink an LV (after filesystem) | `sudo lvreduce -L SIZE /dev/vg_name/lv_name` |
| Create a snapshot | `sudo lvcreate -s -n snap_name -L 5G /dev/vg_name/lv_name` |
| Merge/restore a snapshot | `sudo lvconvert --merge /dev/vg_name/snap_name` |
| Remove a snapshot | `sudo lvremove /dev/vg_name/snap_name` |

---

## 💡 Best Practices

- Confirm target devices with `lsblk -f`/`blkid` before `pvcreate` — it can destroy existing data on a device with leftover content.
- When growing, use `lvextend -r` to resize the filesystem in the same step rather than forgetting the separate `resize2fs`/`xfs_growfs` call.
- When shrinking, always shrink the filesystem **before** the logical volume, and never attempt to shrink XFS at all — it isn't supported.
- Size snapshot reserved space (`-L`) generously relative to expected write volume and how long you'll keep the snapshot — an undersized snapshot can become invalid if it fills up.
- Use snapshots as a pre-change safety net (upgrades, migrations) and for consistent backup sourcing — not as a replacement for genuine, independent backups.
- Remember `lvconvert --merge` is a one-way restore that consumes the snapshot — keep a separate snapshot (or backup) if you might want to compare against the pre-change state later rather than just reverting to it.
- Periodically review `vgs`/`lvs` free space — a volume group that's run out of free space can't accept new LVs or extend existing ones until more physical storage is added.