# LVM Storage Lab

Objective: Create and manage a logical volume on a Linux host.

Tasks:
1. Create a physical volume with `pvcreate`.
2. Build a volume group with `vgcreate`.
3. Create a logical volume with `lvcreate`.
4. Format and mount the new logical volume.

Validation:
- `lvdisplay`, `vgdisplay`, and `lsblk` show the new volume
- The mount point is writable
