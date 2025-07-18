#!/usr/bin/env bash

# Logs Operation Module
# Handles container log viewing

# =============================================================================
# FUNCTION: show_container_logs
# =============================================================================
# Purpose: Display container logs with configurable line count
# Inputs: 
#   $1 - container_name: Name of the container to show logs for
#   $2 - lines: Number of lines to display (optional, defaults to 50)
# Outputs: Container logs to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves logs from Docker
#   - Displays formatted log output
# Return code: 0 if successful, 1 if failed
# Usage: Called by main script when "logs" operation is requested
# Example: show_container_logs "my-app" 100
# =============================================================================
show_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    local operation="LOGS"
    
    log_operation_start "$operation" "$container_name" "Showing container logs"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get container logs
    local logs=$(get_container_logs "$container_name" "$lines")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_header "Container Logs: $container_name (last $lines lines)"
        echo "$logs"
        log_operation_success "$operation" "$container_name" "Logs displayed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to get container logs"
        print_error "Failed to get logs for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: show_container_logs_with_timestamps
# =============================================================================
# Purpose: Display container logs with timestamps for better debugging
# Inputs: 
#   $1 - container_name: Name of the container to show logs for
#   $2 - lines: Number of lines to display (optional, defaults to 50)
# Outputs: Container logs with timestamps to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves logs with timestamps from Docker
#   - Displays formatted log output with timestamps
# Return code: 0 if successful, 1 if failed
# Usage: Called when timestamped logs are needed for debugging
# Example: show_container_logs_with_timestamps "my-app" 100
# =============================================================================
show_container_logs_with_timestamps() {
    local container_name="$1"
    local lines="${2:-50}"
    local operation="LOGS_TIMESTAMP"
    
    log_operation_start "$operation" "$container_name" "Showing container logs with timestamps"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get container logs with timestamps
    local command="docker logs --timestamps --tail $lines $container_name"
    local logs=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_header "Container Logs with Timestamps: $container_name (last $lines lines)"
        echo "$logs"
        log_operation_success "$operation" "$container_name" "Logs with timestamps displayed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to get container logs with timestamps"
        print_error "Failed to get logs with timestamps for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: follow_container_logs
# =============================================================================
# Purpose: Follow container logs in real-time (streaming mode)
# Inputs: 
#   $1 - container_name: Name of the container to follow logs for
# Outputs: Real-time container logs to stdout
# Side Effects: 
#   - Validates container existence and running status
#   - Starts real-time log streaming
#   - Blocks until interrupted by user
# Return code: 0 if successful, 1 if failed
# Usage: Called when real-time log monitoring is needed
# Example: follow_container_logs "my-app"
# Note: This function blocks until Ctrl+C is pressed
# =============================================================================
follow_container_logs() {
    local container_name="$1"
    local operation="LOGS_FOLLOW"
    
    log_operation_start "$operation" "$container_name" "Following container logs"
    
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
    
    print_header "Following Container Logs: $container_name"
    print_info "Press Ctrl+C to stop following logs"
    
    # Follow container logs
    local command="docker logs --follow --timestamps $container_name"
    log_docker_command "$operation" "$container_name" "$command"
    
    # Execute the command (this will block until interrupted)
    eval "$command"
    
    log_operation_success "$operation" "$container_name" "Log following stopped"
}

# =============================================================================
# FUNCTION: show_container_logs_since
# =============================================================================
# Purpose: Display container logs from a specific time onwards
# Inputs: 
#   $1 - container_name: Name of the container to show logs for
#   $2 - since_time: Time to start from (e.g., "1h", "30m", "2023-01-01T10:00:00")
# Outputs: Container logs from specified time to stdout
# Side Effects: 
#   - Validates container existence and time format
#   - Retrieves logs from specified time
#   - Displays formatted log output
# Return code: 0 if successful, 1 if failed
# Usage: Called when logs from a specific time are needed
# Example: show_container_logs_since "my-app" "1h"
# =============================================================================
show_container_logs_since() {
    local container_name="$1"
    local since_time="$2"
    local operation="LOGS_SINCE"
    
    log_operation_start "$operation" "$container_name" "Showing container logs since $since_time"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Validate time format
    if [[ -z "$since_time" ]]; then
        print_error "Time parameter is required"
        print_info "Use format: YYYY-MM-DDTHH:MM:SS or relative time like '1h', '30m', etc."
        return 1
    fi
    
    # Get container logs since specific time
    local command="docker logs --since '$since_time' --timestamps $container_name"
    local logs=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_header "Container Logs Since $since_time: $container_name"
        echo "$logs"
        log_operation_success "$operation" "$container_name" "Logs since $since_time displayed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to get container logs since $since_time"
        print_error "Failed to get logs since $since_time for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: show_container_logs_between
# =============================================================================
# Purpose: Display container logs within a specific time range
# Inputs: 
#   $1 - container_name: Name of the container to show logs for
#   $2 - since_time: Start time for the range
#   $3 - until_time: End time for the range
# Outputs: Container logs within time range to stdout
# Side Effects: 
#   - Validates container existence and time parameters
#   - Retrieves logs within specified time range
#   - Displays formatted log output
# Return code: 0 if successful, 1 if failed
# Usage: Called when logs within a specific time window are needed
# Example: show_container_logs_between "my-app" "1h" "30m"
# =============================================================================
show_container_logs_between() {
    local container_name="$1"
    local since_time="$2"
    local until_time="$3"
    local operation="LOGS_BETWEEN"
    
    log_operation_start "$operation" "$container_name" "Showing container logs between $since_time and $until_time"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Validate time parameters
    if [[ -z "$since_time" || -z "$until_time" ]]; then
        print_error "Both since and until time parameters are required"
        print_info "Use format: YYYY-MM-DDTHH:MM:SS or relative time like '1h', '30m', etc."
        return 1
    fi
    
    # Get container logs between time range
    local command="docker logs --since '$since_time' --until '$until_time' --timestamps $container_name"
    local logs=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_header "Container Logs Between $since_time and $until_time: $container_name"
        echo "$logs"
        log_operation_success "$operation" "$container_name" "Logs between time range displayed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to get container logs between time range"
        print_error "Failed to get logs between $since_time and $until_time for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: show_container_logs_details
# =============================================================================
# Purpose: Display container logs with additional details (extra attributes)
# Inputs: 
#   $1 - container_name: Name of the container to show logs for
#   $2 - lines: Number of lines to display (optional, defaults to 50)
# Outputs: Container logs with details to stdout
# Side Effects: 
#   - Validates container existence
#   - Retrieves logs with additional details from Docker
#   - Displays formatted log output with extra information
# Return code: 0 if successful, 1 if failed
# Usage: Called when detailed log information is needed
# Example: show_container_logs_details "my-app" 100
# =============================================================================
show_container_logs_details() {
    local container_name="$1"
    local lines="${2:-50}"
    local operation="LOGS_DETAILS"
    
    log_operation_start "$operation" "$container_name" "Showing container logs with details"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Get container logs with details
    local command="docker logs --timestamps --details --tail $lines $container_name"
    local logs=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_header "Container Logs with Details: $container_name (last $lines lines)"
        echo "$logs"
        log_operation_success "$operation" "$container_name" "Logs with details displayed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to get container logs with details"
        print_error "Failed to get logs with details for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: export_container_logs
# =============================================================================
# Purpose: Export container logs to a file for analysis or backup
# Inputs: 
#   $1 - container_name: Name of the container to export logs from
#   $2 - output_file: Path to the output file (optional, auto-generated if not provided)
#   $3 - lines: Number of lines to export (optional, defaults to "all")
# Outputs: Container logs written to specified file
# Side Effects: 
#   - Validates container existence
#   - Creates or overwrites output file
#   - Writes logs to filesystem
# Return code: 0 if successful, 1 if failed
# Usage: Called when logs need to be saved to a file
# Example: export_container_logs "my-app" "logs.txt" 1000
# =============================================================================
export_container_logs() {
    local container_name="$1"
    local output_file="$2"
    local lines="${3:-all}"
    local operation="LOGS_EXPORT"
    
    log_operation_start "$operation" "$container_name" "Exporting container logs to $output_file"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Validate output file
    if [[ -z "$output_file" ]]; then
        output_file="${container_name}_logs_$(date +%Y%m%d_%H%M%S).log"
    fi
    
    # Get container logs
    local command="docker logs --timestamps $container_name"
    if [[ "$lines" != "all" ]]; then
        command="docker logs --timestamps --tail $lines $container_name"
    fi
    
    local logs=$(execute_docker_command "$operation" "$container_name" "$command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Write logs to file
        echo "$logs" > "$output_file"
        
        log_operation_success "$operation" "$container_name" "Logs exported to $output_file successfully"
        print_success "Container logs exported to: $output_file"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to export container logs"
        print_error "Failed to export logs for container '$container_name'"
        return $exit_code
    fi
}

# =============================================================================
# FUNCTION: show_multiple_containers_logs
# =============================================================================
# Purpose: Display logs for multiple containers in sequence
# Inputs: 
#   $@ - containers: Array of container names and optional line count
# Outputs: Logs for each container to stdout
# Side Effects: 
#   - Validates each container existence
#   - Displays logs for each container
#   - Continues even if some containers fail
# Return code: 0 if successful, 1 if failed
# Usage: Called when logs from multiple containers are needed
# Example: show_multiple_containers_logs "web" "db" "cache" 50
# =============================================================================
show_multiple_containers_logs() {
    local containers=("$@")
    local lines="${containers[-1]}"
    unset "containers[-1]"
    local operation="LOGS_MULTIPLE"
    
    log_operation_start "$operation" "" "Showing logs for multiple containers"
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        print_error "No containers specified"
        return 1
    fi
    
    # Default lines if not specified
    if [[ -z "$lines" || ! "$lines" =~ ^[0-9]+$ ]]; then
        lines=50
    fi
    
    for container_name in "${containers[@]}"; do
        print_header "Logs for Container: $container_name"
        
        if show_container_logs "$container_name" "$lines"; then
            echo
        else
            print_warning "Failed to get logs for container: $container_name"
        fi
    done
    
    log_operation_success "$operation" "" "Logs for multiple containers displayed"
}

# =============================================================================
# FUNCTION: search_container_logs
# =============================================================================
# Purpose: Search container logs for specific patterns or text
# Inputs: 
#   $1 - container_name: Name of the container to search logs in
#   $2 - search_pattern: Pattern or text to search for
#   $3 - lines: Number of lines to search in (optional, defaults to 100)
# Outputs: Matching log lines to stdout
# Side Effects: 
#   - Validates container existence and search pattern
#   - Retrieves logs and performs pattern matching
#   - Displays matching lines
# Return code: 0 if successful, 1 if failed
# Usage: Called when specific log entries need to be found
# Example: search_container_logs "my-app" "ERROR" 500
# =============================================================================
search_container_logs() {
    local container_name="$1"
    local search_pattern="$2"
    local lines="${3:-100}"
    local operation="LOGS_SEARCH"
    
    log_operation_start "$operation" "$container_name" "Searching container logs for pattern: $search_pattern"
    
    # Check if container exists
    if ! container_exists "$container_name"; then
        log_operation_failure "$operation" "$container_name" "Container does not exist"
        print_error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Validate search pattern
    if [[ -z "$search_pattern" ]]; then
        print_error "Search pattern is required"
        return 1
    fi
    
    # Get container logs and search
    local logs=$(get_container_logs "$container_name" "$lines")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local matching_logs=$(echo "$logs" | grep -i "$search_pattern" || true)
        
        if [[ -n "$matching_logs" ]]; then
            print_header "Container Logs Matching '$search_pattern': $container_name"
            echo "$matching_logs"
        else
            print_info "No logs found matching pattern: $search_pattern"
        fi
        
        log_operation_success "$operation" "$container_name" "Log search completed successfully"
        return 0
    else
        log_operation_failure "$operation" "$container_name" "Failed to search container logs"
        print_error "Failed to search logs for container '$container_name'"
        return $exit_code
    fi
} 