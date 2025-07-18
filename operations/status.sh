#!/usr/bin/env bash

# Status Operation Module
# Handles container status display

# =============================================================================
# FUNCTION: show_container_status
# =============================================================================
# Purpose: Display comprehensive status information for a specific container
# Inputs: 
#   $1 - container_name: Name of the container to show status for
# Outputs: Detailed container status information to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves container information from Docker and state
#   - Displays formatted status information
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "status" operation is requested
# Example: show_container_status "my-app"
# =============================================================================
show_container_status() {
    local container_arg="$1"
    local container_name="$container_arg"
    local operation="STATUS"

    # If the argument is a YAML file, resolve the actual container name
    if [[ "$container_arg" == *.yml || "$container_arg" == *.yaml ]]; then
        # Extract the first service name from the YAML file
        local service_name=$(yq eval '.services | keys | .[0]' "$container_arg" 2>/dev/null)
        if [[ -z "$service_name" ]]; then
            # Fallback: try to grep the first service name
            service_name=$(grep -A 1 'services:' "$container_arg" | grep ':' | head -2 | tail -1 | sed 's/^[[:space:]]*//;s/://')
        fi
        if [[ -n "$service_name" ]]; then
            container_name=$(resolve_container_name "$container_arg" "$service_name")
        fi
    fi

    log_operation_start "$operation" "$container_name" "Showing container status"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get container information
    local status=$(get_container_status "$container_name")
    local container_id=$(get_container_id "$container_name")
    local image=$(get_container_image "$container_name")
    local created=$(docker inspect --format='{{.Created}}' "$container_name" 2>/dev/null)
    local ports=$(docker port "$container_name" 2>/dev/null || echo "No ports exposed")
    
    # Get state information
    local state_status=$(get_container_status_from_state "$container_name")
    local operation_record=$(get_container_operation_record "$container_name")
    local last_operation=""
    local last_operation_time=""
    local yaml_source=""
    
    if [[ -n "$operation_record" ]]; then
        last_operation=$(echo "$operation_record" | jq -r '.last_operation')
        last_operation_time=$(echo "$operation_record" | jq -r '.last_operation_time')
        yaml_source=$(echo "$operation_record" | jq -r '.yaml_source')
    fi
    
    # Display status
    print_header "Container Status: $container_name"
    
    echo "Basic Information:"
    echo "  Name: $container_name"
    echo "  ID: $container_id"
    echo "  Image: $image"
    echo "  Status: $status"
    echo "  Created: $created"
    
    if [[ "$status" == "running" ]]; then
        echo "  Ports: $ports"
        
        # Show resource usage
        local stats=$(get_container_stats "$container_name" 2>/dev/null)
        if [[ -n "$stats" && "$stats" != "Stats unavailable" ]]; then
            echo
            echo "Resource Usage:"
            echo "$stats"
        fi
        
        # Show health status if available
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
        if [[ -n "$health_status" && "$health_status" != "<nil>" ]]; then
            echo "  Health: $health_status"
        fi
    fi
    
    echo
    echo "State Information:"
    echo "  State Status: ${state_status:-unknown}"
    echo "  Last Operation: ${last_operation:-none}"
    echo "  Last Operation Time: ${last_operation_time:-none}"
    if [[ -n "$yaml_source" && "$yaml_source" != "null" ]]; then
        echo "  YAML Source: $yaml_source"
    fi
    
    # Show recent logs if running
    if [[ "$status" == "running" ]]; then
        echo
        echo "Recent Logs (last 10 lines):"
        local logs=$(get_container_logs "$container_name" 10 2>/dev/null)
        if [[ -n "$logs" ]]; then
            echo "$logs"
        else
            echo "  No logs available"
        fi
    fi
    
    echo
    log_operation_success "$operation" "$container_name" "Status displayed successfully"
}

# =============================================================================
# FUNCTION: show_all_containers_status
# =============================================================================
# Purpose: Display status overview for all containers on the system
# Inputs: None
# Outputs: Status summary for all containers to stdout
# Side Effects: 
#   - Retrieves all containers from Docker
#   - Displays formatted status overview
#   - Provides summary statistics
# Return code: 0 if successful, 1 if failed
# Usage: Called when overview of all containers is needed
# Example: show_all_containers_status
# =============================================================================
show_all_containers_status() {
    local operation="STATUS_ALL"
    
    log_operation_start "$operation" "" "Showing status for all containers"
    
    # Get all containers
    local all_containers=$(docker ps -a --format "{{.Names}}" 2>/dev/null)
    if [[ -z "$all_containers" ]]; then
        print_info "No containers found"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$all_containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No containers found"
        return 0
    fi
    
    print_header "All Containers Status"
    
    local running_count=0
    local stopped_count=0
    
    for container_name in "${container_array[@]}"; do
        local status=$(get_container_status "$container_name")
        local image=$(get_container_image "$container_name")
        
        if [[ "$status" == "running" ]]; then
            print_green "✓ $container_name ($image) - $status"
            running_count=$((running_count + 1))
        else
            print_red "✗ $container_name ($image) - $status"
            stopped_count=$((stopped_count + 1))
        fi
    done
    
    echo
    echo "Summary:"
    echo "  Running: $running_count"
    echo "  Stopped: $stopped_count"
    echo "  Total: ${#container_array[@]}"
    
    log_operation_success "$operation" "" "Status for all containers displayed"
}

# =============================================================================
# FUNCTION: show_managed_containers_status
# =============================================================================
# Purpose: Display status overview for containers managed by this tool
# Inputs: None
# Outputs: Status summary for managed containers to stdout
# Side Effects: 
#   - Retrieves managed containers from state
#   - Displays formatted status overview
#   - Provides summary statistics
# Return code: 0 if successful, 1 if failed
# Usage: Called when overview of managed containers is needed
# Example: show_managed_containers_status
# =============================================================================
show_managed_containers_status() {
    local operation="STATUS_MANAGED"
    
    log_operation_start "$operation" "" "Showing status for managed containers"
    
    # Get managed containers from state
    local managed_containers=$(list_containers_in_state)
    if [[ -z "$managed_containers" ]]; then
        print_info "No managed containers found"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$managed_containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No managed containers found"
        return 0
    fi
    
    print_header "Managed Containers Status"
    
    local running_count=0
    local stopped_count=0
    local not_found_count=0
    
    for container_name in "${container_array[@]}"; do
        local status=$(get_container_status "$container_name")
        local image=$(get_container_image "$container_name")
        local state_status=$(get_container_status_from_state "$container_name")
        
        case "$status" in
            "running")
                print_green "✓ $container_name ($image) - $status"
                running_count=$((running_count + 1))
                ;;
            "stopped")
                print_yellow "○ $container_name ($image) - $status"
                stopped_count=$((stopped_count + 1))
                ;;
            "not_found")
                print_red "✗ $container_name - not found"
                not_found_count=$((not_found_count + 1))
                ;;
            *)
                print_blue "? $container_name - $status"
                ;;
        esac
    done
    
    echo
    echo "Summary:"
    echo "  Running: $running_count"
    echo "  Stopped: $stopped_count"
    echo "  Not Found: $not_found_count"
    echo "  Total: ${#container_array[@]}"
    
    log_operation_success "$operation" "" "Status for managed containers displayed"
}

# =============================================================================
# FUNCTION: show_detailed_status_table
# =============================================================================
# Purpose: Display detailed status information in tabular format
# Inputs: None
# Outputs: Tabular container status information to stdout
# Side Effects: 
#   - Retrieves all containers with detailed information
#   - Displays formatted table with container details
# Return code: 0 if successful, 1 if failed
# Usage: Called when detailed tabular status is needed
# Example: show_detailed_status_table
# =============================================================================
show_detailed_status_table() {
    local operation="STATUS_TABLE"
    
    log_operation_start "$operation" "" "Showing detailed status table"
    
    # Get all containers with detailed information
    local detailed_info=$(docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Size}}" 2>/dev/null)
    
    if [[ -z "$detailed_info" ]]; then
        print_info "No containers found"
        return 0
    fi
    
    print_header "Detailed Container Status"
    echo "$detailed_info"
    
    log_operation_success "$operation" "" "Detailed status table displayed"
}

# =============================================================================
# FUNCTION: show_container_health
# =============================================================================
# Purpose: Display health check status and details for a container
# Inputs: 
#   $1 - container_name: Name of the container to show health for
# Outputs: Health status and configuration to stdout
# Side Effects: 
#   - Validates container existence and running status
#   - Retrieves health check information from Docker
#   - Displays health status and configuration
# Return code: 0 if successful, 1 if failed
# Usage: Called when container health information is needed
# Example: show_container_health "my-app"
# =============================================================================
show_container_health() {
    local container_name="$1"
    local operation="HEALTH"
    
    log_operation_start "$operation" "$container_name" "Showing container health status"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Check if container is running
    if ! container_is_running "$container_name"; then
        print_warning "Container '$container_name' is not running"
        return 0
    fi
    
    # Get health status
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
    
    if [[ -z "$health_status" || "$health_status" == "<nil>" ]]; then
        print_info "Container '$container_name' has no health check configured"
        return 0
    fi
    
    echo "Health Status: $health_status"
    
    # Get health check details
    local health_logs=$(docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$container_name" 2>/dev/null)
    if [[ -n "$health_logs" ]]; then
        echo
        echo "Health Check Logs:"
        echo "$health_logs"
    fi
    
    # Get health check configuration
    local health_config=$(docker inspect --format='{{json .Config.Healthcheck}}' "$container_name" 2>/dev/null)
    if [[ -n "$health_config" && "$health_config" != "null" ]]; then
        echo
        echo "Health Check Configuration:"
        echo "$health_config" | jq '.'
    fi
    
    log_operation_success "$operation" "$container_name" "Health status displayed"
}

# =============================================================================
# FUNCTION: show_container_resources
# =============================================================================
# Purpose: Display resource usage statistics for a container
# Inputs: 
#   $1 - container_name: Name of the container to show resources for
# Outputs: Resource usage statistics to stdout
# Side Effects: 
#   - Validates container existence and running status
#   - Retrieves resource statistics from Docker
#   - Displays formatted resource information
# Return code: 0 if successful, 1 if failed
# Usage: Called when container resource monitoring is needed
# Example: show_container_resources "my-app"
# =============================================================================
show_container_resources() {
    local container_name="$1"
    local operation="RESOURCES"
    
    log_operation_start "$operation" "$container_name" "Showing container resource usage"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Check if container is running
    if ! container_is_running "$container_name"; then
        print_warning "Container '$container_name' is not running"
        return 0
    fi
    
    # Get resource usage
    local stats=$(get_container_stats "$container_name")
    if [[ -n "$stats" && "$stats" != "Stats unavailable" ]]; then
        print_header "Resource Usage: $container_name"
        echo "$stats"
    else
        print_error "Could not get resource usage for container '$container_name'"
        return 1
    fi
    
    log_operation_success "$operation" "$container_name" "Resource usage displayed"
}

# =============================================================================
# FUNCTION: show_container_network
# =============================================================================
# Purpose: Display network configuration and information for a container
# Inputs: 
#   $1 - container_name: Name of the container to show network info for
# Outputs: Network configuration information to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves network settings from Docker
#   - Displays formatted network information
# Return code: 0 if successful, 1 if failed
# Usage: Called when container network configuration is needed
# Example: show_container_network "my-app"
# =============================================================================
show_container_network() {
    local container_name="$1"
    local operation="NETWORK"
    
    log_operation_start "$operation" "$container_name" "Showing container network information"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get network information
    local network_info=$(docker inspect --format='{{json .NetworkSettings}}' "$container_name" 2>/dev/null)
    
    if [[ -n "$network_info" && "$network_info" != "null" ]]; then
        print_header "Network Information: $container_name"
        echo "$network_info" | jq '.'
    else
        print_error "Could not get network information for container '$container_name'"
        return 1
    fi
    
    log_operation_success "$operation" "$container_name" "Network information displayed"
}

# =============================================================================
# FUNCTION: show_container_volumes
# =============================================================================
# Purpose: Display volume mount information for a container
# Inputs: 
#   $1 - container_name: Name of the container to show volumes for
# Outputs: Volume mount information to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves volume mount information from Docker
#   - Displays formatted volume information
# Return code: 0 if successful, 1 if failed
# Usage: Called when container volume configuration is needed
# Example: show_container_volumes "my-app"
# =============================================================================
show_container_volumes() {
    local container_name="$1"
    local operation="VOLUMES"
    
    log_operation_start "$operation" "$container_name" "Showing container volume information"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get volume information
    local volume_info=$(docker inspect --format='{{json .Mounts}}' "$container_name" 2>/dev/null)
    
    if [[ -n "$volume_info" && "$volume_info" != "null" ]]; then
        print_header "Volume Information: $container_name"
        echo "$volume_info" | jq '.'
    else
        print_info "Container '$container_name' has no volumes mounted"
    fi
    
    log_operation_success "$operation" "$container_name" "Volume information displayed"
} 