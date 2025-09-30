#!/bin/bash

# RAM Monitor Script for automatic flussonic process restart on high memory usage
# Developer: RAM Monitor Script
# Date: $(date)

# Configuration
RAM_THRESHOLD=80
LOG_FILE="/var/log/flussonic_ram_monitor.log"
PROCESS_NAME="flussonic"
SERVICE_NAME="flussonic"  # systemd service name

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to get RAM usage percentage
get_ram_usage() {
    log_message "DEBUG: Starting get_ram_usage() function"
    
    # Get memory information from /proc/meminfo
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    log_message "DEBUG: MemTotal = $mem_total KB"
    
    # If MemAvailable is not available, use alternative calculation
    if [ -z "$mem_available" ]; then
        log_message "DEBUG: MemAvailable not found, using alternative calculation"
        local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
        mem_available=$((mem_free + buffers + cached))
        log_message "DEBUG: MemFree = $mem_free KB, Buffers = $buffers KB, Cached = $cached KB"
    fi
    
    log_message "DEBUG: MemAvailable = $mem_available KB"
    
    # Calculate usage percentage
    local mem_used=$((mem_total - mem_available))
    local ram_usage=$((mem_used * 100 / mem_total))
    
    log_message "DEBUG: MemUsed = $mem_used KB, RAM Usage = $ram_usage%"
    log_message "DEBUG: Finishing get_ram_usage() function, result: $ram_usage%"
    
    echo "$ram_usage"
}

# Function to check if process is running
is_process_running() {
    log_message "DEBUG: Starting is_process_running() function"
    log_message "DEBUG: Searching for process with name: $PROCESS_NAME"
    
    local pids=$(pgrep -x "$PROCESS_NAME" 2>/dev/null)
    if [ -n "$pids" ]; then
        log_message "DEBUG: Found processes with PIDs: $pids"
        log_message "DEBUG: Finishing is_process_running(), result: process is running"
        return 0
    else
        log_message "DEBUG: No processes found with name $PROCESS_NAME"
        log_message "DEBUG: Finishing is_process_running(), result: process is not running"
        return 1
    fi
}

# Function to restart flussonic via systemd
restart_flussonic() {
    log_message "DEBUG: Starting restart_flussonic() function"
    log_message "INFO: Attempting to restart $SERVICE_NAME via systemd"
    
    log_message "DEBUG: Executing command 'systemctl restart $SERVICE_NAME'"
    local restart_output
    restart_output=$(systemctl restart "$SERVICE_NAME" 2>&1)
    local restart_exit_code=$?
    
    log_message "DEBUG: systemctl restart exit code: $restart_exit_code"
    if [ -n "$restart_output" ]; then
        log_message "DEBUG: systemctl restart output: $restart_output"
    fi
    
    if [ $restart_exit_code -eq 0 ]; then
        log_message "INFO: $SERVICE_NAME successfully restarted via systemd"
        
        # Check service status
        local status_output
        status_output=$(systemctl is-active "$SERVICE_NAME" 2>&1)
        log_message "DEBUG: Service status after restart: $status_output"
        
        log_message "DEBUG: Finishing restart_flussonic(), result: success"
        return 0
    else
        log_message "ERROR: Failed to restart $SERVICE_NAME via systemd"
        log_message "DEBUG: Finishing restart_flussonic(), result: failure"
        return 1
    fi
}

# Function for emergency process termination
force_kill_process() {
    log_message "DEBUG: Starting force_kill_process() function"
    log_message "INFO: Emergency termination of process $PROCESS_NAME"
    
    # First try SIGTERM
    log_message "DEBUG: Sending SIGTERM to process $PROCESS_NAME"
    local pkill_output
    pkill_output=$(pkill -x "$PROCESS_NAME" 2>&1)
    local pkill_exit_code=$?
    
    log_message "DEBUG: pkill SIGTERM exit code: $pkill_exit_code"
    if [ -n "$pkill_output" ]; then
        log_message "DEBUG: pkill SIGTERM output: $pkill_output"
    fi
    
    if [ $pkill_exit_code -eq 0 ]; then
        log_message "DEBUG: SIGTERM sent successfully, waiting 5 seconds"
        sleep 5
        # Check if process terminated
        if ! is_process_running; then
            log_message "INFO: Process $PROCESS_NAME successfully terminated via SIGTERM"
            log_message "DEBUG: Finishing force_kill_process(), result: success (SIGTERM)"
            return 0
        else
            log_message "DEBUG: Process still running after SIGTERM"
        fi
    else
        log_message "DEBUG: Error sending SIGTERM"
    fi
    
    # If process is still running, use SIGKILL
    if is_process_running; then
        log_message "INFO: Using SIGKILL to terminate $PROCESS_NAME"
        log_message "DEBUG: Sending SIGKILL to process $PROCESS_NAME"
        
        local pkill9_output
        pkill9_output=$(pkill -9 -x "$PROCESS_NAME" 2>&1)
        local pkill9_exit_code=$?
        
        log_message "DEBUG: pkill SIGKILL exit code: $pkill9_exit_code"
        if [ -n "$pkill9_output" ]; then
            log_message "DEBUG: pkill SIGKILL output: $pkill9_output"
        fi
        
        log_message "DEBUG: Waiting 2 seconds after SIGKILL"
        sleep 2
        
        # Check if process really terminated
        if ! is_process_running; then
            log_message "DEBUG: Process successfully terminated via SIGKILL"
        else
            log_message "DEBUG: WARNING: Process still running even after SIGKILL"
        fi
    fi
    
    log_message "DEBUG: Finishing force_kill_process()"
    return 0
}

# Main function
main() {
    log_message "DEBUG: Starting main() function execution"
    log_message "DEBUG: RAM threshold: $RAM_THRESHOLD%"
    
    # Get current RAM usage
    log_message "DEBUG: Calling get_ram_usage() function"
    current_ram_usage=$(get_ram_usage)
    log_message "DEBUG: Current RAM usage: $current_ram_usage%"
    
    # Check if RAM usage exceeds threshold
    if [ "$current_ram_usage" -ge "$RAM_THRESHOLD" ]; then
        log_message "WARNING: RAM usage $current_ram_usage% >= $RAM_THRESHOLD%. Initiating $PROCESS_NAME restart"
        
        # Check if process is running at all
        log_message "DEBUG: Checking status of process $PROCESS_NAME"
        if is_process_running; then
            log_message "INFO: Process $PROCESS_NAME is running. Starting restart..."
            
            # Try to restart via systemd
            log_message "DEBUG: Calling restart_flussonic() function"
            if ! restart_flussonic; then
                log_message "WARNING: systemd restart failed. Using emergency method..."
                log_message "DEBUG: Calling force_kill_process() function"
                force_kill_process
                
                # Try to start again via systemd
                log_message "DEBUG: Waiting 3 seconds before attempting service start"
                sleep 3
                log_message "DEBUG: Attempting to start $SERVICE_NAME via systemd"
                
                local start_output
                start_output=$(systemctl start "$SERVICE_NAME" 2>&1)
                local start_exit_code=$?
                
                log_message "DEBUG: systemctl start exit code: $start_exit_code"
                if [ -n "$start_output" ]; then
                    log_message "DEBUG: systemctl start output: $start_output"
                fi
                
                if [ $start_exit_code -eq 0 ]; then
                    log_message "INFO: $SERVICE_NAME started after emergency termination"
                else
                    log_message "CRITICAL: Failed to start $SERVICE_NAME"
                fi
            fi
            
        else
            log_message "WARNING: Process $PROCESS_NAME is not running. Attempting to start..."
            log_message "DEBUG: Attempting to start $SERVICE_NAME via systemd"
            
            local start_output
            start_output=$(systemctl start "$SERVICE_NAME" 2>&1)
            local start_exit_code=$?
            
            log_message "DEBUG: systemctl start exit code: $start_exit_code"
            if [ -n "$start_output" ]; then
                log_message "DEBUG: systemctl start output: $start_output"
            fi
            
            if [ $start_exit_code -eq 0 ]; then
                log_message "INFO: $SERVICE_NAME successfully started"
            else
                log_message "ERROR: Failed to start $SERVICE_NAME"
            fi
        fi
        
        # Check status after actions
        log_message "DEBUG: Waiting 5 seconds before final check"
        sleep 5
        log_message "DEBUG: Final process status check"
        if is_process_running; then
            log_message "DEBUG: Getting new RAM usage value"
            new_ram_usage=$(get_ram_usage)
            log_message "INFO: Process $PROCESS_NAME is running. Current RAM usage: $new_ram_usage%"
            
            # Check if we managed to reduce load
            if [ "$new_ram_usage" -lt "$current_ram_usage" ]; then
                log_message "DEBUG: RAM load decreased from $current_ram_usage% to $new_ram_usage%"
            else
                log_message "DEBUG: WARNING: RAM load did not decrease (was: $current_ram_usage%, now: $new_ram_usage%)"
            fi
        else
            log_message "CRITICAL: Process $PROCESS_NAME is not running after restart"
        fi
        
    else
        # Log only once per hour during normal operation (to reduce log size)
        current_minute=$(date '+%M')
        if [ "$current_minute" = "00" ]; then
            log_message "DEBUG: Hourly report of normal operation"
            local process_status
            if is_process_running; then
                process_status="running"
            else
                process_status="stopped"
            fi
            log_message "INFO: Normal operation: RAM $current_ram_usage%, process $PROCESS_NAME: $process_status"
        fi
    fi
    
    log_message "DEBUG: Finishing main() function execution"
}

# Create log file if it doesn't exist
touch "$LOG_FILE"
log_message "=== STARTING RAM MONITOR SCRIPT ==="
log_message "DEBUG: Script version: 2.0 (with detailed logging)"
log_message "DEBUG: Configuration - RAM threshold: $RAM_THRESHOLD%, Process: $PROCESS_NAME, Service: $SERVICE_NAME"
log_message "DEBUG: Log file: $LOG_FILE"

# Run main function
main

log_message "DEBUG: Script execution completed"
log_message "=== SCRIPT EXECUTION FINISHED ==="

exit 0
