#!/usr/bin/env bash

# Start Operation Module
# Handles container starting operations

# =============================================================================
# FUNCTION: start_container_operation
# =============================================================================
# Purpose: Start a Docker container with comprehensive error handling and status checking
# Inputs: 
#   $1 - container_name: Name of the container to start
# Outputs: None
# Side Effects: 
#   - Starts the specified container
#   - Waits for container readiness
#   - Updates state with new container status
#   - Displays container status information
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "start" operation is requested
# Example: start_container_operation "my-app"
# =============================================================================
start_container_operation() {
    local container_name="$1"
    local operation="START"
    
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        print_info "Use 'list' to see available containers or 'generate' to create a new one"
        return 1
    fi
    
    # Check if container is already running
    if container_is_running "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container is already running"
        print_success "Container '$container_name' is already running"
        
        # Show container status
        show_container_status "$container_name"
        return 0
    fi
    
    # Start the container
    if start_container "$container_name"; then
        # Update state with new status
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "running" "$container_id"
        
        print_success "Container '$container_name' started successfully"
        
        # Wait for container to be ready
        print_info "Waiting for container to be ready..."
        if wait_for_container_ready "$container_name" "$TIMEOUT" ""; then
            print_success "Container '$container_name' is ready"
        else
            print_warning "Container '$container_name' may not be fully ready yet"
        fi
        
        # Show container status
        show_container_status "$container_name"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to start container"
        print_error "Failed to start container '$container_name'"
        return 1
    fi
}

# =============================================================================
# FUNCTION: start_multiple_containers
# =============================================================================
# Purpose: Start multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names to start
# Outputs: None
# Side Effects: 
#   - Starts each container in the provided list
#   - Provides summary of start results
#   - Continues starting containers even if some fail
# Return code: 0 if successful, 1 if failed
# Usage: Called to start multiple containers at once
# Example: start_multiple_containers "web" "db" "cache"
# =============================================================================
start_multiple_containers() {
    local containers=("$@")
    local operation="START_MULTIPLE"
    
    log_operation_start "$operation" "" "Starting multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    local success_count=0
    local total_count=${#containers[@]}
    
    print_info "Starting $total_count containers..."
    
    for container_name in "${containers[@]}"; do
        print_info "Starting container: $container_name"
        
        if start_container_operation "$container_name"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers started successfully"
        print_success "All $total_count containers started successfully"
    else
        log_operation_failure "$operation" "" "Started $success_count out of $total_count containers"
        print_warning "Started $success_count out of $total_count containers"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: start_all_managed_containers
# =============================================================================
# Purpose: Start all containers that are managed by this tool
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Retrieves all managed containers from state
#   - Starts all containers found in state
#   - Provides summary of start results
# Return code: 0 if successful, 1 if failed
# Usage: Called to start all containers managed by the tool
# Example: start_all_managed_containers
# =============================================================================
start_all_managed_containers() {
    local operation="START_ALL"
    
    log_operation_start "$operation" "" "Starting all managed containers"
    
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
    
    # Start all containers
    start_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: start_containers_from_yaml
# =============================================================================
# Purpose: Start containers based on a YAML configuration file
# Inputs: 
#   $1 - yaml_file: Path to the YAML configuration file
# Outputs: None
# Side Effects: 
#   - Validates and parses YAML file
#   - Extracts container names from YAML
#   - Starts all containers found in YAML
# Return code: 0 if successful, 1 if failed
# Usage: Called to start containers defined in a YAML file
# Example: start_containers_from_yaml "docker-compose.yml"
# =============================================================================
start_containers_from_yaml() {
    local yaml_file="$1"
    local operation="START_FROM_YAML"
    
    log_operation_start "$operation" "" "Starting containers from YAML file"
    
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
    
    # Start containers
    start_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: start_container_with_dependencies
# =============================================================================
# Purpose: Start a container and its dependencies in the correct order
# Inputs: 
#   $1 - container_name: Name of the container to start
# Outputs: None
# Side Effects: 
#   - Identifies container dependencies
#   - Starts dependencies first
#   - Starts the main container after dependencies are ready
# Return code: 0 if successful, 1 if failed
# Usage: Called when container has dependencies that need to be started first
# Example: start_container_with_dependencies "web"
# =============================================================================
start_container_with_dependencies() {
    local container_name="$1"
    local operation="START_WITH_DEPS"
    
    log_operation_start "$operation" "$container_name" "Starting container with dependencies"
    
    # Get container dependencies from state
    local dependencies=$(get_container_dependencies "$container_name")
    
    if [[ -n "$dependencies" ]]; then
        print_info "Starting dependencies for '$container_name'..."
        
        local dep_array=()
        while IFS= read -r dep; do
            if [[ -n "$dep" ]]; then
                dep_array+=("$dep")
            fi
        done <<< "$dependencies"
        
        # Start dependencies first
        for dep in "${dep_array[@]}"; do
            print_info "Starting dependency: $dep"
            if ! start_container_operation "$dep"; then
                log_operation_failure "$operation" "$container_name" "Failed to start dependency: $dep"
                print_error "Failed to start dependency: $dep"
                return 1
            fi
        done
        
        # Wait a bit for dependencies to be ready
        sleep 5
    fi
    
    # Start the main container
    start_container_operation "$container_name"
}

# =============================================================================
# FUNCTION: get_container_dependencies
# =============================================================================
# Purpose: Get the list of dependencies for a container
# Inputs: 
#   $1 - container_name: Name of the container to get dependencies for
# Outputs: List of dependency container names (one per line)
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called by start_container_with_dependencies to determine startup order
# Example: get_container_dependencies "web"
# Note: This is a placeholder function that can be extended for real dependency management
# =============================================================================
get_container_dependencies() {
    local container_name="$1"
    
    # This is a placeholder function
    # In a real implementation, you might:
    # - Read dependencies from YAML configuration
    # - Check container links/networks
    # - Query a dependency database
    
    # For now, return empty (no dependencies)
    echo ""
}

# =============================================================================
# FUNCTION: start_container_background
# =============================================================================
# Purpose: Start a container in the background without waiting for readiness
# Inputs: 
#   $1 - container_name: Name of the container to start
# Outputs: None
# Side Effects: 
#   - Starts the container without waiting for readiness
#   - Returns immediately after start command
# Return code: 0 if successful, 1 if failed
# Usage: Called when immediate return is needed after starting container
# Example: start_container_background "my-app"
# =============================================================================
start_container_background() {
    local container_name="$1"
    local operation="START_BACKGROUND"
    
    log_operation_start "$operation" "$container_name" "Starting container in background"
    
    # Start container without waiting
    if start_container "$container_name"; then
        print_success "Container '$container_name' started in background"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to start container in background"
        print_error "Failed to start container '$container_name' in background"
        return 1
    fi
}

# =============================================================================
# FUNCTION: start_container_with_options
# =============================================================================
# Purpose: Start a container with custom options like restart policy, resource limits
# Inputs: 
#   $1 - container_name: Name of the container to start
#   $2 - options: Custom options string (e.g., "restart=always,memory=512m")
# Outputs: None
# Side Effects: 
#   - Applies custom options to container
#   - Starts the container with modified configuration
# Return code: 0 if successful, 1 if failed
# Usage: Called when custom container options need to be applied
# Example: start_container_with_options "my-app" "restart=always,memory=512m"
# =============================================================================
start_container_with_options() {
    local container_name="$1"
    local options="$2"
    local operation="START_CUSTOM"
    
    log_operation_start "$operation" "$container_name" "Starting container with custom options"
    
    # Parse options (simplified - can be extended)
    local restart_policy=""
    local memory_limit=""
    local cpu_limit=""
    
    # Extract options (example parsing)
    if [[ "$options" == *"restart=always"* ]]; then
        restart_policy="always"
    fi
    
    # Start container with options
    local command="docker start $container_name"
    
    if [[ -n "$restart_policy" ]]; then
        command="docker update --restart=$restart_policy $container_name && $command"
    fi
    
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Container '$container_name' started with custom options"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to start container with custom options"
        print_error "Failed to start container '$container_name' with custom options"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: show_container_status
# =============================================================================
# Purpose: Display detailed status information for a container
# Inputs: 
#   $1 - container_name: Name of the container to show status for
# Outputs: Formatted container status information to stdout
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called after container operations to show current status
# Example: show_container_status "my-app"
# =============================================================================
show_container_status() {
    local container_name="$1"
    
    echo
    print_section "Container Status"
    
    # Get container status
    local status=$(get_container_status "$container_name")
    local container_id=$(get_container_id "$container_name")
    local image=$(get_container_image "$container_name")
    
    echo "Name: $container_name"
    echo "ID: $container_id"
    echo "Image: $image"
    echo "Status: $status"
    
    # Show ports if running
    if [[ "$status" == "running" ]]; then
        local ports=$(docker port "$container_name" 2>/dev/null || echo "No ports exposed")
        echo "Ports: $ports"
        
        # Show basic stats
        local stats=$(get_container_stats "$container_name" 2>/dev/null || echo "Stats unavailable")
        if [[ "$stats" != "Stats unavailable" ]]; then
            echo
            echo "Resource Usage:"
            echo "$stats"
        fi
    fi
    
    echo
} 