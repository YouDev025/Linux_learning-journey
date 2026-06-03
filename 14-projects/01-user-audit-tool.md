# User Audit Tool

Build a script that audits system users and reports inactive or privileged accounts for security review.

Project goals:
- Enumerate users from `/etc/passwd`
- Identify accounts with no login shell or UID below 1000
- Summarize account age and password status
