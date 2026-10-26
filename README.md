# SSH Brute Force Detector

A lightweight, two-stage SSH brute-force defense system written in pure Bash, operating as a `systemd` background service.

## TL;DR

- **Real-Time Monitoring:** Continuously tracks `/var/log/auth.log` for failed SSH authentication attempts.
- **Two-Stage Defense Mechanism (`iptables`):**
   - **Stage 1 (Rate Limit):** Restricts SSH connection bandwidth for IPs exceeding `LIMIT_ATTEMPTS`.
   - **Stage 2 (Hard Block):** Completely drops (`DROP`) traffic for IPs exceeding `BLOCK_ATTEMPTS`.
- **System-Wide Alerts:** Sends live terminal broadcast alerts via `wall` and logs event details to a dedicated log file.
- **Zero Third-Party Dependencies:** Relies strictly on native POSIX/Linux tools (`bash`, `iptables`, `awk`, `grep`, `sed`, `tail`).

>  **Full Documentation:** For complete architectural details, configuration references, and advanced setup, see **[DOCUMENTATION.md](DOCUMENTATION.md)**.

##  Quick Setup

1. Copy the script to `/usr/local/bin/`, set ownership to root, and restrict permissions so only root can read and execute it:
   ```bash
   sudo cp brute_force_detector.sh /usr/local/bin/
   sudo chown root:root /usr/local/bin/brute_force_detector.sh
   sudo chmod 700 /usr/local/bin/brute_force_detector.sh
   
2. Copy the systemd service file and enable it:
   ```bash
   sudo cp ssh-log-monitor.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now ssh-log-monitor.service


3. Check service status:
   ```bash
   sudo systemctl status ssh-log-monitor.service
