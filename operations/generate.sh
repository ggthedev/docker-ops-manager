#!/usr/bin/env bash

# Generate Operation Module
# Handles container generation from YAML files

# =============================================================================
# FUNCTION: generate_from_yaml
# =============================================================================
# Purpose: Generate a Docker container from a YAML configuration file
# Inputs: 
#   $1 - yaml_file: Path to the YAML configuration file
#   $2 - container_name: Name of the container to generate (optional)
# Outputs: None
# Side Effects: 
#   - Creates Docker container from YAML configuration
#   - Updates state with container information
#   - Logs operation details
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "generate" operation is requested
# Example: generate_from_yaml "docker-compose.yml" "web"
# =============================================================================
generate_from_yaml() {
    local yaml_file="$1"
    local container_name="$2"
    local operation="GENERATE"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "generate_from_yaml" "yaml_file=$yaml_file, container_name=$container_name" "YAML container generation"
    
    log_operation_start "$operation" "$container_name" "Generating container from YAML"
    
    # Show initial progress
    show_generation_progress 1 "$yaml_file" "$container_name"
    
    # Validate YAML file
    trace_yaml_parse "$yaml_file" "validate" "Checking file existence and syntax"
    if ! validate_yaml_file "$yaml_file"; then
        trace_log "YAML validation failed" "ERROR"
        log_operation_failure "$operation" "$container_name" "YAML file validation failed - File: $yaml_file"
        print_error "❌ YAML file validation failed for '$yaml_file'"
        print_info "💡 Please check:"
        print_info "   - File exists and is readable"
        print_info "   - YAML syntax is correct"
        print_info "   - File contains valid Docker Compose or custom YAML"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "generate_from_yaml" "1" "YAML validation failed" "$duration"
        return 1
    fi
    trace_log "YAML validation successful" "INFO"
    show_generation_step_complete 1 "$yaml_file" "$container_name"
    
    # Show progress for YAML type detection
    show_generation_progress 2 "$yaml_file" "$container_name"
    
    # Detect YAML type
    trace_yaml_parse "$yaml_file" "detect_type" "Analyzing YAML structure"
    local yaml_type=$(detect_yaml_type "$yaml_file")
    trace_log "Detected YAML type: $yaml_type" "INFO"
    log_info "$operation" "$container_name" "Detected YAML type: $yaml_type"
    
    # Extract container names from YAML
    trace_yaml_parse "$yaml_file" "extract_containers" "Finding container definitions"
    local containers=$(extract_container_names "$yaml_file" "$yaml_type")
    if [[ -z "$containers" ]]; then
        trace_log "No containers found in YAML" "ERROR"
        log_operation_failure "$operation" "$container_name" "No containers found in YAML file - File: $yaml_file, Type: $yaml_type"
        print_error "❌ No containers found in YAML file '$yaml_file'"
        print_info "💡 Please ensure the file contains:"
        print_info "   - For Docker Compose: services section with at least one service"
        print_info "   - For Custom YAML: container definitions"
        print_info "   - Valid YAML structure"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "generate_from_yaml" "1" "No containers found" "$duration"
        return 1
    fi
    trace_log "Found containers: $containers" "INFO"
    
    # If no specific container name provided, use the first one
    if [[ -z "$container_name" ]]; then
        container_name=$(echo "$containers" | head -1)
        trace_log "Using first container from YAML: $container_name" "INFO"
        log_info "$operation" "$container_name" "Using first container from YAML: $container_name"
    fi
    
    # Validate container name
    trace_container_operation "$container_name" "validate_name" "Checking naming conventions"
    if ! validate_container_name "$container_name"; then
        trace_log "Container name validation failed: $container_name" "ERROR"
        log_operation_failure "$operation" "$container_name" "Invalid container name - Name: $container_name"
        print_error "❌ Invalid container name '$container_name'"
        print_info "💡 Container names must:"
        print_info "   - Contain only alphanumeric characters, hyphens, and underscores"
        print_info "   - Start with a letter or number"
        print_info "   - Be between 1-63 characters long"
        print_info "   - Not contain special characters or spaces"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "generate_from_yaml" "1" "Invalid container name" "$duration"
        return 1
    fi
    trace_log "Container name validation successful" "INFO"
    
    # Resolve actual container name from YAML before checking existence
    trace_state_operation "resolve" "container_name" "Resolving actual container name from YAML"
    local actual_container_name=$(resolve_container_name "$yaml_file" "$container_name")
    trace_log "Resolved container name: $container_name -> $actual_container_name" "INFO"
    
    # Check if container already exists (using actual container name)
    trace_container_operation "$actual_container_name" "check_exists" "Verifying container existence"
    if container_exists "$actual_container_name"; then
        trace_log "Container already exists: $actual_container_name" "WARN"
        if [[ "$FORCE" == "true" ]]; then
            trace_log "Force flag set, removing existing container" "INFO"
            log_info "$operation" "$actual_container_name" "Container exists, removing due to force flag"
            
            # Enhanced container removal with retry logic
            local removal_attempts=0
            local max_removal_attempts=3
            local removal_success=false
            
            while [[ $removal_attempts -lt $max_removal_attempts && "$removal_success" == "false" ]]; do
                removal_attempts=$((removal_attempts + 1))
                trace_log "Removal attempt $removal_attempts for container: $actual_container_name" "INFO"
                
                remove_container "$actual_container_name" "true"
                local removal_exit_code=$?
                
                if [[ $removal_exit_code -eq 0 ]]; then
                    # Verify container is actually removed
                    if ! container_exists "$actual_container_name"; then
                        removal_success=true
                        trace_log "Container successfully removed: $actual_container_name" "INFO"
                    else
                        trace_log "Container still exists after removal attempt $removal_attempts" "WARN"
                        sleep 1
                    fi
                else
                    trace_log "Container removal failed on attempt $removal_attempts" "WARN"
                    sleep 1
                fi
            done
            
            if [[ "$removal_success" == "false" ]]; then
                trace_log "Failed to remove container after $max_removal_attempts attempts" "ERROR"
                log_operation_failure "$operation" "$actual_container_name" "Failed to remove existing container after $max_removal_attempts attempts"
                print_error "❌ Failed to remove existing container '$actual_container_name' after $max_removal_attempts attempts"
                print_info "💡 Please try:"
                print_info "   - Manual cleanup: docker rm -f $actual_container_name"
                print_info "   - Check container status: docker ps -a | grep $actual_container_name"
                print_info "   - Restart Docker daemon if needed"
                
                local end_time=$(date +%s.%N)
                local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
                trace_exit "generate_from_yaml" "1" "Failed to remove existing container" "$duration"
                return 1
            fi
        else
            trace_log "Container exists and force not set, aborting" "ERROR"
            log_operation_failure "$operation" "$actual_container_name" "Container already exists - Name: $actual_container_name"
            print_error "❌ Container '$actual_container_name' already exists"
            print_info "💡 Use --force to overwrite the existing container"
            print_info "   Or use a different container name"
            print_info "   Current container status: $(docker inspect --format='{{.State.Status}}' "$actual_container_name" 2>/dev/null || echo 'unknown')"
            
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "generate_from_yaml" "1" "Container already exists" "$duration"
            return 1
        fi
    else
        trace_log "Container does not exist, proceeding with creation" "INFO"
    fi
    
    show_generation_step_complete 2 "$yaml_file" "$container_name"
    
    # Show progress for container creation
    show_generation_progress 3 "$yaml_file" "$container_name"
    
    # Generate container based on YAML type
    trace_log "Generating container using type: $yaml_type" "INFO"
    case "$yaml_type" in
        "docker-compose"|"docker-stack")
            generate_from_docker_compose "$yaml_file" "$container_name" "$operation"
            ;;
        "custom")
            generate_from_custom_yaml "$yaml_file" "$container_name" "$operation"
            ;;
        *)
            trace_log "Unsupported YAML type: $yaml_type" "ERROR"
            log_operation_failure "$operation" "$container_name" "Unsupported YAML type - Type: $yaml_type, File: $yaml_file"
            print_error "❌ Unsupported YAML type: $yaml_type"
            print_info "💡 Supported types: docker-compose, docker-stack, custom"
            print_info "   Please ensure your YAML file follows one of these formats"
            
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "generate_from_yaml" "1" "Unsupported YAML type" "$duration"
            return 1
            ;;
    esac
    
    # Update state with actual container name
    trace_state_operation "set" "last_container" "$actual_container_name"
    set_last_container "$actual_container_name"
    trace_state_operation "set" "last_operation" "$operation"
    set_last_operation "$operation"
    trace_state_operation "set" "last_yaml_file" "$yaml_file"
    set_last_yaml_file "$yaml_file"
    
    # Show final progress step
    show_generation_progress 4 "$yaml_file" "$container_name"
    show_generation_step_complete 4 "$yaml_file" "$container_name"
    
    log_operation_success "$operation" "$actual_container_name" "Container generated successfully"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "generate_from_yaml" "0" "Container generated successfully" "$duration"
    return 0
}

# =============================================================================
# FUNCTION: generate_from_docker_compose
# =============================================================================
# Purpose: Generate a container from a Docker Compose YAML file
# Inputs: 
#   $1 - yaml_file: Path to the Docker Compose YAML file
#   $2 - container_name: Name of the service/container to generate
#   $3 - operation: Operation name for logging
# Outputs: None
# Side Effects: 
#   - Creates temporary Docker Compose file for single service
#   - Runs docker-compose up command
#   - Updates state with container information
#   - Waits for container readiness
# Return code: 0 if successful, 1 if failed
# Usage: Called by generate_from_yaml for docker-compose type YAML files
# Example: generate_from_docker_compose "docker-compose.yml" "web" "GENERATE"
# =============================================================================
generate_from_docker_compose() {
    local yaml_file="$1"
    local container_name="$2"
    local operation="$3"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "generate_from_docker_compose" "yaml_file=$yaml_file, container_name=$container_name, operation=$operation" "Docker Compose generation"
    
    log_info "$operation" "$container_name" "Generating from docker-compose YAML"
    
    # Check if docker-compose is available
    trace_command "docker-compose --version" "$operation" "$container_name"
    if ! command_exists docker-compose; then
        trace_log "docker-compose not found" "ERROR"
        log_error "$operation" "$container_name" "docker-compose is not installed - Command: docker-compose"
        print_error "❌ docker-compose is not installed"
        print_info "💡 Please install docker-compose:"
        print_info "   - macOS: brew install docker-compose"
        print_info "   - Ubuntu: sudo apt-get install docker-compose"
        print_info "   - Or use: pip install docker-compose"
        print_info "   - Or use Docker Compose V2: docker compose (built into Docker)"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "generate_from_docker_compose" "1" "docker-compose not installed" "$duration"
        return 1
    fi
    trace_log "docker-compose is available" "INFO"
    
    # Create a temporary docker-compose file for single service
    trace_log "Creating temporary docker-compose file" "INFO"
    local temp_compose_file=$(create_temp_file "compose" ".yml")
    trace_log "Temporary file created: $temp_compose_file" "DEBUG"
    
    # Extract the specific service configuration
    trace_log "Extracting service configuration from YAML" "INFO"
    if command -v yq &> /dev/null; then
        trace_log "Using yq for YAML parsing" "INFO"
        # Use yq to extract the service - simpler approach
        local version=$(yq eval '.version' "$yaml_file")
        
        # Extract or generate project name using YAML parser
        local project_name=$(extract_project_name "$yaml_file" "$container_name")
        trace_log "Project name: $project_name" "DEBUG"
        
        echo "version: '$version'" > "$temp_compose_file"
        echo "name: $project_name" >> "$temp_compose_file"
        echo "services:" >> "$temp_compose_file"
        echo "  $container_name:" >> "$temp_compose_file"
        yq eval ".services.$container_name" "$yaml_file" | sed 's/^/    /' >> "$temp_compose_file"
        
        # Add volumes section if it exists in the original file
        if yq eval '.volumes' "$yaml_file" > /dev/null 2>&1; then
            trace_log "Adding volumes section to temporary compose file" "DEBUG"
            echo "" >> "$temp_compose_file"
            echo "volumes:" >> "$temp_compose_file"
            yq eval '.volumes' "$yaml_file" | sed 's/^/  /' >> "$temp_compose_file"
        fi
    else
        trace_log "yq not available, using fallback extraction" "WARN"
        # Fallback to manual extraction (simplified)
        
        # Extract or generate project name using YAML parser
        local project_name=$(extract_project_name "$yaml_file" "$container_name")
        trace_log "Project name (fallback): $project_name" "DEBUG"
        
        cat > "$temp_compose_file" << EOF
version: '3.8'
name: $project_name
services:
  $container_name:
    image: $(extract_image_from_yaml "$yaml_file" "$container_name")
EOF
    fi
    trace_log "Service configuration extracted successfully" "INFO"
    
    # Run docker-compose command based on --no-start flag
    local command=""
    if [[ "$NO_START" == "true" ]]; then
        # Create container without starting it
        command="docker-compose -f $temp_compose_file create"
        trace_log "Using docker-compose create (no-start mode)" "INFO"
    else
        # Create and start container
        command="docker-compose -f $temp_compose_file up -d"
        trace_log "Using docker-compose up -d (start mode)" "INFO"
    fi
    
    trace_command "$command" "$operation" "$container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command" 300)
    local exit_code=$?
    trace_command_result "$command" "$exit_code" "$output"
    
    # Clean up temporary file
    trace_log "Cleaning up temporary compose file: $temp_compose_file" "DEBUG"
    rm -f "$temp_compose_file"
    
    if [[ $exit_code -eq 0 ]]; then
        trace_log "docker-compose command succeeded" "INFO"
        # Update state with container information
        # Resolve actual Docker container name from YAML
        local actual_container_name=$(resolve_container_name "$yaml_file" "$container_name")
        local container_id=$(get_container_id "$actual_container_name")
        trace_log "Container ID: $container_id" "DEBUG"
        
        if [[ "$NO_START" == "true" ]]; then
            # Container created but not started
            update_container_operation "$actual_container_name" "$operation" "$yaml_file" "$container_id" "created"
            print_success "Container '$container_name' created successfully (not started)"
            trace_log "Container created without starting (no-start mode)" "INFO"
        else
            # Container created and started
            update_container_operation "$actual_container_name" "$operation" "$yaml_file" "$container_id" "running"
            
            # Wait for container to be ready
            trace_log "Waiting for container to be ready" "INFO"
            wait_for_container_ready "$container_name" "${TIMEOUT:-}" "$yaml_file"
            
            print_success "Container '$container_name' generated and started successfully"
        fi
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "generate_from_docker_compose" "0" "Container generated successfully" "$duration"
        return 0
    else
        trace_log "docker-compose command failed with exit code: $exit_code" "ERROR"
        log_operation_failure "$operation" "$container_name" "Failed to generate container from docker-compose - Exit code: $exit_code, Output: $output"
        
        # Parse common docker-compose errors and provide helpful messages
        if echo "$output" | grep -q "image.*not found"; then
            local image_name=$(extract_image_from_yaml "$yaml_file" "$container_name")
            print_error "❌ Image '$image_name' not found"
            print_info "💡 Possible solutions:"
            print_info "   - Check if the image name is correct"
            print_info "   - Verify the image exists in Docker Hub or your registry"
            print_info "   - Try running: docker pull $image_name"
        elif echo "$output" | grep -q "port.*already in use"; then
            print_error "❌ Port conflict detected"
            print_info "💡 A port specified in your YAML is already in use"
            print_info "   Please change the port in your YAML file or stop the conflicting container"
        elif echo "$output" | grep -q "network.*not found"; then
            print_error "❌ Network not found"
            print_info "💡 A network specified in your YAML does not exist"
            print_info "   Please create the network first or check the network name"
        elif echo "$output" | grep -q "volume.*not found"; then
            print_error "❌ Volume not found"
            print_info "💡 A volume specified in your YAML does not exist"
            print_info "   Please create the volume first or check the volume name"
        elif echo "$output" | grep -q "permission denied"; then
            print_error "❌ Permission denied"
            print_info "💡 Please check:"
            print_info "   - Docker daemon is running"
            print_info "   - You have permission to access Docker"
            print_info "   - File permissions for mounted volumes"
        else
            print_error "❌ Failed to generate container from docker-compose"
            print_info "💡 Check the logs above for technical details"
            print_info "   Common issues:"
            print_info "   - Invalid YAML syntax"
            print_info "   - Missing required fields"
            print_info "   - Resource constraints"
        fi
        
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: generate_from_custom_yaml
# =============================================================================
# Purpose: Generate a container from a custom YAML configuration file
# Inputs: 
#   $1 - yaml_file: Path to the custom YAML file
#   $2 - container_name: Name of the container to generate
#   $3 - operation: Operation name for logging
# Outputs: None
# Side Effects: 
#   - Extracts container configuration from custom YAML
#   - Generates docker run command
#   - Creates container using docker run
#   - Updates state with container information
# Return code: 0 if successful, 1 if failed
# Usage: Called by generate_from_yaml for custom type YAML files
# Example: generate_from_custom_yaml "custom-app.yml" "my-app" "GENERATE"
# =============================================================================
generate_from_custom_yaml() {
    local yaml_file="$1"
    local container_name="$2"
    local operation="$3"
    
    log_info "$operation" "$container_name" "Generating from custom YAML"
    
    # Extract container configuration
    local container_config=$(get_container_config "$yaml_file" "$container_name" "custom")
    if [[ -z "$container_config" ]]; then
        log_operation_failure "$operation" "$container_name" "Could not extract container configuration - File: $yaml_file, Container: $container_name"
        print_error "❌ Could not extract container configuration for '$container_name'"
        print_info "💡 Please ensure your custom YAML contains:"
        print_info "   - Valid container definition for '$container_name'"
        print_info "   - Required fields: image, ports, volumes (if needed)"
        print_info "   - Proper YAML structure"
        return 1
    fi
    
    # Show progress for image extraction
    show_generation_progress 3 "$yaml_file" "$container_name"
    
    # Extract image name
    local image_name=$(extract_image_name "$container_config")
    if [[ -z "$image_name" ]]; then
        log_operation_failure "$operation" "$container_name" "Could not extract image name - Container: $container_name, Config: $container_config"
        print_error "❌ Could not extract image name for container '$container_name'"
        print_info "💡 Please ensure your YAML contains an 'image' field:"
        print_info "   - Example: image: nginx:alpine"
        print_info "   - The image field must be present and not empty"
        return 1
    fi
    
    # Generate docker run command
    local docker_run_cmd=$(generate_docker_run_command "$yaml_file" "$container_name" "custom" "$NO_START")
    if [[ -z "$docker_run_cmd" ]]; then
        log_operation_failure "$operation" "$container_name" "Could not generate docker run command - Container: $container_name, Config: $container_config"
        print_error "❌ Could not generate docker run command for '$container_name'"
        print_info "💡 This might be due to:"
        print_info "   - Invalid port mappings"
        print_info "   - Invalid volume mounts"
        print_info "   - Missing required configuration"
        print_info "   - Unsupported YAML structure"
        return 1
    fi
    
    # Create container
    create_container "$container_name" "$image_name" "$docker_run_cmd"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Show final progress step
        show_generation_progress 4 "$yaml_file" "$container_name"
        show_generation_step_complete 4 "$yaml_file" "$container_name"
        # Update state with container information
        # Resolve actual Docker container name from YAML
        local actual_container_name=$(resolve_container_name "$yaml_file" "$container_name")
        local container_id=$(get_container_id "$actual_container_name")
        
        if [[ "$NO_START" == "true" ]]; then
            # Container created but not started
            update_container_operation "$actual_container_name" "$operation" "$yaml_file" "$container_id" "created"
            print_success "Container '$actual_container_name' created successfully (not started)"
        else
            # Container created and started
            update_container_operation "$actual_container_name" "$operation" "$yaml_file" "$container_id" "running"
            print_success "Container '$actual_container_name' generated and started successfully"
        fi
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to generate container from custom YAML - Exit code: $exit_code, Image: $image_name"
        
        # Parse common docker run errors and provide helpful messages
        if echo "$output" | grep -q "image.*not found"; then
            print_error "❌ Image '$image_name' not found"
            print_info "💡 Possible solutions:"
            print_info "   - Check if the image name is correct"
            print_info "   - Verify the image exists in Docker Hub or your registry"
            print_info "   - Try running: docker pull $image_name"
        elif echo "$output" | grep -q "port.*already in use"; then
            print_error "❌ Port conflict detected"
            print_info "💡 A port specified in your YAML is already in use"
            print_info "   Please change the port in your YAML file or stop the conflicting container"
        elif echo "$output" | grep -q "bind.*permission denied"; then
            print_error "❌ Permission denied for volume mount"
            print_info "💡 Please check:"
            print_info "   - File permissions for mounted directories"
            print_info "   - Directory exists and is accessible"
            print_info "   - Path format is correct for your OS"
        elif echo "$output" | grep -q "no space left on device"; then
            print_error "❌ Insufficient disk space"
            print_info "💡 Please:"
            print_info "   - Free up disk space"
            print_info "   - Clean up unused Docker images: docker system prune"
        elif echo "$output" | grep -q "memory"; then
            print_error "❌ Insufficient memory"
            print_info "💡 Please:"
            print_info "   - Increase Docker memory limit"
            print_info "   - Stop other containers to free memory"
        else
            print_error "❌ Failed to generate container from custom YAML"
            print_info "💡 Check the logs above for technical details"
            print_info "   Common issues:"
            print_info "   - Invalid configuration in YAML"
            print_info "   - Resource constraints"
            print_info "   - Docker daemon issues"
        fi
        
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: extract_image_from_yaml
# =============================================================================
# Purpose: Extract image name from YAML file using fallback method (grep/sed)
# Inputs: 
#   $1 - yaml_file: Path to the YAML file
#   $2 - container_name: Name of the container/service
# Outputs: Image name or empty string
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Fallback method when yq is not available
# Example: extract_image_from_yaml "docker-compose.yml" "web"
# =============================================================================
extract_image_from_yaml() {
    local yaml_file="$1"
    local container_name="$2"
    
    # Simple grep-based extraction
    local image=$(grep -A 10 "services:" "$yaml_file" | grep -A 10 "$container_name:" | grep "image:" | head -1 | sed 's/.*image:[[:space:]]*//')
    
    if [[ -z "$image" ]]; then
        # Try to find any image in the file
        image=$(grep "image:" "$yaml_file" | head -1 | sed 's/.*image:[[:space:]]*//')
    fi
    
    echo "$image"
}

# =============================================================================
# FUNCTION: generate_all_from_yaml
# =============================================================================
# Purpose: Generate all containers from a YAML file
# Inputs: 
#   $1 - yaml_file: Path to the YAML file
# Outputs: None
# Side Effects: 
#   - Generates all containers found in the YAML file
#   - Updates state for each successful container
#   - Provides summary of generation results
# Return code: 0 if successful, 1 if failed
# Usage: Called when generating all containers from a multi-service YAML
# Example: generate_all_from_yaml "docker-compose.yml"
# =============================================================================
generate_all_from_yaml() {
    local yaml_file="$1"
    local operation="GENERATE_ALL"
    
    log_operation_start "$operation" "" "Generating all containers from YAML"
    
    # Validate YAML file
    if ! validate_yaml_file "$yaml_file"; then
        log_operation_failure "$operation" "" "YAML file validation failed"
        return 1
    fi
    
    # Detect YAML type
    local yaml_type=$(detect_yaml_type "$yaml_file")
    log_info "$operation" "" "Detected YAML type: $yaml_type"
    
    # Extract all container names
    local containers=$(extract_container_names "$yaml_file" "$yaml_type")
    if [[ -z "$containers" ]]; then
        log_operation_failure "$operation" "" "No containers found in YAML file"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    # Generate each container
    while IFS= read -r container_name; do
        if [[ -n "$container_name" ]]; then
            total_count=$((total_count + 1))
            print_info "Generating container: $container_name"
            
            if generate_from_yaml "$yaml_file" "$container_name"; then
                success_count=$((success_count + 1))
            fi
        fi
    done <<< "$containers"
    
    # Summary
    if [[ $success_count -eq $total_count ]]; then
        log_operation_success "$operation" "" "All $total_count containers generated successfully"
        print_success "All $total_count containers generated successfully"
    else
        log_operation_failure "$operation" "" "Generated $success_count out of $total_count containers"
        print_warning "Generated $success_count out of $total_count containers"
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: validate_yaml_for_generation
# =============================================================================
# Purpose: Validate YAML file and container name before generation
# Inputs: 
#   $1 - yaml_file: Path to the YAML file to validate
#   $2 - container_name: Name of the container to validate (optional)
# Outputs: None
# Side Effects: None
# Return code: 0 if valid, 1 if invalid
# Usage: Pre-validation function called before generation
# Example: validate_yaml_for_generation "docker-compose.yml" "web"
# =============================================================================
validate_yaml_for_generation() {
    local yaml_file="$1"
    local container_name="$2"
    
    # Basic validation
    if ! validate_yaml_file "$yaml_file"; then
        log_operation_failure "VALIDATE" "$container_name" "YAML file validation failed - File: $yaml_file"
        print_error "❌ YAML file validation failed for '$yaml_file'"
        print_info "💡 Please check:"
        print_info "   - File exists and is readable"
        print_info "   - YAML syntax is correct"
        print_info "   - File contains valid Docker Compose or custom YAML"
        return 1
    fi
    
    # Check if container name is specified in YAML
    if [[ -n "$container_name" ]]; then
        local yaml_type=$(detect_yaml_type "$yaml_file")
        local containers=$(extract_container_names "$yaml_file" "$yaml_type")
        
        if ! echo "$containers" | grep -q "^$container_name$"; then
            log_operation_failure "VALIDATE" "$container_name" "Container not found in YAML - Container: $container_name, File: $yaml_file, Available: $containers"
            print_error "❌ Container '$container_name' not found in YAML file '$yaml_file'"
            print_info "💡 Available containers:"
            echo "$containers" | while read -r container; do
                print_info "   - $container"
            done
            print_info "💡 Please specify one of the available containers or check the container name"
            return 1
        fi
    fi
    
    return 0
} 