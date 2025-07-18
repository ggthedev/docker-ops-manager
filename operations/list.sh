#!/usr/bin/env bash

# List Operations Module
# Handles listing of Docker resources (containers, images, projects)

# =============================================================================
# FUNCTION: list_containers
# =============================================================================
# Purpose: List all containers with detailed information
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
#   $2 - filter: Filter containers (running, stopped, all) (optional, defaults to all)
# Outputs: Formatted container list
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list containers" command is invoked
# Example: list_containers "table" "running"
# =============================================================================
list_containers() {
    local format="${1:-table}"
    local filter="${2:-all}"
    local operation="LIST_CONTAINERS"
    
    log_operation_start "$operation" "" "Listing containers with filter: $filter, format: $format"
    
    print_header "Docker Containers"
    
    local docker_cmd="docker ps"
    
    # Apply filter
    case "$filter" in
        "running")
            docker_cmd="docker ps"
            print_info "Showing running containers only"
            ;;
        "stopped")
            docker_cmd="docker ps -a --filter status=exited --filter status=created"
            print_info "Showing stopped containers only"
            ;;
        "all")
            docker_cmd="docker ps -a"
            print_info "Showing all containers"
            ;;
        *)
            print_warning "Unknown filter: $filter, showing all containers"
            docker_cmd="docker ps -a"
            ;;
    esac
    
    # Apply format
    case "$format" in
        "table")
            docker_cmd="$docker_cmd --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\""
            ;;
        "json")
            docker_cmd="$docker_cmd --format json"
            ;;
        "custom")
            docker_cmd="$docker_cmd --format \"{{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}\""
            ;;
        *)
            print_warning "Unknown format: $format, using default table format"
            docker_cmd="$docker_cmd --format \"table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\""
            ;;
    esac
    
    # Execute command
    local output=$(eval $docker_cmd 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            print_info "No containers found"
        fi
        log_operation_success "$operation" "" "Containers listed successfully"
    else
        print_error "Failed to list containers"
        log_operation_failure "$operation" "" "Failed to list containers"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: list_images
# =============================================================================
# Purpose: List all Docker images with detailed information
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
#   $2 - filter: Filter images (dangling, all) (optional, defaults to all)
# Outputs: Formatted image list
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list images" command is invoked
# Example: list_images "table" "all"
# =============================================================================
list_images() {
    local format="${1:-table}"
    local filter="${2:-all}"
    local operation="LIST_IMAGES"
    
    log_operation_start "$operation" "" "Listing images with filter: $filter, format: $format"
    
    print_header "Docker Images"
    
    local docker_cmd="docker images"
    
    # Apply filter
    case "$filter" in
        "dangling")
            docker_cmd="docker images --filter dangling=true"
            print_info "Showing dangling images only"
            ;;
        "all")
            docker_cmd="docker images"
            print_info "Showing all images"
            ;;
        *)
            print_warning "Unknown filter: $filter, showing all images"
            docker_cmd="docker images"
            ;;
    esac
    
    # Apply format
    case "$format" in
        "table")
            docker_cmd="$docker_cmd --format \"table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}\""
            ;;
        "json")
            docker_cmd="$docker_cmd --format json"
            ;;
        "custom")
            docker_cmd="$docker_cmd --format \"{{.Repository}}:{{.Tag}} | {{.ID}} | {{.Size}} | {{.CreatedAt}}\""
            ;;
        *)
            print_warning "Unknown format: $format, using default table format"
            docker_cmd="$docker_cmd --format \"table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}\""
            ;;
    esac
    
    # Execute command
    local output=$(eval $docker_cmd 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            print_info "No images found"
        fi
        log_operation_success "$operation" "" "Images listed successfully"
    else
        print_error "Failed to list images"
        log_operation_failure "$operation" "" "Failed to list images"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: list_projects
# =============================================================================
# Purpose: List all Docker Compose projects
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
# Outputs: Formatted project list
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list projects" command is invoked
# Example: list_projects "table"
# =============================================================================
list_projects() {
    local format="${1:-table}"
    local operation="LIST_PROJECTS"
    
    log_operation_start "$operation" "" "Listing Docker Compose projects with format: $format"
    
    print_header "Docker Compose Projects"
    
    local docker_cmd="docker compose ls"
    
    # Apply format (docker compose ls only supports table and json)
    case "$format" in
        "table")
            docker_cmd="$docker_cmd --format table"
            ;;
        "json")
            docker_cmd="$docker_cmd --format json"
            ;;
        "custom")
            print_warning "Custom format not supported for docker compose ls, using table format"
            docker_cmd="$docker_cmd --format table"
            ;;
        *)
            print_warning "Unknown format: $format, using default table format"
            docker_cmd="$docker_cmd --format table"
            ;;
    esac
    
    # Execute command
    local output=$(eval $docker_cmd 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            print_info "No Docker Compose projects found"
        fi
        log_operation_success "$operation" "" "Projects listed successfully"
    else
        print_error "Failed to list Docker Compose projects"
        log_operation_failure "$operation" "" "Failed to list projects"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: list_volumes
# =============================================================================
# Purpose: List all Docker volumes
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
# Outputs: Formatted volume list
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list volumes" command is invoked
# Example: list_volumes "table"
# =============================================================================
list_volumes() {
    local format="${1:-table}"
    local operation="LIST_VOLUMES"
    
    log_operation_start "$operation" "" "Listing Docker volumes with format: $format"
    
    print_header "Docker Volumes"
    
    local docker_cmd="docker volume ls"
    
    # Apply format
    case "$format" in
        "table")
            docker_cmd="$docker_cmd --format \"table {{.Name}}\t{{.Driver}}\""
            ;;
        "json")
            docker_cmd="$docker_cmd --format json"
            ;;
        "custom")
            docker_cmd="$docker_cmd --format \"{{.Name}} | {{.Driver}}\""
            ;;
        *)
            print_warning "Unknown format: $format, using default table format"
            docker_cmd="$docker_cmd --format \"table {{.Name}}\t{{.Driver}}\""
            ;;
    esac
    
    # Execute command
    local output=$(eval $docker_cmd 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            print_info "No volumes found"
        fi
        log_operation_success "$operation" "" "Volumes listed successfully"
    else
        print_error "Failed to list volumes"
        log_operation_failure "$operation" "" "Failed to list volumes"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: list_networks
# =============================================================================
# Purpose: List all Docker networks
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
# Outputs: Formatted network list
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list networks" command is invoked
# Example: list_networks "table"
# =============================================================================
list_networks() {
    local format="${1:-table}"
    local operation="LIST_NETWORKS"
    
    log_operation_start "$operation" "" "Listing Docker networks with format: $format"
    
    print_header "Docker Networks"
    
    local docker_cmd="docker network ls"
    
    # Apply format
    case "$format" in
        "table")
            docker_cmd="$docker_cmd --format \"table {{.Name}}\t{{.ID}}\t{{.Driver}}\t{{.Scope}}\""
            ;;
        "json")
            docker_cmd="$docker_cmd --format json"
            ;;
        "custom")
            docker_cmd="$docker_cmd --format \"{{.Name}} | {{.ID}} | {{.Driver}} | {{.Scope}}\""
            ;;
        *)
            print_warning "Unknown format: $format, using default table format"
            docker_cmd="$docker_cmd --format \"table {{.Name}}\t{{.ID}}\t{{.Driver}}\t{{.Scope}}\""
            ;;
    esac
    
    # Execute command
    local output=$(eval $docker_cmd 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$output" ]]; then
            echo "$output"
        else
            print_info "No networks found"
        fi
        log_operation_success "$operation" "" "Networks listed successfully"
    else
        print_error "Failed to list networks"
        log_operation_failure "$operation" "" "Failed to list networks"
        return 1
    fi
    
    return 0
}

# =============================================================================
# FUNCTION: list_all_resources
# =============================================================================
# Purpose: List all Docker resources (containers, images, projects, volumes, networks)
# Inputs: 
#   $1 - format: Output format (table, json, custom) (optional, defaults to table)
# Outputs: Formatted resource lists
# Side Effects: None
# Return code: 0 if successful, 1 if failed
# Usage: Called when "list all" command is invoked
# Example: list_all_resources "table"
# =============================================================================
list_all_resources() {
    local format="${1:-table}"
    local operation="LIST_ALL_RESOURCES"
    
    log_operation_start "$operation" "" "Listing all Docker resources with format: $format"
    
    print_header "Docker Resources Summary"
    
    # List containers
    print_section "Containers"
    list_containers "$format" "all"
    
    echo ""
    
    # List images
    print_section "Images"
    list_images "$format" "all"
    
    echo ""
    
    # List projects
    print_section "Docker Compose Projects"
    list_projects "$format"
    
    echo ""
    
    # List volumes
    print_section "Volumes"
    list_volumes "$format"
    
    echo ""
    
    # List networks
    print_section "Networks"
    list_networks "$format"
    
    log_operation_success "$operation" "" "All resources listed successfully"
    return 0
} 