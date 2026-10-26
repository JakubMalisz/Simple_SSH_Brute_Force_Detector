TECHNICAL DOCUMENTATION: SSH BRUTE FORCE DETECTOR



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


Installation Steps:

1. Place `brute_force_detector.sh` into `/usr/local/bin/`. Since this script manages firewall rules and processes security logs, restrict its permissions to root only (`700`):
```
sudo chown root:root /usr/local/bin/brute_force_detector.sh

sudo chmod 700 /usr/local/bin/brute_force_detector.sh
```


2. Place ssh-log-monitor.service into `/etc/systemd/system/`.



3. Reload systemd configuration:
```
sudo systemctl daemon-reload
```


4. Start and enable the service:
```
   sudo systemctl enable --now ssh-log-monitor.service
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
