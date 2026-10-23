#!/bin/bash

# find the scripts and set up the folders I'll need
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor.sh"
RUN_DIR="$SCRIPT_DIR/../run"
LOG_DIR="$SCRIPT_DIR/../logs"
PID_FILE="$RUN_DIR/monitor.pid"
LOG_FILE="$LOG_DIR/monitor.log"
mkdir -p "$RUN_DIR" "$LOG_DIR"
# check if the monitoring process is still running
is_running() {
    # make sure there is a saved process ID
    [[ -f "$PID_FILE" ]] || return 1
    read -r PID < "$PID_FILE"
    # the process ID should only contain numbers
    [[ "$PID" =~ ^[0-9]+$ ]] || return 1

    # check whether the process still exists
    kill -0 "$PID" 2>/dev/null || return 1
    # double-check that the PID belongs to our script
    [[ -r "/proc/$PID/cmdline" ]] || return 1
    #tr '\0' '\n' < "/proc/$PID/cmdline" | grep -Fxq -- "$MONITOR_SCRIPT"
    # the process might disappear while we're checking it
    tr '\0' '\n' 2>/dev/null < "/proc/$PID/cmdline" | grep -Fxq -- "$MONITOR_SCRIPT"
}
# figure out which command the user entered
case "${1:-}" in
    start)
        if is_running; then
            echo "Monitoring is already running (PID $PID)."
            exit 0
        fi
        if [[ ! -f "$MONITOR_SCRIPT" ]]; then
            echo "Can't find monitor.sh at $MONITOR_SCRIPT"
            exit 1
        fi
        # start monitoring in the background
        nohup bash "$MONITOR_SCRIPT" >> "$LOG_FILE" 2>&1 < /dev/null &
        # save its process ID so we can find it later
        echo "$!" > "$PID_FILE"
        sleep 0.2
        if is_running; then
            echo "Started monitoring (PID $PID)."
        else
            echo "Monitoring did not start. Check $LOG_FILE"
            rm -f "$PID_FILE"
            exit 1
        fi
        ;;
    status)
        if is_running; then
            echo "Monitoring is running (PID $PID)."
        else
            echo "Monitoring is stopped."
        fi
        ;;
    stop)
        if ! is_running; then
            rm -f "$PID_FILE"
            echo "Monitoring is already stopped."
            exit 0
        fi
        # ask the monitoring process to stop
        kill "$PID" || exit 1
        # give it a few seconds to shut down
        for attempt in {1..10}; do
            if ! is_running; then
                break
            fi
            sleep 0.5
        done
        if is_running; then
            echo "Monitoring is still stopping. Try again."
            exit 1
        fi
        rm -f "$PID_FILE"
        echo "Monitoring stopped."
        ;;
    *)
        echo "Usage: bash manage.sh {start|stop|status}"
        exit 1
        ;;
esac