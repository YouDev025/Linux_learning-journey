#!/usr/bin/env bash
# User Audit Tool
set -euo pipefail

echo "System User Audit"
echo "==================="

awk -F: '($3<1000 && $1!="root") {print $1":"$3":"$7}' /etc/passwd

printf "\nAccounts with disabled shells:\n"
awk -F: '($7=="/usr/sbin/nologin" || $7=="/bin/false") {print $1":"$7}' /etc/passwd
