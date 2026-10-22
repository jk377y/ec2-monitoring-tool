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


# ===========================================
# check how much space is being used on the main disk
DISK_USAGE=$(df -P / | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')
# print the disk usage to the terminal
echo "Disk Usage: ${DISK_USAGE}%"


# ===========================================
# check network usage; going to use RX (received) and TX (transmitted) values
# figure out which network interface the server is using
NET_IFACE=$(ip -4 route show default | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')
# make sure we actually found an interface - just an error handling condition
if [[ -z "$NET_IFACE" ]]; then
    echo "Could not find the network interface."
    exit 1
fi
# find the files that track received and sent bytes
RX_FILE="/sys/class/net/$NET_IFACE/statistics/rx_bytes"
TX_FILE="/sys/class/net/$NET_IFACE/statistics/tx_bytes"
# make sure the files can be read
if [[ ! -r "$RX_FILE" || ! -r "$TX_FILE" ]]; then
    echo "Could not read network statistics."
    exit 1
fi
# take our first network readings
read -r RX1 < "$RX_FILE"
read -r TX1 < "$TX_FILE"
# wait a second and check again
sleep 1
# check network usage; going to use RX (received) and TX (transmitted) values
read -r RX2 < "$RX_FILE"
read -r TX2 < "$TX_FILE"
# calculate how many bytes moved during that second
RX_DIFF=$((RX2 - RX1))
TX_DIFF=$((TX2 - TX1))
# make sure the counters didn't decrease or reset
if (( RX_DIFF < 0 || TX_DIFF < 0 )); then
    echo "Network counters changed unexpectedly."
    exit 1
fi
# convert bytes per second into KiB per second - just a conversion
RX_KIB_S=$((RX_DIFF / 1024))
TX_KIB_S=$((TX_DIFF / 1024))
# print the network interface information and KiB/s uploaded and downloaded
echo "Network Interface: $NET_IFACE"
echo "Network Download: ${RX_KIB_S} KiB/s"
echo "Network Upload: ${TX_KIB_S} KiB/s"