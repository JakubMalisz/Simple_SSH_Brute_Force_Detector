# SSH Brute Force Detector

A lightweight, two-stage SSH brute-force defense system written in pure Bash, operating as a `systemd` background service.

## TL;DR

- **Real-Time Monitoring:** Continuously tracks `/var/log/auth.log` for failed SSH authentication attempts.
- **Two-Stage Defense Mechanism (`iptables`):**
   - **Stage 1 (Rate Limit):** Restricts SSH connection bandwidth for IPs exceeding `LIMIT_ATTEMPTS`.
   - **Stage 2 (Hard Block):** Completely drops (`DROP`) traffic for IPs exceeding `BLOCK_ATTEMPTS`.
- **System-Wide Alerts:** Sends live terminal broadcast alerts via `wall` and logs event details to a dedicated log file.
- **Zero Third-Party Dependencies:** Relies strictly on native POSIX/Linux tools (`bash`, `iptables`, `awk`, `grep`, `sed`, `tail`).

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

## 1. OVERVIEW & ARCHITECTURAL GOALS



The SSH Brute Force Detector is an automated intrusion prevention tool designed for Linux servers. It mitigates brute-force attacks targeting the SSH daemon by analyzing authentication logs in real time and dynamically injecting packet-filtering rules into iptables.



Unlike static IP blocking solutions, this script enforces a graduated escalation strategy:

- Throttling (Rate Limiting): Temporarily limits login attempt rates when suspicious activity is detected, preventing brute-force efficiency while reducing false-positive impact on legitimate users.

- Hard Blocking (DROP): Permanently (or until rule flush) drops all packets from an IP address if aggressive attack behavior continues.







## 2. PREREQUISITES & SYSTEM REQUIREMENTS



- Operating System: Linux with systemd init manager.

- Privileges: root access (required for iptables rule manipulation and reading system logs).

- Core Dependencies:

  - bash (v4.0+ for associative arrays support)

  - iptables

  - tail, grep, awk, sed

  - wall (for system user notifications)






## 3. PROGRAM LOGIC & EXECUTION FLOW

### 3.1 Log Ingestion & Stream Parsing

The script continuously pipes log output via "tail -F -n 0 /var/log/auth.log". It filters for the string "Failed password for".

- IP Extraction: Extracted via Perl-compatible regular expressions.

- Username Extraction: Extracted using awk, distinguishing between valid system users and invalid/non-existent usernames.



### 3.2 Sliding Window Counter

- The script uses a Bash associative array mapping each IP address to a space-separated string of UNIX timestamps.

- Every time a failure occurs, the script iterates over the timestamps for that IP, discarding any entries where the time difference exceeds the FRAME.

- The total count of active timestamps within the time frame determines the current threat level (COUNT).



### 3.3 Rule Escalation & Firewall Management

- State 1: Rate Limiting

  Trigger: COUNT == LIMIT_ATTEMPTS

  Action: Adds an iptables rule matching port 22 TCP traffic with limit parameters.

  Condition: Executed only if neither a DROP rule nor a Rate Limit rule currently exists for the IP.



- State 2: Hard DROP

  Trigger: COUNT >= BLOCK_ATTEMPTS

  Action: 

    1. Removes any existing Rate Limit rule for the IP.

    2. Appends a hard drop rule.

    3. Clears the IP tracking array.







## 4. CONFIGURATION REFERENCE



All configurable parameters are defined at the top of brute_force_detector.sh:



- OUTPUT_FILE : Destination file for security incident alerts. (Default: /var/log/failed_attempts_ssh/alert.log)

- FRAME : Time window (in seconds) within which failed attempts are evaluated. (Default: 60)

- LIMIT_ATTEMPTS : Threshold of failed attempts to trigger Rate Limiting. (Default: 5)

- BLOCK_ATTEMPTS : Threshold of failed attempts to trigger complete IP blocking (DROP). (Default: 15)

- RL_RATE : iptables limit parameter governing accepted connection frequency. (Default: 1/minute)

- RL_BURST : iptables limit-burst parameter for initial packet burst size. (Default: 1)






## 5. SYSTEMD SERVICE DEPLOYMENT



Service Configuration File (ssh-log-monitor.service):


```bash
[Unit]

Description=SSH Brute Force Detector Service

After=network.target



[Service]

Type=simple

ExecStart=/bin/bash /usr/local/bin/brute_force_detector.sh

Restart=always

RestartSec=5

User=root



[Install]

WantedBy=multi-user.target
```


## 6. MAINTENANCE & OPERATIONAL COMMANDS



### Verifying Service Logs:

`journalctl -u ssh-log-monitor.service -f`



### Checking Active Firewall Rules:

`sudo iptables -L INPUT -v -n --line-numbers`



### Unblocking an IP Address:

- Find rule line number

`sudo iptables -L INPUT -n --line-numbers | grep <TARGET_IP>`



- Delete rule by line number

`sudo iptables -D INPUT <LINE_NUMBER>`
