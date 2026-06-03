#!/usr/bin/env bash
# CLI Fundamentals Lab support script

set -euo pipefail

mkdir -p lab-01-cli
cd lab-01-cli

echo "Creating sample files..."
touch README.txt notes.txt data.csv
mkdir -p archive
cp README.txt archive/README-backup.txt
mv notes.txt notes-reviewed.txt

cat <<'EOF' > instruction.txt
Review the files in this directory using ls -al.
Use find . -name "*.txt" to locate text files.
EOF

echo "Lab 01 setup complete."
