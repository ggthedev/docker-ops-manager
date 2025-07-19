#!/usr/bin/env bash

# Tracing System Module
# Provides detailed method invocation tracking for debugging and flow analysis

# Tracing configuration
TRACE_ENABLED=false
TRACE_DEPTH=0
TRACE_STACK=()
TRACE_TIMESTAMPS=()
TRACE_FILE=""
TRACE_INDENT="  "

# =============================================================================
# FUNCTION: init_tracing
# =============================================================================
# Purpose: Initialize the tracing system with specified options
# Inputs: 
#   $1 - enabled: Whether tracing is enabled (true/false)
#   $2 - trace_file: Optional file to write traces to (defaults to log file)
# Outputs: None
# Side Effects: 
#   - Sets up tracing configuration
#   - Creates trace file if specified
#   - Initializes trace stack
# Return code: 0 if successful, 1 if failed
# Usage: Called during system initialization to enable tracing
# Example: init_tracing "true" "/tmp/docker_ops_trace.log"
# =============================================================================
init_tracing() {
    local enabled="${1:-false}"
    local trace_file="${2:-}"
    
    TRACE_ENABLED="$enabled"
    TRACE_DEPTH=0
    TRACE_STACK=()
    TRACE_TIMESTAMPS=()
    
    if [[ "$TRACE_ENABLED" == "true" ]]; then
        if [[ -n "$trace_file" ]]; then
            TRACE_FILE="$trace_file"
        else
            # Use the same naming convention as log files: docker_ops_trace_YYYY-MM-DD.log
            local current_date=$(date '+%Y-%m-%d')
            TRACE_FILE="${DOCKER_OPS_LOG_DIR:-/tmp}/docker_ops_trace_${current_date}.log"
        fi
        
        # Clean up old trace files to prevent disk space issues (same retention as logs)
        cleanup_old_trace_files
        
        # Create trace file header if it doesn't exist or is empty
        if [[ ! -f "$TRACE_FILE" ]] || [[ ! -s "$TRACE_FILE" ]]; then
            echo "=== Docker Ops Manager Trace Log ===" > "$TRACE_FILE"
            echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TRACE_FILE"
            echo "PID: $$" >> "$TRACE_FILE"
            echo "Command: $0 $*" >> "$TRACE_FILE"
            echo "===================================" >> "$TRACE_FILE"
            echo "" >> "$TRACE_FILE"
        else
            # Add session separator to existing file (append mode)
            echo "" >> "$TRACE_FILE"
            echo "=== New Session ===" >> "$TRACE_FILE"
            echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TRACE_FILE"
            echo "PID: $$" >> "$TRACE_FILE"
            echo "Command: $0 $*" >> "$TRACE_FILE"
            echo "===================" >> "$TRACE_FILE"
            echo "" >> "$TRACE_FILE"
        fi
        
        # Only call log_info if it's available (logging system might not be initialized yet)
        if command -v log_info >/dev/null 2>&1; then
            log_info "TRACING" "" "Tracing enabled - output to: $TRACE_FILE"
        fi
    fi
}

# =============================================================================
# FUNCTION: trace_enter
# =============================================================================
# Purpose: Mark entry into a function/method for tracing
# Inputs: 
#   $1 - function_name: Name of the function being entered
#   $2 - args: Arguments passed to the function (optional)
#   $3 - context: Additional context information (optional)
# Outputs: None
# Side Effects: 
#   - Increments trace depth
#   - Adds function to trace stack
#   - Records timestamp
#   - Writes trace entry to file
# Return code: 0 if successful, 1 if failed
# Usage: Called at the beginning of functions to trace
# Example: trace_enter "generate_from_yaml" "yaml_file=$1, container_name=$2" "YAML generation"
# =============================================================================
trace_enter() {
    local function_name="$1"
    local args="${2:-}"
    local context="${3:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Check if trace file needs rotation
    rotate_trace_file
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    # Add to trace stack
    TRACE_STACK+=("$function_name")
    TRACE_TIMESTAMPS+=("$timestamp")
    TRACE_DEPTH=$((TRACE_DEPTH + 1))
    
    # Write trace entry
    {
        echo "[$timestamp] ${indent}→ ENTER: $function_name"
        if [[ -n "$args" ]]; then
            echo "[$timestamp] ${indent}  Args: $args"
        fi
        if [[ -n "$context" ]]; then
            echo "[$timestamp] ${indent}  Context: $context"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_exit
# =============================================================================
# Purpose: Mark exit from a function/method for tracing
# Inputs: 
#   $1 - function_name: Name of the function being exited
#   $2 - return_code: Return code of the function (optional)
#   $3 - result: Result or output of the function (optional)
#   $4 - duration: Duration of the function execution in seconds (optional)
# Outputs: None
# Side Effects: 
#   - Decrements trace depth
#   - Removes function from trace stack
#   - Writes trace exit to file
# Return code: 0 if successful, 1 if failed
# Usage: Called at the end of functions to trace
# Example: trace_exit "generate_from_yaml" "$?" "Container created successfully" "2.5"
# =============================================================================
trace_exit() {
    local function_name="$1"
    local return_code="${2:-0}"
    local result="${3:-}"
    local duration="${4:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    TRACE_DEPTH=$((TRACE_DEPTH - 1))
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    # Remove from trace stack
    if [[ ${#TRACE_STACK[@]} -gt 0 ]]; then
        unset TRACE_STACK[$((${#TRACE_STACK[@]} - 1))]
        TRACE_STACK=("${TRACE_STACK[@]}")
    fi
    
    # Write trace exit
    {
        echo "[$timestamp] ${indent}← EXIT: $function_name (rc=$return_code)"
        if [[ -n "$result" ]]; then
            echo "[$timestamp] ${indent}  Result: $result"
        fi
        if [[ -n "$duration" ]]; then
            echo "[$timestamp] ${indent}  Duration: ${duration}s"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_log
# =============================================================================
# Purpose: Log a trace message within a function
# Inputs: 
#   $1 - message: The trace message to log
#   $2 - level: Trace level (INFO, DEBUG, WARN, ERROR) - optional
# Outputs: None
# Side Effects: Writes trace message to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called within functions to log important trace points
# Example: trace_log "Extracted image name: nginx:alpine" "INFO"
# =============================================================================
trace_log() {
    local message="$1"
    local level="${2:-INFO}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Check if trace file needs rotation
    rotate_trace_file
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    local current_function="${TRACE_STACK[$((${#TRACE_STACK[@]} - 1))]:-unknown}"
    
    echo "[$timestamp] ${indent}[$level] $current_function: $message" >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_command
# =============================================================================
# Purpose: Trace execution of external commands
# Inputs: 
#   $1 - command: The command being executed
#   $2 - operation: The operation context (optional)
#   $3 - container: The container context (optional)
# Outputs: None
# Side Effects: Writes command trace to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called before executing Docker or other external commands
# Example: trace_command "docker run -d --name web nginx:alpine" "GENERATE" "web"
# =============================================================================
trace_command() {
    local command="$1"
    local operation="${2:-}"
    local container="${3:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    {
        echo "[$timestamp] ${indent}🔧 COMMAND: $command"
        if [[ -n "$operation" ]]; then
            echo "[$timestamp] ${indent}  Operation: $operation"
        fi
        if [[ -n "$container" ]]; then
            echo "[$timestamp] ${indent}  Container: $container"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_command_result
# =============================================================================
# Purpose: Trace the result of external command execution
# Inputs: 
#   $1 - command: The command that was executed
#   $2 - exit_code: Exit code of the command
#   $3 - output: Output of the command (optional)
#   $4 - duration: Duration of command execution (optional)
# Outputs: None
# Side Effects: Writes command result trace to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called after executing external commands
# Example: trace_command_result "docker run -d --name web nginx:alpine" "$?" "container_id" "1.2"
# =============================================================================
trace_command_result() {
    local command="$1"
    local exit_code="$2"
    local output="${3:-}"
    local duration="${4:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    local status_icon="✅"
    
    if [[ $exit_code -ne 0 ]]; then
        status_icon="❌"
    fi
    
    {
        echo "[$timestamp] ${indent}$status_icon RESULT: $command (rc=$exit_code)"
        if [[ -n "$output" ]]; then
            echo "[$timestamp] ${indent}  Output: $output"
        fi
        if [[ -n "$duration" ]]; then
            echo "[$timestamp] ${indent}  Duration: ${duration}s"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_yaml_parse
# =============================================================================
# Purpose: Trace YAML parsing operations
# Inputs: 
#   $1 - yaml_file: Path to the YAML file being parsed
#   $2 - operation: The parsing operation (validate, extract, detect, etc.)
#   $3 - details: Additional details about the parsing (optional)
# Outputs: None
# Side Effects: Writes YAML parsing trace to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called during YAML parsing operations
# Example: trace_yaml_parse "docker-compose.yml" "validate" "File exists and readable"
# =============================================================================
trace_yaml_parse() {
    local yaml_file="$1"
    local operation="$2"
    local details="${3:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    {
        echo "[$timestamp] ${indent}📄 YAML: $operation - $yaml_file"
        if [[ -n "$details" ]]; then
            echo "[$timestamp] ${indent}  Details: $details"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_container_operation
# =============================================================================
# Purpose: Trace container-specific operations
# Inputs: 
#   $1 - container_name: Name of the container
#   $2 - operation: The container operation (create, start, stop, etc.)
#   $3 - details: Additional details about the operation (optional)
# Outputs: None
# Side Effects: Writes container operation trace to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called during container operations
# Example: trace_container_operation "web" "create" "Image: nginx:alpine, Ports: 80:80"
# =============================================================================
trace_container_operation() {
    local container_name="$1"
    local operation="$2"
    local details="${3:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    {
        echo "[$timestamp] ${indent}🐳 CONTAINER: $operation - $container_name"
        if [[ -n "$details" ]]; then
            echo "[$timestamp] ${indent}  Details: $details"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: trace_state_operation
# =============================================================================
# Purpose: Trace state management operations
# Inputs: 
#   $1 - operation: The state operation (get, set, update, etc.)
#   $2 - key: The state key being operated on
#   $3 - value: The value being set or retrieved (optional)
# Outputs: None
# Side Effects: Writes state operation trace to trace file
# Return code: 0 if successful, 1 if failed
# Usage: Called during state management operations
# Example: trace_state_operation "set" "last_container" "web"
# =============================================================================
trace_state_operation() {
    local operation="$1"
    local key="$2"
    local value="${3:-}"
    
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local indent=$(printf "%${TRACE_DEPTH}s" | tr ' ' "$TRACE_INDENT")
    
    {
        echo "[$timestamp] ${indent}💾 STATE: $operation - $key"
        if [[ -n "$value" ]]; then
            echo "[$timestamp] ${indent}  Value: $value"
        fi
    } >> "$TRACE_FILE"
}

# =============================================================================
# FUNCTION: get_trace_stack
# =============================================================================
# Purpose: Get the current function call stack for debugging
# Inputs: None
# Outputs: Current function call stack as string
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called to get current call stack for debugging
# Example: local stack=$(get_trace_stack)
# =============================================================================
get_trace_stack() {
    if [[ ${#TRACE_STACK[@]} -eq 0 ]]; then
        echo "empty"
        return 0
    fi
    
    local stack=""
    for i in "${!TRACE_STACK[@]}"; do
        if [[ $i -gt 0 ]]; then
            stack="$stack → "
        fi
        stack="$stack${TRACE_STACK[$i]}"
    done
    
    echo "$stack"
}

# =============================================================================
# FUNCTION: get_trace_summary
# =============================================================================
# Purpose: Get a summary of the current tracing state
# Inputs: None
# Outputs: Summary of tracing state as string
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called to get tracing summary for debugging
# Example: local summary=$(get_trace_summary)
# =============================================================================
get_trace_summary() {
    local summary="Tracing: $TRACE_ENABLED"
    if [[ "$TRACE_ENABLED" == "true" ]]; then
        summary="$summary, File: $TRACE_FILE, Depth: $TRACE_DEPTH"
        local stack=$(get_trace_stack)
        summary="$summary, Stack: $stack"
    fi
    
    echo "$summary"
}

# =============================================================================
# FUNCTION: cleanup_tracing
# =============================================================================
# Purpose: Clean up tracing resources and write summary
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Writes trace summary to trace file
#   - Resets tracing state
# Return code: 0 if successful, 1 if failed
# Usage: Called during script cleanup to finalize tracing
# Example: cleanup_tracing
# =============================================================================
cleanup_tracing() {
    if [[ "$TRACE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Only write to trace file if it exists and is writable
    if [[ -n "$TRACE_FILE" ]] && [[ -w "$TRACE_FILE" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
        
        {
            echo ""
            echo "=== Session Summary ==="
            echo "Ended: $timestamp"
            echo "Total functions traced: ${#TRACE_STACK[@]}"
            echo "Final depth: $TRACE_DEPTH"
            echo "======================"
            echo ""
        } >> "$TRACE_FILE"
    fi
    
    # Reset tracing state
    TRACE_ENABLED=false
    TRACE_DEPTH=0
    TRACE_STACK=()
    TRACE_TIMESTAMPS=()
    
    # Only call log_info if it's available
    if command -v log_info >/dev/null 2>&1; then
        log_info "TRACING" "" "Tracing completed - log appended to: $TRACE_FILE"
    fi
} 

# =============================================================================
# FUNCTION: rotate_trace_file
# =============================================================================
# Purpose: Check if trace file needs to be rotated to a new day
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Creates new daily trace file if date has changed
#   - Updates TRACE_FILE variable to point to current day's file
# Return code: 0 if successful, 1 if failed
# Usage: Called automatically during tracing operations
# Example: rotate_trace_file
# =============================================================================
rotate_trace_file() {
    if [[ "$TRACE_ENABLED" != "true" ]] || [[ -z "$TRACE_FILE" ]]; then
        return 0
    fi
    
    # Check if we need to rotate to a new day
    local current_date=$(date '+%Y-%m-%d')
    local expected_trace_file="${DOCKER_OPS_LOG_DIR:-/tmp}/docker_ops_trace_${current_date}.log"
    
    # If the current trace file is not for today, switch to today's file
    if [[ "$TRACE_FILE" != "$expected_trace_file" ]]; then
        TRACE_FILE="$expected_trace_file"
        
        # Create trace file header if it doesn't exist
        if [[ ! -f "$TRACE_FILE" ]] || [[ ! -s "$TRACE_FILE" ]]; then
            echo "=== Docker Ops Manager Trace Log ===" > "$TRACE_FILE"
            echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TRACE_FILE"
            echo "PID: $$" >> "$TRACE_FILE"
            echo "Command: $0 $*" >> "$TRACE_FILE"
            echo "===================================" >> "$TRACE_FILE"
            echo "" >> "$TRACE_FILE"
        else
            # Add session separator to existing file
            echo "" >> "$TRACE_FILE"
            echo "=== New Session ===" >> "$TRACE_FILE"
            echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TRACE_FILE"
            echo "PID: $$" >> "$TRACE_FILE"
            echo "Command: $0 $*" >> "$TRACE_FILE"
            echo "===================" >> "$TRACE_FILE"
            echo "" >> "$TRACE_FILE"
        fi
        
        # Only call log_info if it's available
        if command -v log_info >/dev/null 2>&1; then
            log_info "TRACING" "" "Switched to new daily trace file: $TRACE_FILE"
        fi
    fi
} 

# =============================================================================
# FUNCTION: cleanup_old_trace_files
# =============================================================================
# Purpose: Clean up old trace files to prevent disk space issues
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Removes old trace files based on retention period
# Return code: 0 if successful, 1 if failed
# Usage: Called automatically during tracing initialization
# Example: cleanup_old_trace_files
# =============================================================================
cleanup_old_trace_files() {
    # Get the maximum number of days to keep logs from config (use same as logs)
    # Use a default value if get_config_value is not available yet
    local max_days=7
    if command -v get_config_value >/dev/null 2>&1; then
        max_days=$(get_config_value "log_rotation_days" 7)
    fi
    
    # Calculate the cutoff date for files to be removed
    # Handle both Linux (date -d) and macOS (date -v) date syntax
    local cutoff_date=$(date -d "$max_days days ago" +%Y%m%d 2>/dev/null || date -v-${max_days}d +%Y%m%d 2>/dev/null)
    
    if [[ -n "$cutoff_date" ]]; then
        # Use the log directory, defaulting to /tmp if not set
        local log_dir="${DOCKER_OPS_LOG_DIR:-/tmp}"
        
        # Find all trace files and check their dates
        if [[ -d "$log_dir" ]]; then
            find "$log_dir" -name "docker_ops_trace_20*.log" -type f 2>/dev/null | while read -r trace_file; do
                # Extract date from filename (format: docker_ops_trace_YYYY-MM-DD.log)
                local file_date=$(basename "$trace_file" | sed 's/docker_ops_trace_\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)\.log/\1\2\3/')
                # Remove files older than cutoff date
                if [[ "$file_date" < "$cutoff_date" ]]; then
                    rm -f "$trace_file"
                    # Only echo if log_info is not available
                    if ! command -v log_info >/dev/null 2>&1; then
                        echo "Removed old trace file: $trace_file"
                    fi
                fi
            done
        fi
    fi
} 