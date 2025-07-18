#!/usr/bin/env bash

# Cleanup Operation Module
# Handles container and resource cleanup

# =============================================================================
# FUNCTION: cleanup_container
# =============================================================================
# Purpose: Clean up a specific container by stopping and removing it
# Inputs: 
#   $1 - container_name: Name of the container to cleanup
#   $2 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Stops the container if running
#   - Removes the container from Docker
#   - Removes container from state tracking
#   - Updates state to reflect the cleanup operation
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "cleanup" operation is requested
# Example: cleanup_container "my-app" true
# =============================================================================
cleanup_container() {
    local container_arg="$1"
    local force="${2:-false}"
    local container_name="$container_arg"
    local operation="CLEANUP"

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

    log_operation_start "$operation" "$container_name" "Cleaning up container"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container does not exist"
        print_info "Container '$container_name' does not exist"
        return 0
    fi
    
    # Stop container if running
    if container_is_running "$container_name"; then
        print_info "Stopping running container..."
        stop_container "$container_name"
    fi
    
    # Remove container
    print_info "Removing container..."
    remove_container "$container_name" "$force"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Remove from state after successful cleanup
        remove_container_from_state "$container_name"
        
        # Update state to reflect the cleanup operation
        set_last_operation "cleanup"
        set_last_container "$container_name"
        
        log_operation_success "$operation" "$container_name" "Container cleaned up successfully"
        print_success "Container '$container_name' cleaned up successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to cleanup container"
        print_error "Failed to cleanup container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: cleanup_multiple_containers
# =============================================================================
# Purpose: Clean up multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names and optional force flag
# Outputs: None
# Side Effects: 
#   - Cleans up each container in the provided list
#   - Provides summary of cleanup results
#   - Continues cleanup even if some containers fail
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup multiple containers at once
# Example: cleanup_multiple_containers "web" "db" "cache" true
# =============================================================================
cleanup_multiple_containers() {
    local containers=("$@")
    local force="${containers[-1]}"
    unset "containers[-1]"
    local operation="CLEANUP_MULTIPLE"
    
    log_operation_start "$operation" "" "Cleaning up multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    local success_count=0
    local total_count=${#containers[@]}
    
    print_info "Cleaning up $total_count containers..."
    
    for container_name in "${containers[@]}"; do
        print_info "Cleaning up container: $container_name"
        
        if cleanup_container "$container_name" "$force"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers cleaned up successfully"
        print_success "All $total_count containers cleaned up successfully"
    else
        log_operation_failure "$operation" "" "Cleaned up $success_count out of $total_count containers"
        print_warning "Cleaned up $success_count out of $total_count containers"
    fi
    
    # Force sync state to ensure consistency after multiple container cleanup
    force_sync_state_after_cleanup
    
    return 0
}

# =============================================================================
# FUNCTION: cleanup_state_managed_containers
# =============================================================================
# Purpose: Clean up all containers that are present in state.json
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves all managed containers from state
#   - Cleans up all managed containers
#   - Clears state after successful cleanup
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called when --all flag is passed to cleanup command
# Example: cleanup_state_managed_containers true
# =============================================================================
cleanup_state_managed_containers() {
    local force="${1:-false}"
    local operation="CLEANUP_STATE_MANAGED"
    
    log_operation_start "$operation" "" "Cleaning up all state-managed containers"
    
    # Get all containers from state
    local containers=$(list_containers_in_state)
    if [[ -z "$containers" ]]; then
        print_info "No managed containers found in state"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No managed containers found in state"
        return 0
    fi
    
    print_info "Found ${#container_array[@]} managed containers in state"
    
    local success_count=0
    local total_count=${#container_array[@]}
    
    for container_name in "${container_array[@]}"; do
        print_info "Cleaning up managed container: $container_name"
        
        if cleanup_container "$container_name" "$force"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count managed containers cleaned up successfully"
        print_success "All $total_count managed containers cleaned up successfully"
        
        # Clear state after successful cleanup of all managed containers
        clear_state
        print_info "State file cleared - all managed containers removed"
    else
        log_operation_failure "$operation" "" "Cleaned up $success_count out of $total_count managed containers"
        print_warning "Cleaned up $success_count out of $total_count managed containers"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: cleanup_all_managed_containers
# =============================================================================
# Purpose: Clean up all containers managed by this tool
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves all managed containers from state
#   - Cleans up all managed containers
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup all containers managed by the tool
# Example: cleanup_all_managed_containers true
# =============================================================================
cleanup_all_managed_containers() {
    local force="${1:-false}"
    local operation="CLEANUP_ALL_MANAGED"
    
    log_operation_start "$operation" "" "Cleaning up all managed containers"
    
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
    
    # Add force flag to the end
    container_array+=("$force")
    
    # Cleanup all containers
    cleanup_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: cleanup_all_containers
# =============================================================================
# Purpose: Clean up all containers on the system
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves all containers from Docker
#   - Cleans up all containers
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup all containers on the system
# Example: cleanup_all_containers true
# Warning: This will remove ALL containers, not just managed ones
# =============================================================================
cleanup_all_containers() {
    local force="${1:-false}"
    local operation="CLEANUP_ALL"
    
    log_operation_start "$operation" "" "Cleaning up all containers"
    
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
    
    print_info "Found ${#container_array[@]} containers"
    
    # Add force flag to the end
    container_array+=("$force")
    
    # Cleanup all containers
    cleanup_multiple_containers "${container_array[@]}"
    
    # Force sync state to ensure consistency after bulk cleanup
    force_sync_state_after_cleanup
}

# =============================================================================
# FUNCTION: cleanup_stopped_containers
# =============================================================================
# Purpose: Clean up only stopped containers
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves stopped containers from Docker
#   - Cleans up only stopped containers
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup only stopped containers
# Example: cleanup_stopped_containers true
# =============================================================================
cleanup_stopped_containers() {
    local force="${1:-false}"
    local operation="CLEANUP_STOPPED"
    
    log_operation_start "$operation" "" "Cleaning up stopped containers"
    
    # Get stopped containers
    local stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
    if [[ -z "$stopped_containers" ]]; then
        print_info "No stopped containers found"
        return 0
    fi
    
    local container_array=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            container_array+=("$container")
        fi
    done <<< "$stopped_containers"
    
    if [[ ${#container_array[@]} -eq 0 ]]; then
        print_info "No stopped containers found"
        return 0
    fi
    
    print_info "Found ${#container_array[@]} stopped containers"
    
    # Add force flag to the end
    container_array+=("$force")
    
    # Cleanup stopped containers
    cleanup_multiple_containers "${container_array[@]}"
}

# =============================================================================
# FUNCTION: cleanup_unused_images
# =============================================================================
# Purpose: Clean up unused Docker images (dangling images)
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves unused images from Docker
#   - Removes unused images
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup unused Docker images
# Example: cleanup_unused_images true
# =============================================================================
cleanup_unused_images() {
    local force="${1:-false}"
    local operation="CLEANUP_IMAGES"
    
    log_operation_start "$operation" "" "Cleaning up unused images"
    
    # Get unused images
    local unused_images=$(docker images --filter "dangling=true" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null)
    if [[ -z "$unused_images" ]]; then
        print_info "No unused images found"
        return 0
    fi
    
    local image_array=()
    while IFS= read -r image; do
        if [[ -n "$image" ]]; then
            image_array+=("$image")
        fi
    done <<< "$unused_images"
    
    if [[ ${#image_array[@]} -eq 0 ]]; then
        print_info "No unused images found"
        return 0
    fi
    
    print_info "Found ${#image_array[@]} unused images"
    
    local success_count=0
    local total_count=${#image_array[@]}
    
    for image in "${image_array[@]}"; do
        print_info "Removing unused image: $image"
        
        local command="docker rmi $image"
        if [[ "$force" == "true" ]]; then
            command="docker rmi -f $image"
        fi
        
        local output=$(execute_docker_command "$operation" "" "$command")
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count unused images cleaned up successfully"
        print_success "All $total_count unused images cleaned up successfully"
    else
        log_operation_failure "$operation" "" "Cleaned up $success_count out of $total_count unused images"
        print_warning "Cleaned up $success_count out of $total_count unused images"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: cleanup_unused_volumes
# =============================================================================
# Purpose: Clean up unused Docker volumes
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves unused volumes from Docker
#   - Removes unused volumes
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup unused Docker volumes
# Example: cleanup_unused_volumes true
# Warning: This will permanently delete volume data
# =============================================================================
cleanup_unused_volumes() {
    local force="${1:-false}"
    local operation="CLEANUP_VOLUMES"
    
    log_operation_start "$operation" "" "Cleaning up unused volumes"
    
    # Get unused volumes
    local unused_volumes=$(docker volume ls -q -f dangling=true 2>/dev/null)
    if [[ -z "$unused_volumes" ]]; then
        print_info "No unused volumes found"
        return 0
    fi
    
    local volume_array=()
    while IFS= read -r volume; do
        if [[ -n "$volume" ]]; then
            volume_array+=("$volume")
        fi
    done <<< "$unused_volumes"
    
    if [[ ${#volume_array[@]} -eq 0 ]]; then
        print_info "No unused volumes found"
        return 0
    fi
    
    print_info "Found ${#volume_array[@]} unused volumes"
    
    local success_count=0
    local total_count=${#volume_array[@]}
    
    for volume in "${volume_array[@]}"; do
        print_info "Removing unused volume: $volume"
        
        local command="docker volume rm $volume"
        local output=$(execute_docker_command "$operation" "" "$command")
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count unused volumes cleaned up successfully"
        print_success "All $total_count unused volumes cleaned up successfully"
    else
        log_operation_failure "$operation" "" "Cleaned up $success_count out of $total_count unused volumes"
        print_warning "Cleaned up $success_count out of $total_count unused volumes"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: cleanup_unused_networks
# =============================================================================
# Purpose: Clean up unused Docker networks
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Retrieves unused networks from Docker
#   - Removes unused networks
#   - Provides summary of cleanup results
# Return code: 0 if successful, 1 if failed
# Usage: Called to cleanup unused Docker networks
# Example: cleanup_unused_networks true
# =============================================================================
cleanup_unused_networks() {
    local force="${1:-false}"
    local operation="CLEANUP_NETWORKS"
    
    log_operation_start "$operation" "" "Cleaning up unused networks"
    
    # Get unused networks
    local unused_networks=$(docker network ls --filter "type=custom" --format "{{.Name}}" 2>/dev/null)
    if [[ -z "$unused_networks" ]]; then
        print_info "No unused networks found"
        return 0
    fi
    
    local network_array=()
    while IFS= read -r network; do
        if [[ -n "$network" ]]; then
            # Check if network is used by any containers
            local containers_using_network=$(docker network inspect "$network" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)
            if [[ -z "$containers_using_network" ]]; then
                network_array+=("$network")
            fi
        fi
    done <<< "$unused_networks"
    
    if [[ ${#network_array[@]} -eq 0 ]]; then
        print_info "No unused networks found"
        return 0
    fi
    
    print_info "Found ${#network_array[@]} unused networks"
    
    local success_count=0
    local total_count=${#network_array[@]}
    
    for network in "${network_array[@]}"; do
        print_info "Removing unused network: $network"
        
        local command="docker network rm $network"
        local output=$(execute_docker_command "$operation" "" "$command")
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count unused networks cleaned up successfully"
        print_success "All $total_count unused networks cleaned up successfully"
    else
        log_operation_failure "$operation" "" "Cleaned up $success_count out of $total_count unused networks"
        print_warning "Cleaned up $success_count out of $total_count unused networks"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: full_cleanup
# =============================================================================
# Purpose: Perform a comprehensive cleanup of all Docker resources
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Cleans up containers, images, volumes, and networks
#   - Performs system prune
#   - Provides comprehensive cleanup summary
# Return code: 0 if successful, 1 if failed
# Usage: Called to perform a complete Docker cleanup
# Example: full_cleanup true
# =============================================================================
full_cleanup() {
    local force="${1:-false}"
    local operation="FULL_CLEANUP"
    
    log_operation_start "$operation" "" "Performing full cleanup"
    
    print_header "Full Docker Cleanup"
    
    # Cleanup containers
    print_section "Cleaning up containers"
    cleanup_all_containers "$force"
    
    # Cleanup images
    print_section "Cleaning up images"
    cleanup_unused_images "$force"
    
    # Cleanup volumes
    print_section "Cleaning up volumes"
    cleanup_unused_volumes "$force"
    
    # Cleanup networks
    print_section "Cleaning up networks"
    cleanup_unused_networks "$force"
    
    # System prune
    print_section "System prune"
    local command="docker system prune -f"
    local output=$(execute_docker_command "$operation" "" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "" "Full cleanup completed successfully"
        print_success "Full cleanup completed successfully"
    else
        log_operation_failure "$operation" "" "Full cleanup completed with errors"
        print_warning "Full cleanup completed with some errors"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: full_system_cleanup
# =============================================================================
# Purpose: Perform a complete Docker system cleanup (removes ALL resources)
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Stops and removes ALL containers
#   - Removes ALL images
#   - Removes ALL volumes
#   - Removes ALL networks
#   - Clears state file
# Return code: 0 if successful, 1 if failed
# Usage: Called to completely reset Docker system
# Example: full_system_cleanup true
# WARNING: This will remove ALL Docker resources, not just managed ones!
# DANGER: This operation is irreversible and will delete all data!
# =============================================================================
full_system_cleanup() {
    local force="${1:-false}"
    local operation="FULL_SYSTEM_CLEANUP"
    
    log_operation_start "$operation" "" "Performing FULL Docker system cleanup (containers, images, volumes, networks)"
    print_header "Full Docker System Cleanup (DANGER)"
    print_warning "This will remove ALL containers, images, volumes, and networks from your Docker system!"
    
    # Stop all running containers
    print_section "Stopping all running containers"
    docker ps -q | xargs -r docker stop
    
    # Remove all containers with multiple attempts to ensure complete cleanup
    print_section "Removing all containers"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local remaining_containers=$(docker ps -a -q 2>/dev/null | wc -l)
        if [[ $remaining_containers -eq 0 ]]; then
            print_info "All containers removed successfully"
            break
        fi
        
        print_info "Attempt $attempt: Removing $remaining_containers containers"
        docker ps -a -q | xargs -r docker rm -f
        
        # Wait a moment for Docker to process the removals
        sleep 1
        
        attempt=$((attempt + 1))
    done
    
    # Verify all containers are removed
    local final_check=$(docker ps -a -q 2>/dev/null | wc -l)
    if [[ $final_check -gt 0 ]]; then
        print_warning "Warning: $final_check containers still exist after cleanup attempts"
        # Force remove any remaining containers with additional force
        docker ps -a -q | xargs -r docker rm -f --force
        sleep 2
    fi
    
    # Remove all images
    print_section "Removing all images"
    docker images -q | xargs -r docker rmi -f
    
    # Remove all volumes
    print_section "Removing all volumes"
    docker volume ls -q | xargs -r docker volume rm -f
    
    # Remove all networks (except default ones)
    print_section "Removing all user-defined networks"
    docker network ls --filter "type=custom" --format "{{.Name}}" | xargs -r docker network rm
    
    # System prune (just in case)
    print_section "Docker system prune"
    docker system prune -af --volumes
    
    # Clear state file
    print_section "Clearing Docker Ops Manager state file"
    clear_state
    
    # Force sync state to ensure consistency
    force_sync_state_after_cleanup
    
    # Final verification
    print_section "Verification"
    local containers_remaining=$(docker ps -a -q 2>/dev/null | wc -l)
    local images_remaining=$(docker images -q 2>/dev/null | wc -l)
    local volumes_remaining=$(docker volume ls -q 2>/dev/null | wc -l)
    
    if [[ $containers_remaining -eq 0 && $images_remaining -eq 0 && $volumes_remaining -eq 0 ]]; then
        print_success "✓ All Docker resources successfully removed"
    else
        print_warning "⚠ Some resources remain: $containers_remaining containers, $images_remaining images, $volumes_remaining volumes"
    fi
    
    log_operation_success "$operation" "" "Full Docker system cleanup completed successfully"
    print_success "Full Docker system cleanup completed successfully"
} 

# =============================================================================
# FUNCTION: nuke_docker_system
# =============================================================================
# Purpose: Completely remove all Docker containers and images after user confirmation
# Inputs: 
#   $1 - force: Force removal flag (optional, defaults to false)
# Outputs: None
# Side Effects: 
#   - Prompts user for confirmation (default: N)
#   - Removes ALL containers, images, volumes, and networks
#   - Clears state file
#   - Provides comprehensive cleanup summary
# Return code: 0 if successful, 1 if cancelled or failed
# Usage: Called when "nuke" command is invoked
# Example: nuke_docker_system true
# WARNING: This will remove ALL Docker resources, not just managed ones!
# DANGER: This operation is irreversible and will delete all data!
# =============================================================================
nuke_docker_system() {
    local force="${1:-false}"
    local operation="NUKE_DOCKER_SYSTEM"
    
    log_operation_start "$operation" "" "Nuking Docker system (user confirmation required)"
    
    print_header "Docker System Nuke (DANGER)"
    print_warning "This will remove ALL containers, images, volumes, and networks from your Docker system!"
    print_warning "This operation is irreversible and will delete all data!"
    
    # Show what will be deleted
    print_section "Resources to be deleted:"
    local container_count=$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')
    local image_count=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
    local volume_count=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
    local network_count=$(docker network ls --filter "type=custom" -q 2>/dev/null | wc -l | tr -d ' ')
    
    echo "  - Containers: $container_count"
    echo "  - Images: $image_count"
    echo "  - Volumes: $volume_count"
    echo "  - Networks: $network_count"
    echo ""
    
    # User confirmation
    local default_response="N"
    local prompt="Are you absolutely sure you want to proceed? (y/N): "
    
    if [[ "$force" == "true" ]]; then
        print_info "Force flag detected, skipping confirmation"
        local response="y"
    else
        read -p "$prompt" -r response
    fi
    
    # Convert to lowercase for comparison
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response" != "y" && "$response" != "yes" ]]; then
        print_info "Operation cancelled by user"
        log_operation_failure "$operation" "" "Operation cancelled by user"
        return 1
    fi
    
    print_info "User confirmed - proceeding with Docker system nuke..."
    
    # Perform the full system cleanup
    full_system_cleanup "$force"
    
    # Additional verification and summary
    print_section "Nuke Operation Summary"
    local final_container_count=$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')
    local final_image_count=$(docker images -q 2>/dev/null | wc -l | tr -d ' ')
    local final_volume_count=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $final_container_count -eq 0 && $final_image_count -eq 0 ]]; then
        print_success "✓ Docker system successfully nuked"
        print_info "All containers and images removed"
        print_info "State file cleared"
    else
        print_warning "⚠ Some resources remain after nuke operation"
        print_info "Remaining: $final_container_count containers, $final_image_count images, $final_volume_count volumes"
    fi
    
    log_operation_success "$operation" "" "Docker system nuke completed successfully"
    print_success "Docker system nuke completed successfully"
} 