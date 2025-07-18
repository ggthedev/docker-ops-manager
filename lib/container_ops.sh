#!/usr/bin/env bash

# Container Operations Module
# Handles Docker command execution, container validation, error handling, and status checking

# Check if container exists
# Verifies whether a container with the specified name exists in Docker.
# Uses docker ps -a to check all containers (running and stopped).
#
# Input:
#   $1 - container_name: The name of the container to check
# Output: None
# Return code: 0 if container exists, 1 if it doesn't exist
# Example: container_exists "my-container"
container_exists() {
    local container_name="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "container_exists" "container_name=$container_name" "Container existence check"

    # More robust check that handles various container states
    local docker_output=$(docker ps -a --format "{{.Names}}")
    
    local exit_code=1  # Default to not found
    if [[ -n "$docker_output" ]]; then
        # Only run grep if there are actual containers
        echo "$docker_output" | grep -q "^$container_name$"
        exit_code=$?
    fi

    # Additional check for containers in unusual states
    if [[ $exit_code -ne 0 ]]; then
        # Check if container exists but might be in a problematic state
        local container_info=$(docker inspect "$container_name" 2>/dev/null)
        local inspect_exit_code=$?
        if [[ $inspect_exit_code -eq 0 && -n "$container_info" && "$container_info" != "[]" ]]; then
            trace_log "Container exists but may be in problematic state: $container_name" "WARN"
            exit_code=0  # Container exists, even if problematic
        else
            # Container definitely doesn't exist
            exit_code=1
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        trace_log "Container exists: $container_name" "DEBUG"
    else
        trace_log "Container does not exist: $container_name" "DEBUG"
    fi

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "container_exists" "$exit_code" "Container exists: $([[ $exit_code -eq 0 ]] && echo 'yes' || echo 'no')" "$duration"

    return $exit_code
}

# Check if container is running
# Verifies whether a container with the specified name is currently running.
# Uses docker ps to check only running containers.
#
# Input:
#   $1 - container_name: The name of the container to check
# Output: None
# Return code: 0 if container is running, 1 if it's not running
# Example: container_is_running "my-container"
container_is_running() {
    local container_name="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "container_is_running" "container_name=$container_name" "Container running status check"
    
    local result=$(docker ps --format "table {{.Names}}" | grep -q "^$container_name$")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        trace_log "Container is running: $container_name" "DEBUG"
    else
        trace_log "Container is not running: $container_name" "DEBUG"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "container_is_running" "$exit_code" "Container running: $([[ $exit_code -eq 0 ]] && echo 'yes' || echo 'no')" "$duration"
    
    return $exit_code
}

# Check if container is running (with YAML name resolution)
# Checks if a container is running by first resolving the service name to the actual
# Docker container name using the YAML file, then checking if it's running.
#
# Input:
#   $1 - service_name: The service name from the YAML file
#   $2 - yaml_file: Path to the YAML file for name resolution
# Output: None
# Return code: 0 if container is running, 1 if it's not running
# Example: container_is_running_from_yaml "web" "docker-compose.yml"
container_is_running_from_yaml() {
    local service_name="$1"
    local yaml_file="$2"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "container_is_running_from_yaml" "service_name=$service_name, yaml_file=$yaml_file" "Container running status from YAML"
    
    # Resolve the actual Docker container name from the service name
    trace_log "Resolving container name from YAML" "DEBUG"
    local container_name=$(resolve_container_name "$yaml_file" "$service_name")
    trace_log "Resolved container name: $service_name -> $container_name" "DEBUG"
    
    # Check if the resolved container name is running
    local result=$(container_is_running "$container_name")
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "container_is_running_from_yaml" "$exit_code" "Service $service_name running: $([[ $exit_code -eq 0 ]] && echo 'yes' || echo 'no')" "$duration"
    
    return $exit_code
}

# Get container status
# Retrieves the current status of a container (running, stopped, or not found).
# Provides a standardized status string for use in the application.
#
# Input:
#   $1 - container_name: The name of the container to check
# Output: Status string ("running", "stopped", or "not_found")
# Example: get_container_status "my-container"
get_container_status() {
    local container_name="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "get_container_status" "container_name=$container_name" "Container status retrieval"
    
    # Check if container exists first
    if ! container_exists "$container_name"; then
        trace_log "Container not found: $container_name" "DEBUG"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "get_container_status" "0" "not_found" "$duration"
        echo "not_found"
        return 0
    fi
    
    # Check if container is running
    if container_is_running "$container_name"; then
        trace_log "Container is running: $container_name" "DEBUG"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "get_container_status" "0" "running" "$duration"
        echo "running"
    else
        trace_log "Container is stopped: $container_name" "DEBUG"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "get_container_status" "0" "stopped" "$duration"
        echo "stopped"
    fi
}

# Get container ID
# Retrieves the Docker container ID for a given container name.
# Uses docker ps -a to get the ID from the container list.
#
# Input:
#   $1 - container_name: The name of the container
# Output: Container ID or empty string if not found
# Example: get_container_id "my-container"
get_container_id() {
    local container_name="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "get_container_id" "container_name=$container_name" "Container ID retrieval"
    
    local container_id=$(docker ps -a --format "table {{.ID}}\t{{.Names}}" | awk -v name="$container_name" '$2 == name {print $1}')
    
    if [[ -n "$container_id" ]]; then
        trace_log "Found container ID: $container_id" "DEBUG"
    else
        trace_log "Container ID not found for: $container_name" "DEBUG"
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "get_container_id" "0" "ID: $container_id" "$duration"
    
    echo "$container_id"
}

# Get container image
# Retrieves the Docker image name used by a container.
# Uses docker ps -a to get the image information.
#
# Input:
#   $1 - container_name: The name of the container
# Output: Image name or empty string if not found
# Example: get_container_image "my-container"
get_container_image() {
    local container_name="$1"
    docker ps -a --format "table {{.Image}}\t{{.Names}}" | awk -v name="$container_name" '$2 == name {print $1}'
}

# Execute Docker command with logging
# Executes a Docker command with timeout, logging, and error handling.
# This is the central function for all Docker command execution in the application.
#
# Input:
#   $1 - operation: The operation name for logging
#   $2 - container_name: The container name for logging
#   $3 - command: The Docker command to execute
#   $4 - timeout: Timeout in seconds (optional, defaults to 60)
# Output: Command output
# Return code: Exit code from the Docker command
# Example: execute_docker_command "START" "my-container" "docker start my-container" 30
execute_docker_command() {
    local operation="$1"
    local container_name="$2"
    local command="$3"
    local timeout="${4:-60}"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "execute_docker_command" "operation=$operation, container_name=$container_name, command=$command, timeout=$timeout" "Docker command execution"
    
    # Trace the command being executed
    trace_command "$command" "$operation" "$container_name"
    
    # Log the command being executed for debugging
    log_docker_command "$operation" "$container_name" "$command"
    
    # Execute command with timeout to prevent hanging
    local output
    local exit_code
    output=$(timeout "$timeout" bash -c "$command" 2>&1)
    exit_code=$?
    
    # Trace the command result
    trace_command_result "$command" "$exit_code" "$output"
    
    # Log the result for debugging and error tracking
    log_docker_result "$operation" "$container_name" "$exit_code" "$output"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "execute_docker_command" "$exit_code" "Command completed" "$duration"
    
    # Return the output and exit code
    echo "$output"
    return $exit_code
}

# Start container
# Starts a Docker container and updates the state with the new status.
# Includes comprehensive error handling and logging.
#
# Input:
#   $1 - container_name: The name of the container to start
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: start_container "my-container"
start_container() {
    local container_name="$1"
    local operation="START"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "start_container" "container_name=$container_name" "Container start operation"
    
    # Log the start of the operation
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists before attempting to start
    if ! container_exists "$container_name"; then
        trace_log "Container does not exist: $container_name" "ERROR"
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "start_container" "1" "Container does not exist" "$duration"
        return 1
    fi
    
    # Check if container is already running to avoid unnecessary operations
    if container_is_running "$container_name"; then
        trace_log "Container is already running: $container_name" "INFO"
        log_operation_success "$operation" "$container_name" "Container is already running"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "start_container" "0" "Container already running" "$duration"
        return 0
    fi
    
    # Execute the docker start command
    trace_log "Starting container: $container_name" "INFO"
    local command="docker start $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        trace_log "Container started successfully: $container_name" "INFO"
        log_operation_success "$operation" "$container_name" "Container started successfully"
        
        # Update state with new container information
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "running" "$container_id"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "start_container" "0" "Container started successfully" "$duration"
        return 0
    else
        trace_log "Failed to start container: $container_name" "ERROR"
        log_operation_failure "$operation" "$container_name" "Failed to start container"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "start_container" "$exit_code" "Failed to start container" "$duration"
        return $exit_code
    fi
}

# Stop container
# Stops a Docker container and updates the state with the new status.
# Includes comprehensive error handling and logging.
#
# Input:
#   $1 - container_name: The name of the container to stop
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: stop_container "my-container"
stop_container() {
    local container_name="$1"
    local operation="STOP"
    
    # Log the start of the operation
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists before attempting to stop
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        return 1
    fi
    
    # Check if container is already stopped to avoid unnecessary operations
    if ! container_is_running "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container is already stopped"
        return 0
    fi
    
    # Execute the docker stop command
    local command="docker stop $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container stopped successfully"
        
        # Update state with new container information
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "stopped" "$container_id"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to stop container"
        return $exit_code
    fi
}

# Remove container
# Removes a Docker container and cleans up the state.
# Stops the container first if it's running, then removes it.
#
# Input:
#   $1 - container_name: The name of the container to remove
#   $2 - force: Whether to force removal (optional, defaults to false)
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: remove_container "my-container" "true"
remove_container() {
    local container_name="$1"
    local force="${2:-false}"
    local operation="REMOVE"
    
    # Log the start of the operation
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists before attempting to remove
    if ! container_exists "$container_name"; then
        log_operation_success "$operation" "$container_name" "Container does not exist"
        return 0
    fi
    
    # Stop container if running before removal
    if container_is_running "$container_name"; then
        log_info "$operation" "$container_name" "Stopping running container before removal"
        stop_container "$container_name"
    fi
    
    # Build the docker rm command with optional force flag
    local command="docker rm $container_name"
    if [[ "$force" == "true" ]]; then
        command="docker rm -f $container_name"
    fi
    
    # Execute the removal command
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container removed successfully"
        
        # Remove container from state tracking
        remove_container_from_state "$container_name"
        
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to remove container"
        return $exit_code
    fi
}

# Create container from image
# Creates a new Docker container from an image using the specified docker run command.
# Includes image pulling, comprehensive error handling, and helpful error messages.
#
# Input:
#   $1 - container_name: The name for the new container
#   $2 - image_name: The Docker image to use
#   $3 - docker_run_cmd: The complete docker run command
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: create_container "my-container" "nginx:alpine" "docker run -d --name my-container -p 80:80 nginx:alpine"
create_container() {
    local container_name="$1"
    local image_name="$2"
    local docker_run_cmd="$3"
    local operation="CREATE"
    
    # Log the start of the operation
    log_operation_start "$operation" "$container_name"
    
    # Check if container already exists to avoid conflicts
    if container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container already exists"
        return 1
    fi
    
    # Pull image if needed (this ensures we have the latest version)
    log_info "$operation" "$container_name" "Pulling image: $image_name"
    local pull_command="docker pull $image_name"
    local pull_output=$(execute_docker_command "$operation" "$container_name" "$pull_command" 300)
    local pull_exit_code=$?
    
    if [[ $pull_exit_code -ne 0 ]]; then
        log_operation_failure "$operation" "$container_name" "Failed to pull image: $image_name - Exit code: $pull_exit_code, Output: $pull_output"
        
        # Parse common image pull errors and provide helpful messages
        if echo "$pull_output" | grep -q "manifest.*not found"; then
            print_error "❌ Image '$image_name' not found in registry"
            print_info "💡 Possible solutions:"
            print_info "   - Check if the image name and tag are correct"
            print_info "   - Verify the image exists in Docker Hub or your registry"
            print_info "   - Try running: docker pull $image_name"
            print_info "   - Check if you need to login to a private registry"
        elif echo "$pull_output" | grep -q "unauthorized"; then
            print_error "❌ Unauthorized access to image '$image_name'"
            print_info "💡 Please:"
            print_info "   - Login to the registry: docker login"
            print_info "   - Check your credentials"
            print_info "   - Verify you have access to this image"
        elif echo "$pull_output" | grep -q "network.*timeout"; then
            print_error "❌ Network timeout while pulling image '$image_name'"
            print_info "💡 Possible solutions:"
            print_info "   - Check your internet connection"
            print_info "   - Try again later"
            print_info "   - Use a different registry or mirror"
        elif echo "$pull_output" | grep -q "no space left on device"; then
            print_error "❌ Insufficient disk space to pull image '$image_name'"
            print_info "💡 Please:"
            print_info "   - Free up disk space"
            print_info "   - Clean up unused Docker images: docker system prune"
            print_info "   - Remove unused images: docker image prune -a"
        else
            print_error "❌ Failed to pull image '$image_name'"
            print_info "💡 Check the logs above for technical details"
            print_info "   Common issues:"
            print_info "   - Image doesn't exist"
            print_info "   - Network connectivity issues"
            print_info "   - Registry authentication problems"
        fi
        
        return $pull_exit_code
    fi
    
    # Create container using the provided docker run command
    local output=$(execute_docker_command "$operation" "$container_name" "$docker_run_cmd")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container created successfully"
        
        # Update state with new container information
        local container_id=$(get_container_id "$container_name")
        update_container_operation "$container_name" "$operation" "" "$container_id" "created"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to create container - Exit code: $exit_code, Output: $output, Image: $image_name"
        
        # Parse common container creation errors and provide helpful messages
        if echo "$output" | grep -q "port.*already in use"; then
            print_error "❌ Port conflict detected"
            print_info "💡 A port specified in your configuration is already in use"
            print_info "   Please change the port or stop the conflicting container"
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
        elif echo "$output" | grep -q "network.*not found"; then
            print_error "❌ Network not found"
            print_info "💡 Please create the network first:"
            print_info "   docker network create <network-name>"
        else
            print_error "❌ Failed to create container '$container_name'"
            print_info "💡 Check the logs above for technical details"
            print_info "   Common issues:"
            print_info "   - Invalid configuration"
            print_info "   - Resource constraints"
            print_info "   - Docker daemon issues"
        fi
        
        return $exit_code
    fi
}

# Restart container
# Restarts a Docker container and updates the state with the new status.
# This stops and then starts the container in one operation.
#
# Input:
#   $1 - container_name: The name of the container to restart
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: restart_container "my-container"
restart_container() {
    local container_name="$1"
    local operation="RESTART"
    
    # Log the start of the operation
    log_operation_start "$operation" "$container_name"
    
    # Check if container exists before attempting to restart
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        return 1
    fi
    
    # Execute the docker restart command
    local command="docker restart $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_operation_success "$operation" "$container_name" "Container restarted successfully"
        
        # Update state with new container information
        local container_id=$(get_container_id "$container_name")
        update_container_status "$container_name" "running" "$container_id"
        set_last_container "$container_name"
        set_last_operation "$operation"
        
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to restart container"
        return $exit_code
    fi
}

# Get container logs
# Retrieves logs from a Docker container with optional line limit.
# Includes error handling for non-existent containers.
#
# Input:
#   $1 - container_name: The name of the container
#   $2 - lines: Number of lines to retrieve (optional, defaults to 50)
# Output: Container logs
# Return code: 0 if successful, 1 if failed
# Example: get_container_logs "my-container" 100
get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    local operation="LOGS"
    
    # Check if container exists before attempting to get logs
    if ! container_exists "$container_name"; then
        log_error "$operation" "$container_name" "Container does not exist"
        return 1
    fi
    
    # Execute the docker logs command
    local command="docker logs --tail $lines $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "$operation" "$container_name" "Failed to get container logs"
        return $exit_code
    fi
}

# Get container stats
# Retrieves resource usage statistics for a Docker container.
# Shows CPU, memory, network, and disk usage information.
#
# Input:
#   $1 - container_name: The name of the container
# Output: Container statistics
# Return code: 0 if successful, 1 if failed
# Example: get_container_stats "my-container"
get_container_stats() {
    local container_name="$1"
    local operation="STATS"
    
    # Check if container exists before attempting to get stats
    if ! container_exists "$container_name"; then
        log_error "$operation" "$container_name" "Container does not exist"
        return 1
    fi
    
    # Execute the docker stats command (no-stream for single snapshot)
    local command="docker stats --no-stream $container_name"
    local output=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "$operation" "$container_name" "Failed to get container stats"
        return $exit_code
    fi
}

# Execute command in container
# Executes a command inside a running Docker container.
# Requires the container to be running for the command to succeed.
#
# Input:
#   $1 - container_name: The name of the container
#   $2 - command: The command to execute inside the container
# Output: Command output from inside the container
# Return code: 0 if successful, 1 if failed
# Example: execute_in_container "my-container" "ls -la"
execute_in_container() {
    local container_name="$1"
    local command="$2"
    local operation="EXEC"
    
    # Check if container exists before attempting to execute command
    if ! container_exists "$container_name"; then
        log_error "$operation" "$container_name" "Container does not exist"
        return 1
    fi
    
    # Check if container is running (required for exec)
    if ! container_is_running "$container_name"; then
        log_error "$operation" "$container_name" "Container is not running"
        return 1
    fi
    
    # Execute the command inside the container
    local docker_command="docker exec $container_name $command"
    local output=$(execute_docker_command "$operation" "$container_name" "$docker_command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "$operation" "$container_name" "Failed to execute command in container"
        return $exit_code
    fi
}

# List all containers
# Lists all Docker containers (running and stopped) in a formatted table.
# Shows container names, images, status, and port mappings.
#
# Input: None
# Output: Formatted container list
# Return code: 0 if successful, 1 if failed
# Example: list_all_containers
list_all_containers() {
    local operation="LIST"
    local command="docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
    local output=$(execute_docker_command "$operation" "" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "$operation" "" "Failed to list containers"
        return $exit_code
    fi
}

# List running containers
# Lists only running Docker containers in a formatted table.
# Shows container names, images, status, and port mappings.
#
# Input: None
# Output: Formatted running container list
# Return code: 0 if successful, 1 if failed
# Example: list_running_containers
list_running_containers() {
    local operation="LIST_RUNNING"
    local command="docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
    local output=$(execute_docker_command "$operation" "" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "$operation" "" "Failed to list running containers"
        return $exit_code
    fi
}

# Clean up unused containers and images
# Performs Docker system cleanup to remove unused resources.
# Includes containers, images, networks, and optionally volumes.
#
# Input:
#   $1 - remove_volumes: Whether to remove unused volumes (optional, defaults to false)
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: cleanup_docker "true"
cleanup_docker() {
    local operation="CLEANUP"
    local remove_volumes="${1:-false}"
    
    # Log the start of the cleanup operation
    log_operation_start "$operation" "" "Cleaning up Docker resources"
    
    # Remove stopped containers
    local command="docker container prune -f"
    local output=$(execute_docker_command "$operation" "" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "$operation" "" "Removed stopped containers"
    fi
    
    # Remove unused images
    command="docker image prune -f"
    output=$(execute_docker_command "$operation" "" "$command")
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "$operation" "" "Removed unused images"
    fi
    
    # Remove unused networks
    command="docker network prune -f"
    output=$(execute_docker_command "$operation" "" "$command")
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "$operation" "" "Removed unused networks"
    fi
    
    # Remove unused volumes if requested
    if [[ "$remove_volumes" == "true" ]]; then
        command="docker volume prune -f"
        output=$(execute_docker_command "$operation" "" "$command")
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_info "$operation" "" "Removed unused volumes"
        fi
    fi
    
    log_operation_success "$operation" "" "Docker cleanup completed"
    return 0
}

# Extract per-container readiness timeout from YAML using yq
# Extracts a custom readiness timeout value for a specific container from YAML.
# Looks for x-docker-ops.readiness_timeout in the service configuration.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - container_name: The name of the container
# Output: Timeout value in seconds or empty string if not set
# Example: get_container_readiness_timeout "docker-compose.yml" "web"
get_container_readiness_timeout() {
    local yaml_file="$1"
    local container_name="$2"
    if command -v yq &> /dev/null; then
        yq eval ".services.$container_name.x-docker-ops.readiness_timeout // \"\"" "$yaml_file" 2>/dev/null | grep -E '^[0-9]+$' || true
    else
        echo ""  # Fallback: not supported without yq
    fi
}

# Wait for a container to become ready (healthy or running)
# Waits for a container to reach a ready state before considering the operation complete.
# Supports health checks and configurable timeouts.
#
# Algorithm:
# 1. Container creation starts
# 2. Check for health check response, max wait time is timeout
# 3. Show waiting dots animation during the entire timeout period
# 4. Number of dots is 1/4 of the timeout value
# 5. If health check responds with "healthy" within timeout, stop animation and return success
# 6. If no health check response within timeout, check if container is running
# 7. Show appropriate message based on container status
#
# Timeout is determined in the following order:
#   1. Per-container override (YAML: x-docker-ops.readiness_timeout)
#   2. CLI flag (--timeout)
#   3. Config file/env var (DOCKER_OPS_READINESS_TIMEOUT)
#   4. Hardcoded default (60s)
#
# Input:
#   $1 - service_name: The service name from YAML (for name resolution)
#   $2 - cli_timeout: CLI timeout value (optional)
#   $3 - yaml_file: Path to YAML file for name resolution and timeout override (optional)
# Output: None
# Return code: 0 if ready, 1 if timeout
# Example: wait_for_container_ready "web" 30 "docker-compose.yml"
wait_for_container_ready() {
    local service_name="$1"
    local cli_timeout="$2"   # May be empty
    local yaml_file="$3"     # May be empty
    local operation="WAIT"
    
    # Resolve actual Docker container name from YAML
    local container_name="$service_name"
    if [[ -n "$yaml_file" ]]; then
        container_name=$(resolve_container_name "$yaml_file" "$service_name")
        log_debug "$operation" "$service_name" "Resolved container name: $service_name -> $container_name"
    fi

    # 1. Per-container YAML override
    local yaml_timeout=""
    if [[ -n "$yaml_file" ]]; then
        yaml_timeout=$(get_container_readiness_timeout "$yaml_file" "$container_name")
    fi

    # 2. CLI flag
    local timeout=""
    if [[ -n "$cli_timeout" ]]; then
        timeout="$cli_timeout"
    elif [[ -n "$yaml_timeout" ]]; then
        timeout="$yaml_timeout"
    elif [[ -n "${DOCKER_OPS_READINESS_TIMEOUT:-}" ]]; then
        timeout="$DOCKER_OPS_READINESS_TIMEOUT"
    else
        timeout=60
    fi

    # Calculate dots based on timeout (1/4 of timeout value)
    local dots_count=$((timeout / 4))
    if [[ $dots_count -lt 3 ]]; then
        dots_count=3  # Minimum 3 dots
    elif [[ $dots_count -gt 10 ]]; then
        dots_count=10  # Maximum 10 dots
    fi

    log_operation_start "$operation" "$container_name" "Waiting for container to be ready (timeout: ${timeout}s, dots: ${dots_count})"

    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))

    # Show waiting animation
    print_info "Waiting for container '$container_name' to be ready (timeout: ${timeout}s)"

    # Start signal-based animation with calculated dots
    start_signal_animation "$dots_count"

    # Poll for health check response until timeout
    local health_responded=false
    local health_status=""
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Try to get health status, but handle containers without health checks gracefully
        if docker inspect --format='{{.State.Health.Status}}' "$container_name" >/dev/null 2>&1; then
            health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)
            
            # Check if we got a valid health response (not <nil>)
            if [[ -n "$health_status" && "$health_status" != "<nil>" ]]; then
                health_responded=true
                log_debug "$operation" "$service_name" "Health check responded: $health_status"
                
                # If healthy, stop animation and return success
                if [[ "$health_status" == "healthy" ]]; then
                    stop_signal_animation
                    log_operation_success "$operation" "$container_name" "Container is healthy and ready"
                    return 0
                elif [[ "$health_status" == "unhealthy" ]]; then
                    log_debug "$operation" "$container_name" "Healthcheck reports unhealthy, continuing to wait..."
                elif [[ "$health_status" == "starting" ]]; then
                    log_debug "$operation" "$container_name" "Healthcheck is starting, continuing to wait..."
                else
                    log_debug "$operation" "$container_name" "Unknown health status: $health_status, continuing to wait..."
                fi
            else
                log_debug "$operation" "$service_name" "No health check configured or health status is <nil>"
            fi
        else
            log_debug "$operation" "$service_name" "Health check not available for container"
        fi
        
        # Small sleep to prevent busy waiting
        sleep 1
    done

    # Timeout reached - stop animation
    stop_signal_animation

    # After timeout, check if container is running and show appropriate message
    local is_running=$(container_is_running "$container_name" && echo "true" || echo "false")
    
    if [[ "$is_running" == "true" ]]; then
        if [[ "$health_responded" == "true" ]]; then
            # Health check responded but didn't become healthy within timeout
            log_operation_failure "$operation" "$container_name" "Container is running but health check did not become healthy within timeout (${timeout}s)"
            print_warning "Container '$container_name' is running but health check did not become healthy within timeout (${timeout}s)"
            return 1
        else
            # No health check configured, container is running
            log_operation_success "$operation" "$container_name" "Container is ready, but no provision for health check!!! 🐳✨"
            print_success "Container '$container_name' is ready, but no provision for health check!!! 🐳✨"
            return 0
        fi
    else
        # Container is not running
        log_operation_failure "$operation" "$container_name" "Container not ready within timeout (${timeout}s)"
        print_error "Container '$container_name' is not running after timeout (${timeout}s)"
        return 1
    fi
} 