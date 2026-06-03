#!/usr/bin/env bash
# LVM Storage Lab support script

set -euo pipefail

cat <<'EOF' > README.md
Use this workspace to practice pvcreate, vgcreate, lvcreate, mkfs, and mount commands.
Create a small logical volume and mount it in /mnt/lab-lv.
EOF

echo "LVM lab prep complete."
