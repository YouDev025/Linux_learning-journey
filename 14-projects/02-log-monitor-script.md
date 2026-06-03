# Log Monitor Script

Create a script that scans system logs for potential security events and sends warnings when suspicious patterns are detected.

Project goals:
- Parse `/var/log/auth.log` or `/var/log/secure`
- Detect repeated failed logins and sudo attempts
- Output a summary report for follow-up
