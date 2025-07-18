#!/usr/bin/env bash

# Stop Operation Module
# Handles container stopping operations

# =============================================================================
# FUNCTION: stop_container_operation
# =============================================================================
# Purpose: Stop a Docker container with comprehensive error handling
# Inputs: 
#   $1 - container_name: Name of the container to stop
# Outputs: None
# Side Effects: 
#   - Validates container existence
#   - Stops the container if running
#   - Updates state with new container status
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "stop" operation is requested
# Example: stop_container_operation "my-app"
# =============================================================================
stop_container_operation() {
    local container_name="$1"
    local operation="STOP"
    
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Check if container is already stopped
    if ! container_is_running "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container is already stopped"
        print_success "Container '$container_name' is already stopped"
        return 0
    fi
    
    # Stop the container
    if stop_container "$container_name"; then
        # Update state with new status
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "exited" "$container_id"
        
        print_success "Container '$container_name' stopped successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to stop container"
        print_error "Failed to stop container '$container_name'"
        return 1
    fi
}

# =============================================================================
# FUNCTION: stop_multiple_containers
# =============================================================================
# Purpose: Stop multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names to stop
# Outputs: None
# Side Effects: 
#   - Stops each container in the provided list
#   - Provides summary of stop results
#   - Continues stopping containers even if some fail
# Return code: 0 if successful, 1 if failed
# Usage: Called to stop multiple containers at once
# Example: stop_multiple_containers "web" "db" "cache"
# =============================================================================
stop_multiple_containers() {
    local containers=("$@")
    local operation="STOP_MULTIPLE"
    
    log_operation_start "$operation" "" "Stopping multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    local success_count=0
    local total_count=${#containers[@]}
    
    print_info "Stopping $total_count containers..."
    
    for container_name in "${containers[@]}"; do
        print_info "Stopping container: $container_name"
        
        if stop_container_operation "$container_name"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers stopped successfully"
        print_success "All $total_count containers stopped successfully"
    else
        log_operation_failure "$operation" "" "Stopped $success_count out of $total_count containers"
        print_warning "Stopped $success_count out of $total_count containers"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: stop_all_running_containers
# =============================================================================
# Purpose: Stop all running containers on the system
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Retrieves all running containers from Docker
#   - Stops all running containers
#   - Provides summary of stop results
# Return code: 0 if successful, 1 if failed
# Usage: Called to stop all running containers on the system
# Example: stop_all_running_containers
# =============================================================================
stop_all_running_containers() {
    local operation="STOP_ALL"
    
    log_operation_start "$operation" "" "Stopping all running containers"
    
    # Get all running containers
    local running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [[ -z "$running_containers" ]]; then
        print_info "No running containers found"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$running_containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No running containers found"
        return 0
    fi
    
    print_info "Found ${#container_array[@]} running containers"
    
    # Stop all containers
    stop_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: stop_all_managed_containers
# =============================================================================
# Purpose: Stop all containers managed by this tool
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Retrieves all managed containers from state
#   - Stops all managed containers
#   - Provides summary of stop results
# Return code: 0 if successful, 1 if failed
# Usage: Called to stop all containers managed by the tool
# Example: stop_all_managed_containers
# =============================================================================
stop_all_managed_containers() {
    local operation="STOP_MANAGED"
    
    log_operation_start "$operation" "" "Stopping all managed containers"
    
    # Get all containers from state
    local containers=$(list_containers_in_state)
    if [[ -z "$containers" ]]; then
        print_info "No managed containers found"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No managed containers found"
        return 0
    fi
    
    print_info "Found ${#container_array[@]} managed containers"
    
    # Stop all containers
    stop_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: stop_containers_from_yaml
# =============================================================================
# Purpose: Stop containers based on a YAML configuration file
# Inputs: 
#   $1 - yaml_file: Path to the YAML configuration file
# Outputs: None
# Side Effects: 
#   - Validates and parses YAML file
#   - Extracts container names from YAML
#   - Stops all containers found in YAML
# Return code: 0 if successful, 1 if failed
# Usage: Called to stop containers defined in a YAML file
# Example: stop_containers_from_yaml "docker-compose.yml"
# =============================================================================
stop_containers_from_yaml() {
    local yaml_file="$1"
    local operation="STOP_FROM_YAML"
    
    log_operation_start "$operation" "" "Stopping containers from YAML file"
    
    # Validate YAML file
    if ! validate_yaml_file "$yaml_file"; then
        log_operation_failure "$operation" "" "YAML file validation failed"
        return 1
    fi
    
    # Detect YAML type
    local yaml_type=$(detect_yaml_type "$yaml_file")
    log_info "$operation" "" "Detected YAML type: $yaml_type"
    
    # Extract container names
    local containers=$(extract_container_names "$yaml_file" "$yaml_type")
    if [[ -z "$containers" ]]; then
        log_operation_failure "$operation" "" "No containers found in YAML file"
        return 1
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$containers"
    
    print_info "Found ${#container_array[@]} containers in YAML file"
    
    # Stop containers
    stop_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: stop_container_with_dependencies
# =============================================================================
# Purpose: Stop a container and its dependencies in the correct order
# Inputs: 
#   $1 - container_name: Name of the container to stop
# Outputs: None
# Side Effects: 
#   - Stops the main container first
#   - Identifies and stops unused dependencies
#   - Preserves dependencies used by other containers
# Return code: 0 if successful, 1 if failed
# Usage: Called when container has dependencies that need to be stopped
# Example: stop_container_with_dependencies "web"
# =============================================================================
stop_container_with_dependencies() {
    local container_name="$1"
    local operation="STOP_WITH_DEPS"
    
    log_operation_start "$operation" "$container_name" "Stopping container with dependencies"
    
    # Get container dependencies from state
    local dependencies=$(get_container_dependencies "$container_name")
    
    # Stop the main container first
    if ! stop_container_operation "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Failed to stop main container"
        return 1
    fi
    
    # Stop dependencies if they're not used by other containers
    if [[ -n "$dependencies" ]]; then
        print_info "Checking dependencies for '$container_name'..."
        
        local dep_array=()
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                dep_array+=("$dep")
            fi
        done <<< "$dependencies"
        
        for dep in "${dep_array[@]}"; do
            # Check if dependency is used by other containers
            if ! is_container_used_by_others "$dep" "$container_name"; then
                print_info "Stopping unused dependency: $dep"
                stop_container_operation "$dep"
            else
                print_info "Keeping dependency '$dep' (used by other containers)"
            fi
        done
    fi
    
    log_operation_success "$operation" "$container_name" "Container and dependencies stopped"
    return 0
}

# =============================================================================
# FUNCTION: is_container_used_by_others
# =============================================================================
# Purpose: Check if a container is being used by other containers
# Inputs: 
#   $1 - container_name: Name of the container to check
#   $2 - exclude_container: Container name to exclude from the check
# Outputs: None
# Side Effects: None
# Return code: 0 if container is in use, 1 if not in use
# Usage: Called by stop_container_with_dependencies to determine if dependencies can be stopped
# Example: is_container_used_by_others "db" "web"
# Note: This is a simplified check that can be extended for more sophisticated dependency analysis
# =============================================================================
is_container_used_by_others() {
    local container_name="$1"
    local exclude_container="$2"
    
    # This is a simplified check
    # In a real implementation, you might check:
    # - Container links
    # - Network connections
    # - Volume dependencies
    
    # For now, just check if the container is running
    if container_is_running "$container_name"; then
        return 0  # Container is in use
    else
        return 1  # Container is not in use
    fi
}

# =============================================================================
# FUNCTION: force_stop_container
# =============================================================================
# Purpose: Force stop a container using docker kill (SIGKILL)
# Inputs: 
#   $1 - container_name: Name of the container to force stop
# Outputs: None
# Side Effects: 
#   - Immediately terminates the container process
#   - Updates state with new container status
#   - May cause data loss if container is writing
# Return code: 0 if successful, 1 if failed
# Usage: Called when graceful stop fails or immediate termination is needed
# Example: force_stop_container "my-app"
# Warning: This will immediately kill the container process
# =============================================================================
force_stop_container() {
    local container_name="$1"
    local operation="FORCE_STOP"
    
    log_operation_start "$operation" "$container_name" "Force stopping container"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Force stop the container
    local command="docker kill $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container force stopped successfully"
        print_success "Container '$container_name' force stopped successfully"
        
        # Update state
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "stopped" "$container_id"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to force stop container"
        print_error "Failed to force stop container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: stop_container_gracefully
# =============================================================================
# Purpose: Stop a container gracefully with configurable timeout
# Inputs: 
#   $1 - container_name: Name of the container to stop
#   $2 - timeout: Timeout in seconds for graceful stop (optional, defaults to 30)
# Outputs: None
# Side Effects: 
#   - Sends SIGTERM first for graceful shutdown
#   - Falls back to force stop if graceful stop fails
#   - Updates state with new container status
# Return code: 0 if successful, 1 if failed
# Usage: Called when graceful shutdown is preferred over force stop
# Example: stop_container_gracefully "my-app" 60
# =============================================================================
stop_container_gracefully() {
    local container_name="$1"
    local timeout="${2:-30}"
    local operation="STOP_GRACEFUL"
    
    log_operation_start "$operation" "$container_name" "Stopping container gracefully"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Check if container is already stopped
    if ! container_is_running "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container is already stopped"
        print_success "Container '$container_name' is already stopped"
        return 0
    fi
    
    # Send SIGTERM first
    local command="docker stop --time=$timeout $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container stopped gracefully"
        print_success "Container '$container_name' stopped gracefully"
        
        # Update state
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "stopped" "$container_id"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        return 0
    else
        # If graceful stop failed, try force stop
        log_warn "$operation" "$container_name" "Graceful stop failed, trying force stop"
        print_warning "Graceful stop failed, trying force stop..."
        
        force_stop_container "$container_name"
    fi
}

# =============================================================================
# FUNCTION: stop_containers_by_pattern
# =============================================================================
# Purpose: Stop containers that match a specific pattern
# Inputs: 
#   $1 - pattern: Pattern to match container names (regex or glob pattern)
# Outputs: None
# Side Effects: 
#   - Finds containers matching the pattern
#   - Stops all matching containers
#   - Provides summary of stop results
# Return code: 0 if successful, 1 if failed
# Usage: Called when stopping containers by name pattern
# Example: stop_containers_by_pattern "web-*"
# =============================================================================
stop_containers_by_pattern() {
    local pattern="$1"
    local operation="STOP_PATTERN"
    
    log_operation_start "$operation" "" "Stopping containers matching pattern: $pattern"
    
    # Find containers matching pattern
    local matching_containers=$(docker ps --format "{{.Names}}" | grep "$pattern" 2>/dev/null || true)
    
    if [[ -z "$matching_containers" ]]; then
        print_info "No containers found matching pattern: $pattern"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$matching_containers"
    
    print_info "Found ${#container_array[@]} containers matching pattern: $pattern"
    
    # Stop containers
    stop_multiple_containers "${container_array[@]}"
} 