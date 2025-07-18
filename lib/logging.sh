#!/usr/bin/env bash

# Logging System Module
# Handles log initialization, levels, rotation, and formatting

# Log levels - defines the hierarchy of log levels
# DEBUG (0) - Most verbose, includes all messages
# INFO (1) - General information messages
# WARN (2) - Warning messages
# ERROR (3) - Error messages only
declare -A LOG_LEVELS=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARN"]=2
    ["ERROR"]=3
)

# Current log level - controls which messages are actually written
CURRENT_LOG_LEVEL="INFO"

# Initialize logging system
# Sets up the logging system with the specified log level and creates log files.
# Also handles log rotation to prevent log files from growing too large.
#
# Input:
#   $1 - log_level: The log level to use (DEBUG, INFO, WARN, ERROR)
# Output: None
# Side effects: Creates log directory, rotates old logs, sets global variables
# Example: init_logging "DEBUG"
init_logging() {
    local log_level="${1:-$DOCKER_OPS_LOG_LEVEL}"
    CURRENT_LOG_LEVEL="$log_level"
    
    # Create log file with timestamp for daily rotation
    local log_file="$DOCKER_OPS_LOG_DIR/docker_ops_$(date +%Y-%m-%d).log"
    export DOCKER_OPS_CURRENT_LOG_FILE="$log_file"
    
    # Clean up old log files to prevent disk space issues
    rotate_logs
    
    # Log the initialization for debugging purposes
    log_info "LOGGING" "Logging system initialized with level: $CURRENT_LOG_LEVEL"
}

# Rotate old log files
# Removes log files older than the configured retention period.
# This prevents log files from consuming too much disk space.
#
# Input: None (uses configuration values)
# Output: None
# Side effects: Deletes old log files from filesystem
rotate_logs() {
    # Get the maximum number of days to keep logs from config
    local max_days=$(get_config_value "log_rotation_days" 7)
    
    # Calculate the cutoff date for files to be removed
    # Handle both Linux (date -d) and macOS (date -v) date syntax
    local cutoff_date=$(date -d "$max_days days ago" +%Y-%m-%d 2>/dev/null || date -v-${max_days}d +%Y-%m-%d 2>/dev/null)
    
    if [[ -n "$cutoff_date" ]]; then
        # Find all log files and check their dates
        find "$DOCKER_OPS_LOG_DIR" -name "docker_ops_*.log" -type f | while read -r log_file; do
            # Extract date from filename (format: docker_ops_YYYY-MM-DD.log)
            local file_date=$(basename "$log_file" | sed 's/docker_ops_\(.*\)\.log/\1/')
            # Remove files older than cutoff date
            if [[ "$file_date" < "$cutoff_date" ]]; then
                rm -f "$log_file"
                echo "Removed old log file: $log_file"
            fi
        done
    fi
}

# Check if log level should be output
# Determines whether a message at the given level should be written to the log
# based on the current log level setting.
#
# Input:
#   $1 - level: The log level of the message (DEBUG, INFO, WARN, ERROR)
# Output: None
# Return code: 0 if message should be logged, 1 if it should be suppressed
should_log() {
    local level="$1"
    # Get numeric values for comparison
    local current_level_num="${LOG_LEVELS[$CURRENT_LOG_LEVEL]:-1}"
    local message_level_num="${LOG_LEVELS[$level]:-0}"
    
    # Only log if message level is >= current level (higher numbers = more important)
    [[ $message_level_num -ge $current_level_num ]]
}

# Format log message
# Creates a standardized log message format with timestamp, level, operation, and container.
# This ensures all log messages have consistent formatting.
#
# Input:
#   $1 - level: Log level (DEBUG, INFO, WARN, ERROR)
#   $2 - operation: The operation being performed
#   $3 - container: The container name (can be empty)
#   $4 - message: The actual log message
# Output: Formatted log message string
# Example: format_log_message "INFO" "START" "my-container" "Container started"
format_log_message() {
    local level="$1"
    local operation="$2"
    local container="$3"
    local message="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format: [timestamp] [level] [operation] [container] - message
    echo "[$timestamp] [$level] [$operation] [$container] - $message"
}

# Write log message
# Writes a formatted log message to the log file and optionally to stderr.
# This is the core function that handles actual log writing.
#
# Input:
#   $1 - level: Log level (DEBUG, INFO, WARN, ERROR)
#   $2 - operation: The operation being performed
#   $3 - container: The container name (can be empty)
#   $4 - message: The actual log message
# Output: None
# Side effects: Writes to log file and optionally stderr
write_log() {
    local level="$1"
    local operation="$2"
    local container="$3"
    local message="$4"
    
    # Check if logging system has been initialized
    if [[ -z "${DOCKER_OPS_CURRENT_LOG_FILE:-}" ]]; then
        return 0
    fi
    
    # Only write if the message level meets the current log level threshold
    if should_log "$level"; then
        # Format the message with timestamp and metadata
        local formatted_message=$(format_log_message "$level" "$operation" "$container" "$message")
        # Append to log file
        echo "$formatted_message" >> "$DOCKER_OPS_CURRENT_LOG_FILE"
        
        # Also output ERROR and WARN messages to stderr for immediate visibility
        if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
            echo "$formatted_message" >&2
        fi
    fi
}

# Log functions for different levels
# These are convenience functions that call write_log with the appropriate level.
# They provide a clean API for logging at different levels.

# Log debug message
# Used for detailed debugging information that's only needed during development.
#
# Input:
#   $1 - operation: The operation being performed (optional)
#   $2 - container: The container name (optional)
#   $3 - message: The debug message
# Output: None
# Example: log_debug "START" "my-container" "Starting container process"
log_debug() {
    local operation="${1:-}"
    local container="${2:-}"
    local message="${3:-}"
    write_log "DEBUG" "$operation" "$container" "$message"
}

# Log info message
# Used for general information about operations being performed.
#
# Input:
#   $1 - operation: The operation being performed (optional)
#   $2 - container: The container name (optional)
#   $3 - message: The info message
# Output: None
# Example: log_info "START" "my-container" "Container started successfully"
log_info() {
    local operation="${1:-}"
    local container="${2:-}"
    local message="${3:-}"
    write_log "INFO" "$operation" "$container" "$message"
}

# Log warning message
# Used for warning conditions that don't stop execution but should be noted.
#
# Input:
#   $1 - operation: The operation being performed (optional)
#   $2 - container: The container name (optional)
#   $3 - message: The warning message
# Output: None
# Example: log_warn "START" "my-container" "Container took longer than expected to start"
log_warn() {
    local operation="${1:-}"
    local container="${2:-}"
    local message="${3:-}"
    write_log "WARN" "$operation" "$container" "$message"
}

# Log error message
# Used for error conditions that may affect operation success.
#
# Input:
#   $1 - operation: The operation being performed (optional)
#   $2 - container: The container name (optional)
#   $3 - message: The error message
# Output: None
# Example: log_error "START" "my-container" "Failed to start container"
log_error() {
    local operation="${1:-}"
    local container="${2:-}"
    local message="${3:-}"
    write_log "ERROR" "$operation" "$container" "$message"
}

# Log operation start
# Convenience function for logging the start of an operation.
# Provides consistent formatting for operation start messages.
#
# Input:
#   $1 - operation: The operation name
#   $2 - container: The container name (optional)
#   $3 - message: Custom start message (optional, defaults to "Starting operation")
# Output: None
# Example: log_operation_start "START" "my-container" "Starting container with custom config"
log_operation_start() {
    local operation="$1"
    local container="$2"
    local message="${3:-Starting operation}"
    log_info "$operation" "$container" "$message"
}

# Log operation success
# Convenience function for logging successful operation completion.
# Provides consistent formatting for success messages.
#
# Input:
#   $1 - operation: The operation name
#   $2 - container: The container name (optional)
#   $3 - message: Custom success message (optional, defaults to "Operation completed successfully")
# Output: None
# Example: log_operation_success "START" "my-container" "Container started and is healthy"
log_operation_success() {
    local operation="$1"
    local container="$2"
    local message="${3:-Operation completed successfully}"
    log_info "$operation" "$container" "$message"
}

# Log operation failure
# Convenience function for logging operation failures.
# Provides consistent formatting for failure messages and includes exit code.
#
# Input:
#   $1 - operation: The operation name
#   $2 - container: The container name (optional)
#   $3 - message: The failure message
#   $4 - exit_code: The exit code (optional, defaults to 1)
# Output: None
# Example: log_operation_failure "START" "my-container" "Container failed to start" 127
log_operation_failure() {
    local operation="$1"
    local container="$2"
    local message="$3"
    local exit_code="${4:-1}"
    log_error "$operation" "$container" "$message (exit code: $exit_code)"
}

# Log Docker command execution
# Logs the execution of Docker commands for debugging purposes.
# This helps track what Docker commands are being run.
#
# Input:
#   $1 - operation: The operation name
#   $2 - container: The container name (optional)
#   $3 - command: The Docker command being executed
# Output: None
# Example: log_docker_command "START" "my-container" "docker start my-container"
log_docker_command() {
    local operation="$1"
    local container="$2"
    local command="$3"
    log_debug "$operation" "$container" "Executing: $command"
}

# Log Docker command result
# Logs the result of Docker command execution including exit code and output.
# This helps with debugging Docker command failures.
#
# Input:
#   $1 - operation: The operation name
#   $2 - container: The container name (optional)
#   $3 - exit_code: The exit code from the Docker command
#   $4 - output: The output from the Docker command
# Output: None
# Example: log_docker_result "START" "my-container" 0 "Container started successfully"
log_docker_result() {
    local operation="$1"
    local container="$2"
    local exit_code="$3"
    local output="$4"
    
    if [[ $exit_code -eq 0 ]]; then
        log_debug "$operation" "$container" "Command succeeded"
        # Log output if present (but only at debug level to avoid log spam)
        if [[ -n "$output" ]]; then
            log_debug "$operation" "$container" "Output: $output"
        fi
    else
        log_error "$operation" "$container" "Command failed with exit code: $exit_code"
        # Always log error output for debugging
        if [[ -n "$output" ]]; then
            log_error "$operation" "$container" "Error output: $output"
        fi
    fi
}

# Get log file path
# Returns the path to the current log file.
# Useful for external tools that need to read the logs.
#
# Input: None
# Output: Path to current log file
# Example: get_log_file
get_log_file() {
    echo "$DOCKER_OPS_CURRENT_LOG_FILE"
}

# Show recent logs
# Displays the most recent log entries from the current log file.
# Useful for quick debugging and monitoring.
#
# Input:
#   $1 - lines: Number of lines to show (optional, defaults to 50)
# Output: Recent log entries
# Example: show_recent_logs 100
show_recent_logs() {
    local lines="${1:-50}"
    local log_file="$DOCKER_OPS_CURRENT_LOG_FILE"
    
    if [[ -f "$log_file" ]]; then
        # Show the last N lines from the log file
        tail -n "$lines" "$log_file"
    else
        echo "No log file found: $log_file"
        return 1
    fi
}

# Show logs for specific container
# Filters and displays log entries for a specific container.
# Useful for debugging issues with a particular container.
#
# Input:
#   $1 - container: The container name to filter logs for
#   $2 - lines: Number of lines to show (optional, defaults to 50)
# Output: Filtered log entries for the container
# Example: show_container_logs "my-container" 25
show_container_logs() {
    local container="$1"
    local lines="${2:-50}"
    local log_file="$DOCKER_OPS_CURRENT_LOG_FILE"
    
    if [[ -f "$log_file" ]]; then
        # Filter logs for the specific container and show last N lines
        grep "\[$container\]" "$log_file" | tail -n "$lines"
    else
        echo "No log file found: $log_file"
        return 1
    fi
}

# Show logs for specific operation
# Filters and displays log entries for a specific operation.
# Useful for debugging issues with a particular operation type.
#
# Input:
#   $1 - operation: The operation name to filter logs for
#   $2 - lines: Number of lines to show (optional, defaults to 50)
# Output: Filtered log entries for the operation
# Example: show_operation_logs "START" 25
show_operation_logs() {
    local operation="$1"
    local lines="${2:-50}"
    local log_file="$DOCKER_OPS_CURRENT_LOG_FILE"
    
    if [[ -f "$log_file" ]]; then
        # Filter logs for the specific operation and show last N lines
        grep "\[$operation\]" "$log_file" | tail -n "$lines"
    else
        echo "No log file found: $log_file"
        return 1
    fi
}

# Clear logs
# Clears the current log file by truncating it to zero size.
# Useful for starting fresh or managing log file size.
#
# Input: None
# Output: None
# Side effects: Clears the current log file
# Example: clear_logs
clear_logs() {
    local log_file="$DOCKER_OPS_CURRENT_LOG_FILE"
    if [[ -f "$log_file" ]]; then
        # Truncate the log file to zero size
        > "$log_file"
        log_info "LOGGING" "" "Logs cleared"
    fi
} 