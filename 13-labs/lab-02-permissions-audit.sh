#!/usr/bin/env bash
# Permissions Audit Lab setup and verify script

set -euo pipefail

mkdir -p lab-02-permissions
cd lab-02-permissions

echo "Setting up permission audit exercise..."
mkdir -p app/logs app/public

useradd --no-create-home --shell /usr/sbin/nologin appuser 2>/dev/null || true
chown -R appuser:appuser app
chmod 750 app
chmod 700 app/logs
chmod 755 app/public

cat <<'EOF' > README.md
Inspect directory permissions with ls -l.
Ensure appuser owns the application directory and subdirectories.
EOF

echo "Permissions audit environment created."
