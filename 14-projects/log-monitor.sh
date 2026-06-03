#!/usr/bin/env bash
# Log Monitor Script
set -euo pipefail

LOG_FILE="/var/log/auth.log"
if [[ ! -f "$LOG_FILE" ]]; then
  LOG_FILE="/var/log/secure"
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No auth log file found."
  exit 1
fi

echo "Failed login summary:" 
grep -i "failed password" "$LOG_FILE" | tail -20

echo "\nSudo failure summary:"
grep -i "sudo: .*authentication failure" "$LOG_FILE" | tail -20
