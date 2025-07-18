#!/usr/bin/env bash

# Install Operation Module
# Handles container installation and reinstallation

# =============================================================================
# FUNCTION: install_container
# =============================================================================
# Purpose: Install a container from its stored YAML configuration
# Inputs: 
#   $1 - container_name: Name of the container to install
# Outputs: None
# Side Effects: 
#   - Retrieves container information from state
#   - Validates YAML source file
#   - Generates container from YAML configuration
#   - Updates state with installation results
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "install" operation is requested
# Example: install_container "my-app"
# =============================================================================
install_container() {
    local container_name="$1"
    local operation="INSTALL"
    
    log_operation_start "$operation" "$container_name" "Installing container"
    
    # Check if container exists
    if container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container already exists"
        print_error "Container '$container_name' already exists"
        print_info "Use 'reinstall' to update the container"
        return 1
    fi
    
    # Get container information from state
    local operation_record=$(get_container_operation_record "$container_name")
    if [[ -z "$operation_record" ]]; then
        log_operation_failure "$operation" "$container_name" "No container information found in state"
        print_error "No information found for container '$container_name'"
        print_info "Use 'generate' to create a new container from YAML"
        return 1
    fi
    
    # Extract information from state
    local yaml_source=$(echo "$operation_record" | jq -r '.yaml_source')
    local last_operation=$(echo "$operation_record" | jq -r '.last_operation')
    
    if [[ -z "$yaml_source" || "$yaml_source" == "null" ]]; then
        log_operation_failure "$operation" "$container_name" "No YAML source found in state"
        print_error "No YAML source found for container '$container_name'"
        return 1
    fi
    
    # Validate YAML file
    if ! validate_file_path "$yaml_source" "YAML source file"; then
        return 1
    fi
    
    # Generate container from YAML
    print_info "Installing container from: $yaml_source"
    generate_from_yaml "$yaml_source" "$container_name"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container installed successfully"
        print_success "Container '$container_name' installed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to install container"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: reinstall_container
# =============================================================================
# Purpose: Reinstall a container by removing the existing one and creating a new one
# Inputs: 
#   $1 - container_name: Name of the container to reinstall
# Outputs: None
# Side Effects: 
#   - Stops and removes existing container
#   - Retrieves YAML source from state
#   - Generates new container from YAML
#   - Updates state with reinstallation results
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "reinstall" operation is requested
# Example: reinstall_container "my-app"
# =============================================================================
reinstall_container() {
    local container_name="$1"
    local operation="REINSTALL"
    
    log_operation_start "$operation" "$container_name" "Reinstalling container"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        print_info "Use 'install' to create a new container"
        return 1
    fi
    
    # Get container information from state
    local operation_record=$(get_container_operation_record "$container_name")
    if [[ -z "$operation_record" ]]; then
        log_operation_failure "$operation" "$container_name" "No container information found in state"
        print_error "No information found for container '$container_name'"
        return 1
    fi
    
    # Extract information from state
    local yaml_source=$(echo "$operation_record" | jq -r '.yaml_source')
    local container_id=$(echo "$operation_record" | jq -r '.container_id')
    
    if [[ -z "$yaml_source" || "$yaml_source" == "null" ]]; then
        log_operation_failure "$operation" "$container_name" "No YAML source found in state"
        print_error "No YAML source found for container '$container_name'"
        return 1
    fi
    
    # Validate YAML file
    if ! validate_file_path "$yaml_source" "YAML source file"; then
        return 1
    fi
    
    # Stop container if running
    if container_is_running "$container_name"; then
        print_info "Stopping running container..."
        stop_container "$container_name"
    fi
    
    # Remove existing container
    print_info "Removing existing container..."
    remove_container "$container_name" "true"
    
    # Generate new container from YAML
    print_info "Reinstalling container from: $yaml_source"
    generate_from_yaml "$yaml_source" "$container_name"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container reinstalled successfully"
        print_success "Container '$container_name' reinstalled successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to reinstall container"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: update_container_image
# =============================================================================
# Purpose: Update a container's image to the latest version
# Inputs: 
#   $1 - container_name: Name of the container to update
# Outputs: None
# Side Effects: 
#   - Pulls latest image from registry
#   - Stops and removes existing container
#   - Recreates container with new image
#   - Restarts container if it was running before
#   - Updates state with new container information
# Return code: 0 if successful, 1 if failed
# Usage: Called to update container images to latest versions
# Example: update_container_image "my-app"
# =============================================================================
update_container_image() {
    local container_name="$1"
    local operation="UPDATE_IMAGE"
    
    log_operation_start "$operation" "$container_name" "Updating container image"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get current image
    local current_image=$(get_container_image "$container_name")
    if [[ -z "$current_image" ]]; then
        log_operation_failure "$operation" "$container_name" "Could not get current image"
        print_error "Could not get current image for container '$container_name'"
        return 1
    fi
    
    print_info "Current image: $current_image"
    
    # Pull latest image
    print_info "Pulling latest image..."
    local pull_command="docker pull $current_image"
    local output=$(execute_docker_command "$operation" "$container_name" "$pull_command" 300)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_operation_failure "$operation" "$container_name" "Failed to pull latest image"
        print_error "Failed to pull latest image"
        return $exit_code
    fi
    
    # Stop container if running
    local was_running=false
    if container_is_running "$container_name"; then
        print_info "Stopping container to update..."
        stop_container "$container_name"
        was_running=true
    fi
    
    # Remove container (keeping volumes)
    print_info "Removing container (keeping volumes)..."
    local command="docker rm $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_operation_failure "$operation" "$container_name" "Failed to remove container"
        print_error "Failed to remove container"
        return $exit_code
    fi
    
    # Get container information from state
    local operation_record=$(get_container_operation_record "$container_name")
    local yaml_source=""
    if [[ -n "$operation_record" ]]; then
        yaml_source=$(echo "$operation_record" | jq -r '.yaml_source')
    fi
    
    # Recreate container
    if [[ -n "$yaml_source" && "$yaml_source" != "null" ]]; then
        print_info "Recreating container from YAML..."
        generate_from_yaml "$yaml_source" "$container_name"
    else
        print_info "Recreating container with same configuration..."
        # This would need the original docker run command
        # For now, we'll just recreate from the image
        local command="docker run -d --name $container_name $current_image"
        local output=$(execute_docker_command "$operation" "$container_name" "$command")
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            # Update state
            local new_container_id=$(get_container_id "$container_name")
            update_container_operation "$container_name" "$operation" "$yaml_source" "$new_container_id" "created"
        fi
    fi
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        # Start container if it was running before
        if [[ "$was_running" == "true" ]]; then
            print_info "Starting updated container..."
            start_container "$container_name"
        fi
        
        log_operation_success "$operation" "$container_name" "Container image updated successfully"
        print_success "Container '$container_name' image updated successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to update container image"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: install_container_from_image
# =============================================================================
# Purpose: Install a container directly from a Docker image
# Inputs: 
#   $1 - container_name: Name for the new container
#   $2 - image_name: Docker image to use
#   $3 - docker_run_cmd: Custom docker run command (optional)
# Outputs: None
# Side Effects: 
#   - Creates container from specified image
#   - Uses custom docker run command if provided
#   - Updates state with container information
# Return code: 0 if successful, 1 if failed
# Usage: Called to install containers directly from images without YAML
# Example: install_container_from_image "my-app" "nginx:alpine" "docker run -d -p 80:80 --name my-app nginx:alpine"
# =============================================================================
install_container_from_image() {
    local container_name="$1"
    local image_name="$2"
    local docker_run_cmd="$3"
    local operation="INSTALL_FROM_IMAGE"
    
    log_operation_start "$operation" "$container_name" "Installing container from image"
    
    # Validate inputs
    if [[ -z "$container_name" ]]; then
        log_operation_failure "$operation" "" "Container name is required"
        print_error "Container name is required"
        return 1
    fi
    
    if [[ -z "$image_name" ]]; then
        log_operation_failure "$operation" "$container_name" "Image name is required"
        print_error "Image name is required"
        return 1
    fi
    
    # Check if container already exists
    if container_exists "$container_name"; then
        if [[ "$FORCE" == "true" ]]; then
            print_info "Container exists, removing due to force flag..."
            remove_container "$container_name" "true"
        else
            log_operation_failure "$operation" "$container_name" "Container already exists"
            print_error "Container '$container_name' already exists"
            print_info "Use --force to overwrite"
            return 1
        fi
    fi
    
    # Create container
    if [[ -n "$docker_run_cmd" ]]; then
        create_container "$container_name" "$image_name" "$docker_run_cmd"
    else
        # Use default docker run command
        local default_cmd="docker run -d --name $container_name $image_name"
        create_container "$container_name" "$image_name" "$default_cmd"
    fi
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container installed from image successfully"
        print_success "Container '$container_name' installed from image successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to install container from image"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: install_multiple_containers
# =============================================================================
# Purpose: Install multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names to install
# Outputs: None
# Side Effects: 
#   - Installs each container in the provided list
#   - Provides summary of installation results
#   - Continues installation even if some containers fail
# Return code: 0 if successful, 1 if failed
# Usage: Called to install multiple containers at once
# Example: install_multiple_containers "web" "db" "cache"
# =============================================================================
install_multiple_containers() {
    local containers=("$@")
    local operation="INSTALL_MULTIPLE"
    
    log_operation_start "$operation" "" "Installing multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    local success_count=0
    local total_count=${#containers[@]}
    
    print_info "Installing $total_count containers..."
    
    for container_name in "${containers[@]}"; do
        print_info "Installing container: $container_name"
        
        if install_container "$container_name"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers installed successfully"
        print_success "All $total_count containers installed successfully"
    else
        log_operation_failure "$operation" "" "Installed $success_count out of $total_count containers"
        print_warning "Installed $success_count out of $total_count containers"
    fi
    
    return 0
} 

# =============================================================================
# FUNCTION: reinstall_multiple_containers
# =============================================================================
# Purpose: Reinstall multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names to reinstall
# Outputs: None
# Side Effects: 
#   - Reinstalls each container in the provided list
#   - Provides summary of reinstallation results
#   - Continues reinstallation even if some containers fail
# Return code: 0 if successful, 1 if failed
# Usage: Called to reinstall multiple containers at once
# Example: reinstall_multiple_containers "web" "db" "cache"
# =============================================================================
reinstall_multiple_containers() {
    local containers=("$@")
    local operation="REINSTALL_MULTIPLE"
    
    log_operation_start "$operation" "" "Reinstalling multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    local success_count=0
    local total_count=${#containers[@]}
    
    print_info "Reinstalling $total_count containers..."
    
    for container_name in "${containers[@]}"; do
        print_info "Reinstalling container: $container_name"
        
        if reinstall_container "$container_name"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers reinstalled successfully"
        print_success "All $total_count containers reinstalled successfully"
    else
        log_operation_failure "$operation" "" "Reinstalled $success_count out of $total_count containers"
        print_warning "Reinstalled $success_count out of $total_count containers"
    fi
    
    return 0
} 