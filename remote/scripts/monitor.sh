#!/bin/bash

# grabs some basic info about the server
SERVER_NAME=$(hostname) # the name of the host, probably 10.10.10.xxx with the EC2 labs
CHECK_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") # the time of the check in UTC

# print the info so I can make sure it's working
echo "Server: $SERVER_NAME" # print the hostname to the terminal
echo "Checked: $CHECK_TIME" # print the current time to the terminal


# ===========================================
# need to calculate CPU usage % across all cores
# get the first CPU reading
read -r label user nice system idle iowait irq softirq steal extra < /proc/stat
TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))
# wait a second before checking it again
sleep 1
# get the second CPU reading
read -r label user nice system idle iowait irq softirq steal extra < /proc/stat
TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))
# figure out how much CPU time passed between the checks
TOTAL_DIFF=$((TOTAL2 - TOTAL1))
IDLE_DIFF=$((IDLE2 - IDLE1))
# calculate what percentage of the time the CPU was busy
if (( TOTAL_DIFF > 0 )); then
    CPU_USAGE=$((100 * (TOTAL_DIFF - IDLE_DIFF) / TOTAL_DIFF))
else
    CPU_USAGE=0 # No CPU time elapsed or if there is an error, keeps from breaking
fi
# print the resulting % to the terminal
echo "CPU Usage: ${CPU_USAGE}%"


# ===========================================
# grab the total RAM and how much is still available
MEM_TOTAL=$(free -b | awk '$1 == "Mem:" {print $2}')
MEM_AVAILABLE=$(free -b | awk '$1 == "Mem:" {print $7}')
# figure out what percentage of RAM is being used
if (( MEM_TOTAL > 0 )); then
    MEM_USAGE=$((100 * (MEM_TOTAL - MEM_AVAILABLE) / MEM_TOTAL))
else
    MEM_USAGE=0
fi
# print the memory usage to the terminal window
echo "Memory Usage: ${MEM_USAGE}%"