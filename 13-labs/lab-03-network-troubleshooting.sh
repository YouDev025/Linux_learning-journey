#!/usr/bin/env bash
# Network Troubleshooting Lab support script

set -euo pipefail

cat <<'EOF' > lab-03-network-config.txt
Interface: eth0
IP: 192.168.10.50/24
Gateway: 192.168.10.1
DNS: 8.8.8.8
EOF

echo "Network lab scenario created in lab-03-network-config.txt"

cat <<'EOF' > README.md
Use ip addr, ip route, ping, and dig to validate the configured network.
If the interface is down, bring it up with ip link set eth0 up.
EOF
