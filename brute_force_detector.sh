#!/bin/bash

OUTPUT_FILE="/var/log/failed_attempts_ssh/alert.log"
FRAME=60
LIMIT_ATTEMPTS=5
BLOCK_ATTEMPTS=15
RL_RATE="1/minute"
RL_BURST="1"
declare -A ATTEMPTS

sudo tail -F -n 0 /var/log/auth.log | grep --line-buffered "Failed password for" | while read -r LINE; do

	IP=$(echo "$LINE" | grep -oP '(\d{1,3}\.){3}\d{1,3}')
	[ -z "$IP" ] && continue

	USER=$(echo "$LINE" | awk '{for(i=1;i<=NF;i++) if($i=="for") {print ($(i+1) == "invalid") ? $(i+3) : $(i+1)}}')
	
	NOW=$(date +%s)

	ATTEMPTS["$IP"]="${ATTEMPTS["$IP"]} $NOW"

	TIMESTAMP=""
	COUNT=0
	for T in ${ATTEMPTS["$IP"]}; do
		if [ $((NOW - T)) -lt $FRAME ]; then
			TIMESTAMP="$TIMESTAMP $T"
			COUNT=$((COUNT + 1))
		fi
	done
	
	ATTEMPTS["$IP"]="$TIMESTAMP"
			
	if [ "$COUNT" -eq "$LIMIT_ATTEMPTS" ]; then
		if ! iptables -C INPUT -s "$IP" -p tcp --dport 22 -m limit --limit "$RL_RATE" --limit-burst "$RL_BURST" -j ACCEPT 2>/dev/null && ! iptables -C INPUT -s "$IP" -j DROP 2>/dev/null; then
			iptables -A INPUT -s "$IP" -p tcp --dport 22 -m limit --limit "$RL_RATE" --limit-burst "$RL_BURST" -j ACCEPT
			
			MESSAGE="
			[SSH ALERT]
			$(date)
			AUTHENTICATION ATTEMPTS RATE LIMIT EXECUTED
			Reason: Too many failed authentication attempts
			Username: ${USER}
			IP: ${IP}"		
			
			echo "$MESSAGE" | sed 's/^[ \t]*//' | wall -n
			echo "$MESSAGE" >> "$OUTPUT_FILE"
		fi	
	elif [ "$COUNT" -ge "$BLOCK_ATTEMPTS" ]; then
		if ! iptables -C INPUT -s "$IP" -j DROP 2>/dev/null; then
			iptables -D INPUT -s "$IP" -p tcp --dport 22 -m limit --limit "$RL_RATE" --limit-burst "$RL_BURST" -j ACCEPT 2>/dev/null
			iptables -A INPUT -s "$IP" -j DROP

			MESSAGE="
			[SSH ALERT]
			$(date)
			HOST BLOCKED
			Reason: Too many failed authentication attempts
			Username: ${USER}
			IP: ${IP}"

			echo "$MESSAGE" | sed 's/^[ \t]*//' | wall -n
			echo "$MESSAGE" >> "$OUTPUT_FILE"
		fi
		unset 'ATTEMPTS[$IP]'
	fi
done
