#!/bin/bash

# let's get colorful
# Colors for terminal messages.
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[38;5;45m'
RESET='\033[0m'
# Only color the labels, not the rest of the message.
ok() {
    printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$1"
}
error() {
    printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$1"
}
info() {
    printf '%b[INFO]%b %s\n' "$YELLOW" "$RESET" "$1"
}
file() {
    printf '%b%s%b\n' "$LIGHT_BLUE" "$1" "$RESET"
}

# find the project folder, even if I run this from somewhere else
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR" || exit 1
echo "======================================"
echo "       EC2 MONITORING TOOL"
echo "======================================"
echo ""
# ask for the IP address and SSH username
read -r -p "EC2 public IP or DNS: " EC2_HOST
read -r -p "SSH username [ec2-user]: " SSH_USER
# use ec2-user if they leave the username blank
SSH_USER="${SSH_USER:-ec2-user}"
# make sure an address was provided
if [[ -z "$EC2_HOST" ]]; then
    error "An EC2 address is required."
    exit 1
fi
# look for PEM files in this project folder
shopt -s nullglob
PEM_FILES=("$PROJECT_DIR"/*.pem)
shopt -u nullglob
DEFAULT_KEY=""
# if there's only one PEM file, suggest using it
if (( ${#PEM_FILES[@]} == 1 )); then
    DEFAULT_KEY="${PEM_FILES[0]##*/}"
fi
# show the available keys if there are several
if (( ${#PEM_FILES[@]} > 1 )); then
    info "Found these PEM files:"
    for KEY in "${PEM_FILES[@]}"; do
        echo "  ${KEY##*/}"
    done
fi
read -r -p "PEM filename [$DEFAULT_KEY]: " KEY_NAME
KEY_NAME="${KEY_NAME:-$DEFAULT_KEY}"
# the PEM file should be inside our local project folder
KEY_PATH="$PROJECT_DIR/$KEY_NAME"
if [[ -z "$KEY_NAME" || ! -f "$KEY_PATH" ]]; then
    error "Could not find the PEM file."
    exit 1
fi
# limit access to the private key
chmod 400 "$KEY_PATH" || exit 1

# Share the same SSH settings between SSH and SCP.
SSH_OPTIONS=(-i "$KEY_PATH" -o IdentitiesOnly=yes -o ConnectTimeout=10)

# Older SSH clients (including some Macs) don't recognize WarnWeakCrypto.
# ssh -G checks the option without making a network connection.
if ssh -G -o WarnWeakCrypto=no-pq-kex "$EC2_HOST" >/dev/null 2>&1; then
    SSH_OPTIONS+=(-o WarnWeakCrypto=no-pq-kex)
fi
echo ""
info "Connecting to $SSH_USER@$EC2_HOST ..."
echo ""
# try SSH before attempting to deploy anything
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" \
    'printf "Connected as: "; id -un; if [ -r /etc/os-release ]; then . /etc/os-release; printf "Linux version: %s\n" "$PRETTY_NAME"; fi'
then
    echo ""
    ok "SSH connection successful."
else
    echo ""
    error "SSH connection failed."
    echo "Check the IP, username, PEM key, and port 22 access."
    exit 1
fi
# make sure all the project files are here before uploading anything
echo ""
info "Checking local project files..."
PROJECT_FILES=(
    "remote/scripts/monitor.sh"
    "remote/scripts/manage.sh"
    "remote/public/index.html"
    "remote/public/styles.css"
    "remote/public/app.js"
)
for FILE in "${PROJECT_FILES[@]}"; do
    if [[ ! -f "$PROJECT_DIR/$FILE" ]]; then
        error "Missing file: $FILE"
        exit 1
    fi
done
ok "All project files found."
# check the EC2 instance for the tools our scripts need
echo ""
info "Checking software on EC2..."
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" 'bash -s' <<'REMOTE_CHECK'; then
# Remote commands run in their own Bash process, so give them colors too.
REMOTE_GREEN='\033[0;32m'
REMOTE_RED='\033[0;31m'
REMOTE_RESET='\033[0m'

# check the tools needed by monitor.sh, manage.sh, and the web server
REQUIRED_COMMANDS=(
    bash
    awk
    free
    df
    hostname
    date
    sleep
    nohup
    grep
    tr
    mv
    mkdir
    cat
    rm
    python3
)
MISSING=0
for CMD in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$CMD" >/dev/null 2>&1; then
        printf '%b[OK]%b %s\n' "$REMOTE_GREEN" "$REMOTE_RESET" "$CMD"
    else
        printf '%b[MISSING]%b %s\n' "$REMOTE_RED" "$REMOTE_RESET" "$CMD"
        MISSING=1
    fi
done
# make sure we can access the Linux system information
if [[ -r /proc/stat && -r /proc/uptime && -r /proc/net/route && -d /sys/class/net ]]; then
    printf '%b[OK]%b Linux system statistics available.\n' "$REMOTE_GREEN" "$REMOTE_RESET"
else
    printf '%b[ERROR]%b Cannot access Linux system statistics.\n' "$REMOTE_RED" "$REMOTE_RESET"
    MISSING=1
fi
# python will serve our HTML and JSON files
if command -v python3 >/dev/null 2>&1; then
    python3 --version
    if ! python3 -c 'import http.server' 2>/dev/null; then
        printf '%b[ERROR]%b Python HTTP server module unavailable.\n' "$REMOTE_RED" "$REMOTE_RESET"
        MISSING=1
    fi
fi
exit "$MISSING"
REMOTE_CHECK
    ok "EC2 requirements passed."
else
    error "EC2 is missing something we need."
    echo "Deployment stopped before making changes."
    exit 1
fi
# automated the mkdir folders and subfulders to transfer files
echo ""
info "Creating project folders on EC2..."
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" \
    'mkdir -p "$HOME/ec2-monitoring-tool/remote/scripts" "$HOME/ec2-monitoring-tool/remote/public"'
then
    ok "Remote folders are ready."
else
    error "Could not create the remote folders."
    exit 1
fi
# automated the upload of scripts to the ec2 instance
echo ""
info "Uploading monitoring scripts..."
if scp -q "${SSH_OPTIONS[@]}" \
    "$PROJECT_DIR/remote/scripts/monitor.sh" \
    "$PROJECT_DIR/remote/scripts/manage.sh" \
    "$SSH_USER@$EC2_HOST:ec2-monitoring-tool/remote/scripts/"
then
    file "monitor.sh"
    file "manage.sh"
    ok "Monitoring scripts uploaded."
else
    error "Failed to upload monitoring scripts."
    exit 1
fi
# automated the upload of dashboard files
echo ""
info "Uploading dashboard files..."

if scp -q "${SSH_OPTIONS[@]}" \
    "$PROJECT_DIR/remote/public/index.html" \
    "$PROJECT_DIR/remote/public/styles.css" \
    "$PROJECT_DIR/remote/public/app.js" \
    "$SSH_USER@$EC2_HOST:ec2-monitoring-tool/remote/public/"
then
    file "index.html"
    file "styles.css"
    file "app.js"
    ok "Dashboard files uploaded."
else
    error "Failed to upload dashboard files."
    exit 1
fi
# doing a verification check to make sure all files were transferred from local env to the ec2 successfully
echo ""
info "Verifying uploaded files..."
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" \
    'test -s "$HOME/ec2-monitoring-tool/remote/scripts/monitor.sh" &&
     test -s "$HOME/ec2-monitoring-tool/remote/scripts/manage.sh" &&
     test -s "$HOME/ec2-monitoring-tool/remote/public/index.html" &&
     test -s "$HOME/ec2-monitoring-tool/remote/public/styles.css" &&
     test -s "$HOME/ec2-monitoring-tool/remote/public/app.js"'
then
    ok "All five project files verified."
else
    error "One or more uploaded files are missing or empty."
    exit 1
fi
# start monitoring and make sure it actually works
echo ""
info "Starting monitoring collector..."
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" 'bash -s' <<'REMOTE_COLLECTOR'; then
# These commands run on EC2, so the local color functions aren't available here.
# go to the scripts folder on EC2
cd "$HOME/ec2-monitoring-tool/remote/scripts" || exit 1
# Restart the managed collector so redeploying picks up monitor.sh edits.
bash manage.sh stop || exit 1
bash manage.sh start || exit 1
JSON_FILE="$HOME/ec2-monitoring-tool/remote/public/data/metrics.json"
# give the collector a few chances to write valid JSON
READY=0
for attempt in {1..6}; do
    if [[ -s "$JSON_FILE" ]] && python3 -m json.tool "$JSON_FILE" >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 2
done
if (( READY == 0 )); then
    printf "\033[0;31m[ERROR]\033[0m No valid JSON after startup.\n"
    exit 1
fi
# make sure the JSON file is still being updated
FIRST_UPDATE=$(date -r "$JSON_FILE" +%s) || exit 1
sleep 5
SECOND_UPDATE=$(date -r "$JSON_FILE" +%s) || exit 1
if (( SECOND_UPDATE <= FIRST_UPDATE )); then
    printf "\033[0;31m[ERROR]\033[0m JSON exists but is not updating.\n"
    exit 1
fi
# check the updated JSON one more time
if ! python3 -m json.tool "$JSON_FILE" >/dev/null 2>&1; then
    printf "\033[0;31m[ERROR]\033[0m Updated JSON is invalid.\n"
    exit 1
fi
printf "\033[0;32m[OK]\033[0m JSON is valid and updating.\n"
REMOTE_COLLECTOR
    ok "Monitoring collector is ready."
else
    error "Monitoring collector failed to start or update its data."
    exit 1
fi

#! starting up the web server on ec2
echo ""
info "Checking dashboard HTTP server..."
if ssh "${SSH_OPTIONS[@]}" \
    "$SSH_USER@$EC2_HOST" 'bash -s' <<'REMOTE_WEB'; then
# This block also runs on EC2, so print colored labels directly.
# set up paths for the website, process info, and logs
WEB_DIR="$HOME/ec2-monitoring-tool/remote/public"
RUN_DIR="$HOME/ec2-monitoring-tool/remote/run"
LOG_DIR="$HOME/ec2-monitoring-tool/remote/logs"
mkdir -p "$RUN_DIR" "$LOG_DIR"
# check whether something is already using port 8000
if python3 -c 'import socket; socket.create_connection(("127.0.0.1", 8000), timeout=1)' >/dev/null 2>&1; then
    printf "\033[1;33m[INFO]\033[0m Port 8000 is in use. Checking existing server.\n"
else
    # start Python in the background and save its PID
    nohup python3 -m http.server 8000 \
        --bind 127.0.0.1 \
        --directory "$WEB_DIR" \
        >> "$LOG_DIR/web.log" 2>&1 < /dev/null &
    echo "$!" > "$RUN_DIR/web.pid"
    printf "\033[1;33m[INFO]\033[0m Started Python HTTP server (PID %s).\n" "$!"
fi
# verify the server is actually serving our dashboard
READY=0
for attempt in {1..5}; do
    if python3 -c '
import json
from pathlib import Path
from urllib.request import urlopen
web_dir = Path.home() / "ec2-monitoring-tool/remote/public"
base_url = "http://127.0.0.1:8000"
with urlopen(base_url + "/index.html", timeout=2) as response:
    served_html = response.read()
if served_html != (web_dir / "index.html").read_bytes():
    raise ValueError("Wrong dashboard directory")
with urlopen(base_url + "/data/metrics.json", timeout=2) as response:
    metrics = json.load(response)
if "cpu_percent" not in metrics:
    raise ValueError("Missing monitoring data")
' >/dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
done
if (( READY == 0 )); then
    printf "\033[0;31m[ERROR]\033[0m HTTP server unavailable or serving the wrong files.\n"
    echo "Check port 8000 and $LOG_DIR/web.log"
    exit 1
fi
printf "\033[0;32m[OK]\033[0m Dashboard HTML and JSON are available.\n"
REMOTE_WEB
    ok "Dashboard HTTP server is ready."
else
    error "Dashboard HTTP server failed verification."
    exit 1
fi

# Connect to the dashboard and open the default browser.
echo ""
info "Opening SSH tunnel to EC2..."

DASHBOARD_URL="http://127.0.0.1:8080/index.html"

# Git Bash normally includes curl; we use it to confirm the tunnel is ready.
if ! command -v curl >/dev/null 2>&1; then
    error "Couldn't find curl on this computer."
    exit 1
fi

# Don't accidentally use an older tunnel or another application on port 8080.
if curl -sS --max-time 1 "$DASHBOARD_URL" >/dev/null 2>&1; then
    error "Local port 8080 is already serving a website. Close the old tunnel first."
    exit 1
fi

# Start forwarding in the background just long enough to check it's ready.
# We still keep this terminal open and close this tunnel with Ctrl+C.
ssh "${SSH_OPTIONS[@]}" \
    -o ExitOnForwardFailure=yes \
    -N \
    -L 127.0.0.1:8080:127.0.0.1:8000 \
    "$SSH_USER@$EC2_HOST" &
TUNNEL_PID=$!

# Only stop the SSH process started by this script.
close_tunnel() {
    if kill -0 "$TUNNEL_PID" 2>/dev/null; then
        kill "$TUNNEL_PID" 2>/dev/null || true
        wait "$TUNNEL_PID" 2>/dev/null || true
    fi
}
trap close_tunnel EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Wait until the webpage is reachable through our tunnel.
TUNNEL_READY=0
for attempt in {1..20}; do
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        break
    fi
    if curl -fsS --max-time 2 "$DASHBOARD_URL" >/dev/null 2>&1; then
        TUNNEL_READY=1
        break
    fi
    sleep 0.5
done

if (( TUNNEL_READY == 0 )); then
    error "SSH tunnel didn't become ready on port 8080."
    exit 1
fi

ok "SSH tunnel is ready."
echo "Dashboard: $DASHBOARD_URL"

# Open the dashboard in the default browser on macOS or Windows.
# This avoids relying on whether the terminal makes the URL clickable.
if [[ "$OSTYPE" == darwin* ]]; then
    if open "$DASHBOARD_URL" >/dev/null 2>&1; then
        ok "Opened dashboard in your default browser."
    else
        info "Couldn't open the browser automatically. Use the URL above."
    fi
elif command -v powershell.exe >/dev/null 2>&1; then
    if powershell.exe -NoProfile -NonInteractive -Command "Start-Process '$DASHBOARD_URL'" >/dev/null 2>&1; then
        ok "Opened dashboard in your default browser."
    else
        info "Couldn't open the browser automatically. Use the URL above."
    fi
else
    info "Open the URL above in your browser."
fi

echo "Keep this terminal open while using the dashboard."
echo "Press Ctrl+C when finished."

# Wait for the tunnel so the launcher doesn't immediately close.
wait "$TUNNEL_PID"
echo ""
info "SSH tunnel closed."
