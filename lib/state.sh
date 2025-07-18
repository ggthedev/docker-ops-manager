#!/usr/bin/env bash

# State Management Module
# Handles state file operations, container history tracking, and operation history

# Initialize state file
# Creates the initial state file with default structure if it doesn't exist.
# The state file stores information about containers, operations, and history.
#
# Input: None (uses global config variables)
# Output: None
# Side effects: Creates state.json file if it doesn't exist
init_state_file() {
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "init_state_file" "" "State file initialization"
    
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        trace_log "No state file path configured, skipping initialization" "WARN"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "init_state_file" "0" "No state file path configured" "$duration"
        return 0
    fi
    
    # Only create the file if it doesn't already exist
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        trace_log "Creating new state file: $DOCKER_OPS_STATE_FILE" "INFO"
        # Create initial JSON structure with default values
        cat > "$DOCKER_OPS_STATE_FILE" << EOF
{
    "config": {
        "log_level": "$DOCKER_OPS_LOG_LEVEL",
        "log_rotation_days": $DOCKER_OPS_LOG_ROTATION_DAYS,
        "max_container_history": $DOCKER_OPS_MAX_CONTAINER_HISTORY
    },
    "state": {
        "last_container": "",
        "last_operation": "",
        "last_yaml_file": "",
        "container_history": [],
        "operations": {}
    }
}
EOF
        trace_log "State file created successfully" "INFO"
        log_info "STATE" "" "State file initialized: $DOCKER_OPS_STATE_FILE"
    else
        trace_log "State file already exists: $DOCKER_OPS_STATE_FILE" "DEBUG"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "init_state_file" "0" "State file ready" "$duration"
}

# Get state value from JSON state file
# Retrieves a specific value from the state file using jq.
# Returns the default value if the key doesn't exist or the file doesn't exist.
#
# Input:
#   $1 - key: The state key to retrieve (e.g., "last_container", "last_operation")
#   $2 - default_value: Value to return if key doesn't exist
# Output: The state value or default value
# Example: get_state_value "last_container" ""
get_state_value() {
    local key="$1"
    local default_value="$2"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "get_state_value" "key=$key, default_value=$default_value" "State value retrieval"
    
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        trace_log "No state file path configured, returning default" "WARN"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "get_state_value" "0" "Default value: $default_value" "$duration"
        echo "$default_value"
        return 0
    fi
    
    # Check if state file exists before trying to read from it
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        trace_log "Reading from state file: $DOCKER_OPS_STATE_FILE" "DEBUG"
        # Use jq to extract the value from JSON, suppress errors
        local value=$(jq -r ".state.$key" "$DOCKER_OPS_STATE_FILE" 2>/dev/null)
        # Check if value is valid (not null and not empty)
        if [[ "$value" != "null" && -n "$value" ]]; then
            trace_log "Found value: $value" "DEBUG"
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "get_state_value" "0" "Value: $value" "$duration"
            echo "$value"
        else
            trace_log "Value not found or null, using default: $default_value" "DEBUG"
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "get_state_value" "0" "Default value: $default_value" "$duration"
            echo "$default_value"
        fi
    else
        trace_log "State file does not exist, returning default" "WARN"
        # Return default if state file doesn't exist
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "get_state_value" "0" "Default value: $default_value" "$duration"
        echo "$default_value"
    fi
}

# Set state value in JSON state file
# Updates or adds a value in the state file using jq.
# Creates the state file if it doesn't exist.
#
# Input:
#   $1 - key: The state key to set
#   $2 - value: The value to set for the key
# Output: None
# Side effects: Updates state.json file
# Example: set_state_value "last_container" "my-container"
set_state_value() {
    local key="$1"
    local value="$2"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "set_state_value" "key=$key, value=$value" "State value update"
    
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        trace_log "No state file path configured, skipping update" "WARN"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "set_state_value" "0" "No state file path" "$duration"
        return 0
    fi
    
    # Create state file if it doesn't exist
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        trace_log "State file does not exist, initializing" "INFO"
        init_state_file
    fi
    
    # Handle different value types for proper JSON formatting
    trace_log "Updating state value: $key = $value" "DEBUG"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        # Numeric value - no quotes needed
        trace_log "Setting numeric value" "DEBUG"
        jq ".state.$key = $value" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    elif [[ "$value" == "true" || "$value" == "false" ]]; then
        # Boolean value - no quotes needed
        trace_log "Setting boolean value" "DEBUG"
        jq ".state.$key = $value" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    else
        # String value - needs quotes
        trace_log "Setting string value" "DEBUG"
        jq ".state.$key = \"$value\"" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "set_state_value" "0" "State value updated" "$duration"
}

# Get last container name from state
# Retrieves the name of the last container that was operated on.
# Useful for operations that don't specify a container name.
#
# Input: None
# Output: Last container name or empty string
# Example: get_last_container
get_last_container() {
    get_state_value "last_container" ""
}

# Set last container name in state
# Updates the last container name and adds it to the container history.
# This tracks which containers have been used recently.
#
# Input:
#   $1 - container_name: The name of the container to set as last
# Output: None
# Side effects: Updates state file and container history
# Example: set_last_container "my-container"
set_last_container() {
    local container_name="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "set_last_container" "container_name=$container_name" "Set last container"
    
    trace_state_operation "set" "last_container" "$container_name"
    set_state_value "last_container" "$container_name"
    
    # Add to container history for tracking recently used containers
    trace_log "Adding to container history" "DEBUG"
    add_to_container_history "$container_name"
    
    log_debug "STATE" "$container_name" "Set as last container"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "set_last_container" "0" "Last container set" "$duration"
}

# Get last operation from state
# Retrieves the name of the last operation that was performed.
# Useful for tracking operation sequences.
#
# Input: None
# Output: Last operation name or empty string
# Example: get_last_operation
get_last_operation() {
    get_state_value "last_operation" ""
}

# Set last operation in state
# Updates the last operation name in the state file.
#
# Input:
#   $1 - operation: The name of the operation to set as last
# Output: None
# Side effects: Updates state file
# Example: set_last_operation "START"
set_last_operation() {
    local operation="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "set_last_operation" "operation=$operation" "Set last operation"
    
    trace_state_operation "set" "last_operation" "$operation"
    set_state_value "last_operation" "$operation"
    log_debug "STATE" "" "Set last operation: $operation"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "set_last_operation" "0" "Last operation set" "$duration"
}

# Get last YAML file from state
# Retrieves the path of the last YAML file that was used.
# Useful for operations that need to reference the source YAML.
#
# Input: None
# Output: Last YAML file path or empty string
# Example: get_last_yaml_file
get_last_yaml_file() {
    get_state_value "last_yaml_file" ""
}

# Set last YAML file in state
# Updates the last YAML file path in the state file.
#
# Input:
#   $1 - yaml_file: The path of the YAML file to set as last
# Output: None
# Side effects: Updates state file
# Example: set_last_yaml_file "/path/to/docker-compose.yml"
set_last_yaml_file() {
    local yaml_file="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "set_last_yaml_file" "yaml_file=$yaml_file" "Set last YAML file"
    
    trace_state_operation "set" "last_yaml_file" "$yaml_file"
    set_state_value "last_yaml_file" "$yaml_file"
    log_debug "STATE" "" "Set last YAML file: $yaml_file"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "set_last_yaml_file" "0" "Last YAML file set" "$duration"
}

# Add container to history
# Adds a container name to the beginning of the container history list.
# Removes duplicates and limits the history to the configured maximum size.
#
# Input:
#   $1 - container_name: The name of the container to add to history
# Output: None
# Side effects: Updates container history in state file
# Example: add_to_container_history "my-container"
add_to_container_history() {
    local container_name="$1"
    local max_history=$DOCKER_OPS_MAX_CONTAINER_HISTORY
    
    # Create state file if it doesn't exist
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        init_state_file
    fi
    
    # Get current history from state file
    local current_history=$(jq -r '.state.container_history[]' "$DOCKER_OPS_STATE_FILE" 2>/dev/null)
    
    # Remove the container if it already exists (to avoid duplicates)
    local new_history=$(echo "$current_history" | grep -v "^$container_name$" || true)
    
    # Add to beginning of list (most recent first)
    new_history="$container_name"$'\n'"$new_history"
    
    # Limit to maximum history size to prevent the list from growing too large
    new_history=$(echo "$new_history" | head -n "$max_history")
    
    # Convert to JSON array format and update the state file
    local json_array=$(echo "$new_history" | jq -R . | jq -s .)
    jq ".state.container_history = $json_array" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    
    log_debug "STATE" "$container_name" "Added to container history"
}

# Get container history
# Retrieves the list of recently used containers from the state file.
# Returns containers in order of most recent first.
#
# Input: None
# Output: List of container names (one per line)
# Example: get_container_history
get_container_history() {
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        jq -r '.state.container_history[]' "$DOCKER_OPS_STATE_FILE" 2>/dev/null
    fi
}

# Update container operation record
# Creates or updates a detailed record of an operation performed on a container.
# This includes operation type, timestamp, YAML source, container ID, and status.
#
# Input:
#   $1 - container_name: The name of the container
#   $2 - operation: The operation performed (e.g., "START", "STOP", "GENERATE")
#   $3 - yaml_source: Path to the YAML file used (optional)
#   $4 - container_id: Docker container ID (optional)
#   $5 - status: Current status of the container (optional)
# Output: None
# Side effects: Updates operations object in state file
# Example: update_container_operation "my-container" "START" "/path/to/compose.yml" "abc123" "running"
update_container_operation() {
    local container_name="$1"
    local operation="$2"
    local yaml_source="${3:-}"
    local container_id="${4:-}"
    local status="${5:-}"
    
    # Create state file if it doesn't exist
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        init_state_file
    fi
    
    # Generate ISO timestamp for the operation
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create operation record as JSON
    local operation_record=$(cat << EOF
{
    "last_operation": "$operation",
    "last_operation_time": "$timestamp",
    "yaml_source": "$yaml_source",
    "container_id": "$container_id",
    "status": "$status"
}
EOF
)
    
    # Update the operations object in the state file
    jq ".state.operations[\"$container_name\"] = $operation_record" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    
    log_debug "STATE" "$container_name" "Updated operation record: $operation"
}

# Get container operation record
# Retrieves the detailed operation record for a specific container.
# Returns the JSON record or empty string if not found.
#
# Input:
#   $1 - container_name: The name of the container
# Output: JSON operation record or empty string
# Example: get_container_operation_record "my-container"
get_container_operation_record() {
    local container_name="$1"
    
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        return 0
    fi
    
    # Extract the operation record for the specific container
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        jq -r ".state.operations[\"$container_name\"]" "$DOCKER_OPS_STATE_FILE" 2>/dev/null
    fi
}

# Remove container from state
# Completely removes a container from the state file, including its operation record
# and history entry. Used when containers are deleted or cleaned up.
#
# Input:
#   $1 - container_name: The name of the container to remove
# Output: None
# Side effects: Removes container from state file
# Example: remove_container_from_state "my-container"
remove_container_from_state() {
    local container_name="$1"
    
    # Check if state file exists
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        return 0
    fi
    
    # Remove from operations object
    jq "del(.state.operations[\"$container_name\"])" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    
    # Remove from container history
    local current_history=$(jq -r '.state.container_history[]' "$DOCKER_OPS_STATE_FILE" 2>/dev/null)
    local new_history=$(echo "$current_history" | grep -v "^$container_name$" || true)
    local json_array=$(echo "$new_history" | jq -R . | jq -s .)
    jq ".state.container_history = $json_array" "$DOCKER_OPS_STATE_FILE" > "${DOCKER_OPS_STATE_FILE}.tmp" && mv "${DOCKER_OPS_STATE_FILE}.tmp" "$DOCKER_OPS_STATE_FILE"
    
    # Clear last container if it was this one
    if [[ "$(get_last_container)" == "$container_name" ]]; then
        set_last_container ""
    fi
    
    log_info "STATE" "$container_name" "Removed from state"
}

# Get container status from state
# Retrieves the stored status of a container from the state file.
# This is the status that was recorded during the last operation.
#
# Input:
#   $1 - container_name: The name of the container
# Output: Container status or empty string
# Example: get_container_status_from_state "my-container"
get_container_status_from_state() {
    local container_name="$1"
    local operation_record=$(get_container_operation_record "$container_name")
    
    if [[ -n "$operation_record" ]]; then
        echo "$operation_record" | jq -r '.status' 2>/dev/null
    fi
}

# Update container status in state
# Updates the status of a container in the state file while preserving other
# operation record information.
#
# Input:
#   $1 - container_name: The name of the container
#   $2 - status: The new status to set
#   $3 - container_id: The container ID (optional)
# Output: None
# Side effects: Updates container status in state file
# Example: update_container_status "my-container" "running" "abc123"
update_container_status() {
    local container_name="$1"
    local status="$2"
    local container_id="${3:-}"
    
    # Get existing operation record to preserve other fields
    local operation_record=$(get_container_operation_record "$container_name")
    if [[ -n "$operation_record" ]]; then
        local last_operation=$(echo "$operation_record" | jq -r '.last_operation')
        local last_operation_time=$(echo "$operation_record" | jq -r '.last_operation_time')
        local yaml_source=$(echo "$operation_record" | jq -r '.yaml_source')
        
        # Update the operation record with new status
        update_container_operation "$container_name" "$last_operation" "$yaml_source" "$container_id" "$status"
    fi
}

# List all containers in state
# Retrieves a list of all containers that are currently tracked in the state file.
# These are containers that have been operated on by this tool.
#
# Input: None
# Output: List of container names (one per line)
# Example: list_containers_in_state
list_containers_in_state() {
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        return 0
    fi
    
    # Extract all container names from the operations object
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        jq -r '.state.operations | keys[]' "$DOCKER_OPS_STATE_FILE" 2>/dev/null
    fi
}

# Get state summary
# Displays a comprehensive summary of the current state including last operations,
# container history, and managed containers. Useful for debugging and monitoring.
#
# Input: None
# Output: Formatted state summary
# Example: get_state_summary
get_state_summary() {
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        echo "No state file configured"
        return 1
    fi
    
    # Check if state file exists
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        echo "No state file found"
        return 1
    fi
    
    # Display formatted summary
    echo "=== Docker Ops Manager State Summary ==="
    echo "Last Container: $(get_last_container)"
    echo "Last Operation: $(get_last_operation)"
    echo "Last YAML File: $(get_last_yaml_file)"
    echo ""
    echo "Container History:"
    get_container_history | nl
    echo ""
    echo "Managed Containers:"
    list_containers_in_state | while read -r container; do
        local status=$(get_container_status_from_state "$container")
        echo "  - $container ($status)"
    done
    echo "========================================"
}

# Clear state
# Completely removes the state file, effectively resetting all state information.
# Use with caution as this will lose all container history and operation records.
#
# Input: None
# Output: None
# Side effects: Deletes state file
# Example: clear_state
clear_state() {
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        rm -f "$DOCKER_OPS_STATE_FILE"
        log_info "STATE" "" "State file cleared"
    fi
}

# Backup state
# Creates a backup copy of the current state file with a timestamp.
# Useful for preserving state before major operations or updates.
#
# Input: None
# Output: Path to backup file or empty string if no state file exists
# Example: backup_state
backup_state() {
    local backup_file="${DOCKER_OPS_STATE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$DOCKER_OPS_STATE_FILE" ]]; then
        cp "$DOCKER_OPS_STATE_FILE" "$backup_file"
        log_info "STATE" "" "State backed up to: $backup_file"
        echo "$backup_file"
    else
        log_warn "STATE" "" "No state file to backup"
        return 1
    fi
}

# Restore state
# Restores the state file from a backup file.
# Useful for recovering from state corruption or reverting changes.
#
# Input:
#   $1 - backup_file: Path to the backup file to restore from
# Output: None
# Side effects: Replaces current state file with backup
# Example: restore_state "/path/to/backup.json"
restore_state() {
    local backup_file="$1"
    
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$DOCKER_OPS_STATE_FILE"
        log_info "STATE" "" "State restored from: $backup_file"
    else
        log_error "STATE" "" "Backup file not found: $backup_file"
        return 1
    fi
}

# Sync state with actual Docker container status
# Compares the stored state with actual Docker container status and updates
# the state file to reflect the current reality. This helps keep state in sync
# when containers are modified outside of this tool.
#
# Input: None
# Output: None
# Side effects: Updates container statuses in state file
# Example: sync_state_with_docker
sync_state_with_docker() {
    log_debug "STATE" "" "Syncing state with Docker container status"
    
    # Get list of containers tracked in state
    local containers_in_state=$(list_containers_in_state)
    
    if [[ -z "$containers_in_state" ]]; then
        log_debug "STATE" "" "No containers in state to sync"
        return 0
    fi
    
    # Update each container's status based on actual Docker state
    while IFS= read -r container_name; do
        if [[ -n "$container_name" ]]; then
            log_debug "STATE" "$container_name" "Checking Docker status"
            
            # Get current Docker status
            local container_status=""
            local container_id=""
            
            # Try to find the container by name (check both service name and full container name)
            local container_info=""
            if docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.ID}}" | grep -q "$container_name"; then
                container_info=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.ID}}" | grep "$container_name" | head -1)
            elif docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.ID}}" | grep -q "docker-ops-.*-$container_name"; then
                container_info=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.ID}}" | grep "docker-ops-.*-$container_name" | head -1)
            fi
            
            if [[ -n "$container_info" ]]; then
                # Parse the container info - status is everything between name and ID
                local container_name_full=$(echo "$container_info" | awk '{print $1}')
                container_id=$(echo "$container_info" | awk '{print $NF}')  # Last field is the ID
                local container_status_raw=$(echo "$container_info" | awk '{$1=""; $NF=""; print $0}' | sed 's/^ *//;s/ *$//')
                
                # Convert Docker status to our status format
                if echo "$container_status_raw" | grep -q "Up"; then
                    container_status="running"
                elif echo "$container_status_raw" | grep -q "Exited"; then
                    container_status="exited"
                elif echo "$container_status_raw" | grep -q "Created"; then
                    container_status="created"
                else
                    container_status="unknown"
                fi
                
                log_debug "STATE" "$container_name" "Docker status: $container_status (ID: $container_id)"
                
                # Update the state with current Docker status
                update_container_status "$container_name" "$container_status" "$container_id"
            else
                log_debug "STATE" "$container_name" "Container not found in Docker, marking as removed"
                update_container_status "$container_name" "removed" ""
            fi
        fi
    done <<< "$containers_in_state"
    
    log_info "STATE" "" "State synchronized with Docker container status"
} 

# Force sync state with Docker after cleanup operations
# This function is specifically designed to be called after cleanup operations
# to ensure the state file accurately reflects the current Docker state.
# It removes any containers from state that no longer exist in Docker.
#
# Input: None
# Output: None
# Side effects: Updates state file to match actual Docker state
# Example: force_sync_state_after_cleanup
force_sync_state_after_cleanup() {
    log_debug "STATE" "" "Force syncing state after cleanup operation"
    
    # Check if state file path is configured
    if [[ -z "${DOCKER_OPS_STATE_FILE:-}" ]]; then
        log_debug "STATE" "" "No state file path configured, skipping sync"
        return 0
    fi
    
    # Check if state file exists
    if [[ ! -f "$DOCKER_OPS_STATE_FILE" ]]; then
        log_debug "STATE" "" "No state file exists, cleanup was successful"
        return 0
    fi
    
    # Get list of containers tracked in state
    local containers_in_state=$(list_containers_in_state)
    
    if [[ -z "$containers_in_state" ]]; then
        log_debug "STATE" "" "No containers in state to sync"
        return 0
    fi
    
    # Check each container in state against actual Docker containers
    local containers_to_remove=()
    while IFS= read -r container_name; do
        if [[ -n "$container_name" ]]; then
            log_debug "STATE" "$container_name" "Checking if container still exists in Docker"
            
            # Check if container actually exists in Docker
            if ! docker ps -a --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
                # Container doesn't exist in Docker, mark for removal from state
                containers_to_remove+=("$container_name")
                log_debug "STATE" "$container_name" "Container no longer exists in Docker, marking for state removal"
            fi
        fi
    done <<< "$containers_in_state"
    
    # Remove containers that no longer exist in Docker from state
    for container_name in "${containers_to_remove[@]}"; do
        log_info "STATE" "$container_name" "Removing from state (no longer exists in Docker)"
        remove_container_from_state "$container_name"
    done
    
    if [[ ${#containers_to_remove[@]} -gt 0 ]]; then
        log_info "STATE" "" "Removed ${#containers_to_remove[@]} containers from state after cleanup"
    else
        log_debug "STATE" "" "All containers in state still exist in Docker"
    fi
} 