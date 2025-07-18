#!/usr/bin/env bash

# Docker Ops Manager - Main Script
# A comprehensive Docker operations management tool
# 
# Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)
# Licensed under MIT License with Attribution Requirement
# 
# Copyright (c) 2024 Gaurav Gupta
# 
# This software is provided "as is", without warranty of any kind.
# See LICENSE file for complete license terms.

set -euo pipefail

# Set up cleanup trap for animation
trap cleanup_animation EXIT INT TERM

# Script information
SCRIPT_NAME="docker_mgr.sh"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all library modules
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/yaml_parser.sh"
source "$SCRIPT_DIR/lib/container_ops.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/tracing.sh"

# Global variables
OPERATION=""
CONTAINER_NAMES=()  # Array to store multiple container names
YAML_FILES=()       # Array to store multiple YAML files
FORCE=false
TIMEOUT=60
LOG_LEVEL=""
TRACE_ENABLED=false

# =============================================================================
# FUNCTION: initialize_system
# =============================================================================
# Purpose: Initialize the Docker Ops Manager system by setting up configuration,
#          logging, state management, and validating system requirements
# Inputs: None (uses global variables)
# Outputs: None (side effects: initializes config, logging, state)
# Side Effects: 
#   - Creates configuration directory and file if they don't exist
#   - Initializes logging system with specified log level
#   - Creates state file if it doesn't exist
#   - Validates system configuration and exits if validation fails
# Usage: Called automatically during script startup
# =============================================================================
initialize_system() {
    # print_header "Docker Ops Manager v$SCRIPT_VERSION"
    # print_info "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
    # print_info "Licensed under MIT License with Attribution Requirement"
    
    # Load configuration
    load_config
    init_config_file
    
    # Initialize logging
    init_logging "$LOG_LEVEL"
    
    # Initialize tracing if enabled
    if [[ "$TRACE_ENABLED" == "true" ]]; then
        init_tracing "true"
    fi
    
    # Initialize state
    init_state_file
    
    # Validate system requirements
    local validation_errors=$(validate_config)
    if [[ -n "$validation_errors" ]]; then
        print_error "System validation failed:"
        echo "$validation_errors"
        exit 1
    fi
    
    log_info "INIT" "" "System initialized successfully"
    
    # Log tracing status
    if [[ "$TRACE_ENABLED" == "true" ]]; then
        log_info "INIT" "" "Tracing enabled - detailed method tracking active"
    fi
}

# =============================================================================
# FUNCTION: parse_arguments
# =============================================================================
# Purpose: Parse command line arguments and set global variables accordingly
# Inputs: 
#   - args: Array of command line arguments
# Outputs: None (side effects: sets global variables OPERATION, CONTAINER_NAME, 
#          YAML_FILE, FORCE, TIMEOUT, LOG_LEVEL)
# Side Effects:
#   - Sets global variables based on parsed arguments
#   - Exits with error if invalid options are provided
#   - Exits with help if --help is specified
#   - Exits with version if --version is specified
# Usage: Called automatically during script startup with all command line args
# =============================================================================
parse_arguments() {
    local args=("$@")
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"
        
        case "$arg" in
            --help|-h)
                print_help
                exit 0
                ;;
            --version|-v)
                echo "Docker Ops Manager v$SCRIPT_VERSION"
                echo "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
                echo "Licensed under MIT License with Attribution Requirement"
                echo "Copyright (c) 2024 Gaurav Gupta"
                exit 0
                ;;
            --yaml)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    YAML_FILES+=("${args[$((i+1))]}")
                    i=$((i+2))
                else
                    print_error "Missing value for --yaml option"
                    exit 1
                fi
                ;;
            --force)
                FORCE=true
                i=$((i+1))
                ;;
            --timeout)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    TIMEOUT="${args[$((i+1))]}"
                    i=$((i+2))
                else
                    print_error "Missing value for --timeout option"
                    exit 1
                fi
                ;;
            --log-level)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    LOG_LEVEL="${args[$((i+1))]}"
                    i=$((i+2))
                else
                    print_error "Missing value for --log-level option"
                    exit 1
                fi
                ;;
            --trace)
                TRACE_ENABLED=true
                i=$((i+1))
                ;;
            --all)
                # Special case for cleanup operation - treat as positional argument
                if [[ ${#CONTAINER_NAMES[@]} -eq 0 ]]; then
                    CONTAINER_NAMES+=("$arg")
                else
                    print_error "Too many arguments"
                    exit 1
                fi
                i=$((i+1))
                ;;
            --*)
                print_error "Unknown option: $arg"
                exit 1
                ;;
            *)
                if [[ -z "$OPERATION" ]]; then
                    OPERATION="$arg"
                elif [[ "$OPERATION" == "generate" ]]; then
                    # For generate operation, collect all YAML files
                    YAML_FILES+=("$arg")
                elif [[ "$OPERATION" == "list" ]]; then
                    # For list operation, treat as resource type
                    CONTAINER_NAMES+=("$arg")
                else
                    # Container names for other operations
                    CONTAINER_NAMES+=("$arg")
                fi
                i=$((i+1))
                ;;
        esac
    done
}

# =============================================================================
# FUNCTION: validate_operation
# =============================================================================
# Purpose: Validate that the specified operation is supported by the script
# Inputs: None (uses global variable OPERATION)
# Outputs: None
# Side Effects: Exits with error if operation is invalid
# Usage: Called automatically after argument parsing
# =============================================================================
validate_operation() {
    local valid_operations=(
        "generate" "install" "reinstall" "start" "run" "stop" "restart"
        "cleanup" "nuke" "status" "logs" "list" "config" "state" "env" "help"
    )
    
    for op in "${valid_operations[@]}"; do
        if [[ "$OPERATION" == "$op" ]]; then
            return 0
        fi
    done
    
    print_error "Invalid operation: $OPERATION"
    print_info "Use 'help' to see available operations"
    exit 1
}

# =============================================================================
# FUNCTION: get_target_containers
# =============================================================================
# Purpose: Determine the target container names from arguments or last used container
# Inputs: None (uses global variables CONTAINER_NAMES)
# Outputs: Container names as array
# Side Effects: Exits with error if no container can be determined
# Usage: Called by operation handlers to get the target containers
# =============================================================================
get_target_containers() {
    if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
        echo "${CONTAINER_NAMES[@]}"
    else
        local last_container=$(get_last_container)
        if [[ -n "$last_container" ]]; then
            echo "$last_container"
        else
            print_error "No container specified and no last container found"
            print_info "Use 'list' to see available containers or specify a container name"
            exit 1
        fi
    fi
}

# =============================================================================
# FUNCTION: get_target_container
# =============================================================================
# Purpose: Get a single target container (for backward compatibility)
# Inputs: None (uses global variables CONTAINER_NAMES)
# Outputs: First container name as string
# Side Effects: Exits with error if no container can be determined
# Usage: Called by operation handlers that need a single container
# =============================================================================
get_target_container() {
    local containers=($(get_target_containers))
    echo "${containers[0]}"
}

# =============================================================================
# FUNCTION: route_operation
# =============================================================================
# Purpose: Route the specified operation to the appropriate handler function
# Inputs: None (uses global variable OPERATION)
# Outputs: None
# Side Effects: Calls appropriate operation handler, may exit script
# Usage: Called automatically after operation validation
# =============================================================================
route_operation() {
    case "$OPERATION" in
        "generate")
            handle_generate
            ;;
        "install")
            handle_install
            ;;
        "reinstall")
            handle_reinstall
            ;;
        "start"|"run")
            handle_start
            ;;
        "stop")
            handle_stop
            ;;
        "restart")
            handle_restart
            ;;
        "cleanup")
            # Check for --all flag to cleanup state-managed containers only
            if [[ ${#CONTAINER_NAMES[@]} -eq 1 && "${CONTAINER_NAMES[0]}" == "--all" ]]; then
                print_section "Cleaning up all state-managed containers"
                source "$SCRIPT_DIR/operations/cleanup.sh"
                cleanup_state_managed_containers "$FORCE"
            elif [[ ${#CONTAINER_NAMES[@]} -eq 1 && "${CONTAINER_NAMES[0]}" == "all" ]]; then
                print_section "Full Docker System Cleanup"
                # Call the full system cleanup function from the cleanup module
                source "$SCRIPT_DIR/operations/cleanup.sh"
                full_system_cleanup "$FORCE"
            elif [[ ${#CONTAINER_NAMES[@]} -gt 1 ]]; then
                # Multiple containers specified
                print_section "Cleaning up multiple containers"
                source "$SCRIPT_DIR/operations/cleanup.sh"
                cleanup_multiple_containers "${CONTAINER_NAMES[@]}" "$FORCE"
            else
                local container_name=$(get_target_container)
                print_section "Cleaning up container: $container_name"
                source "$SCRIPT_DIR/operations/cleanup.sh"
                cleanup_container "$container_name" "$FORCE"
            fi
            ;;
        "nuke")
            print_section "Nuke Docker System"
            source "$SCRIPT_DIR/operations/cleanup.sh"
            nuke_docker_system "$FORCE"
            ;;
        "status")
            handle_status
            ;;
        "logs")
            handle_logs
            ;;
        "list")
            handle_list
            ;;
        "config")
            handle_config
            ;;
        "state")
            handle_state
            ;;
        "env")
            handle_env
            ;;
        "help")
            print_help
            ;;
        *)
            print_error "Unknown operation: $OPERATION"
            exit 1
            ;;
    esac
}

# =============================================================================
# FUNCTION: handle_generate
# =============================================================================
# Purpose: Handle the generate operation to create containers from YAML files
# Inputs: None (uses global variables YAML_FILES, CONTAINER_NAMES)
# Outputs: None
# Side Effects: 
#   - Exits if YAML file is not specified or invalid
#   - Extracts container name from YAML if not provided
#   - Sources and calls generate operation module
# Usage: Called by route_operation when operation is "generate"
# =============================================================================
handle_generate() {
    if [[ ${#YAML_FILES[@]} -eq 0 ]]; then
        print_error "YAML file is required for generate operation"
        print_info "Use --yaml <file> or provide as first argument"
        exit 1
    fi
    
    # Validate all YAML files
    for yaml_file in "${YAML_FILES[@]}"; do
        if ! validate_file_path "$yaml_file" "YAML file"; then
            exit 1
        fi
    done
    
    if [[ ${#YAML_FILES[@]} -eq 1 ]]; then
        # Single YAML file - use existing logic
        local yaml_file="${YAML_FILES[0]}"
        local container_name=""
        if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
            container_name="${CONTAINER_NAMES[0]}"
        fi
        
        if [[ -z "$container_name" ]]; then
            # Extract container name from YAML
            local yaml_type=$(detect_yaml_type "$yaml_file")
            local containers=$(extract_container_names "$yaml_file" "$yaml_type" | head -1)
            if [[ -n "$containers" ]]; then
                container_name="$containers"
            else
                print_error "Could not extract container name from YAML file"
                exit 1
            fi
        fi
        
        print_section "Generating container from YAML"
        parse_yaml_summary "$yaml_file"
        
        # Execute generate operation
        source "$SCRIPT_DIR/operations/generate.sh"
        generate_from_yaml "$yaml_file" "$container_name"
    else
        # Multiple YAML files
        print_section "Generating containers from multiple YAML files"
        
        source "$SCRIPT_DIR/operations/generate.sh"
        
        local success_count=0
        local total_count=${#YAML_FILES[@]}
        
        for yaml_file in "${YAML_FILES[@]}"; do
            print_info "Processing YAML file: $yaml_file"
            parse_yaml_summary "$yaml_file"
            
            # Extract container name from YAML
            local yaml_type=$(detect_yaml_type "$yaml_file")
            local containers=$(extract_container_names "$yaml_file" "$yaml_type" | head -1)
            local container_name=""
            
            if [[ -n "$containers" ]]; then
                container_name="$containers"
            else
                print_error "Could not extract container name from YAML file: $yaml_file"
                continue
            fi
            
            if generate_from_yaml "$yaml_file" "$container_name"; then
                success_count=$((success_count + 1))
            fi
        done
        
        # Summary
        if [[ $success_count -eq $total_count ]]; then
            print_success "All $total_count YAML files processed successfully"
        else
            print_warning "Processed $success_count out of $total_count YAML files successfully"
        fi
    fi
}

# =============================================================================
# FUNCTION: handle_install
# =============================================================================
# Purpose: Handle the install operation to install/update containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls install operation module
# Usage: Called by route_operation when operation is "install"
# =============================================================================
handle_install() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Installing container: $container_name"
        
        source "$SCRIPT_DIR/operations/install.sh"
        install_container "$container_name"
    else
        print_section "Installing multiple containers"
        
        source "$SCRIPT_DIR/operations/install.sh"
        install_multiple_containers "${containers[@]}"
    fi
}

# =============================================================================
# FUNCTION: handle_reinstall
# =============================================================================
# Purpose: Handle the reinstall operation to completely reinstall containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls reinstall operation module
# Usage: Called by route_operation when operation is "reinstall"
# =============================================================================
handle_reinstall() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Reinstalling container: $container_name"
        
        source "$SCRIPT_DIR/operations/install.sh"
        reinstall_container "$container_name"
    else
        print_section "Reinstalling multiple containers"
        
        source "$SCRIPT_DIR/operations/install.sh"
        reinstall_multiple_containers "${containers[@]}"
    fi
}

# =============================================================================
# FUNCTION: handle_start
# =============================================================================
# Purpose: Handle the start/run operation to start containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls start operation module
# Usage: Called by route_operation when operation is "start" or "run"
# =============================================================================
handle_start() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Starting container: $container_name"
        
        source "$SCRIPT_DIR/operations/start.sh"
        start_container_operation "$container_name"
    else
        print_section "Starting multiple containers"
        
        source "$SCRIPT_DIR/operations/start.sh"
        start_multiple_containers "${containers[@]}"
    fi
}

# =============================================================================
# FUNCTION: handle_stop
# =============================================================================
# Purpose: Handle the stop operation to stop containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls stop operation module
# Usage: Called by route_operation when operation is "stop"
# =============================================================================
handle_stop() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Stopping container: $container_name"
        
        source "$SCRIPT_DIR/operations/stop.sh"
        stop_container_operation "$container_name"
    else
        print_section "Stopping multiple containers"
        
        source "$SCRIPT_DIR/operations/stop.sh"
        stop_multiple_containers "${containers[@]}"
    fi
}

# =============================================================================
# FUNCTION: handle_restart
# =============================================================================
# Purpose: Handle the restart operation to restart containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Calls restart_container function from container_ops module
# Usage: Called by route_operation when operation is "restart"
# =============================================================================
handle_restart() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Restarting container: $container_name"
        
        restart_container "$container_name"
    else
        print_section "Restarting multiple containers"
        
        local success_count=0
        local total_count=${#containers[@]}
        
        for container_name in "${containers[@]}"; do
            print_info "Restarting container: $container_name"
            if restart_container "$container_name"; then
                success_count=$((success_count + 1))
            fi
        done
        
        # Summary
        if [[ $success_count -eq $total_count ]]; then
            print_success "All $total_count containers restarted successfully"
        else
            print_warning "Restarted $success_count out of $total_count containers"
        fi
    fi
}

# =============================================================================
# FUNCTION: handle_cleanup
# =============================================================================
# Purpose: Handle the cleanup operation to remove containers and images
# Inputs: None (uses global variables CONTAINER_NAME, FORCE)
# Outputs: None
# Side Effects: 
#   - Sources and calls cleanup operation module
#   - Handles both single container cleanup and full system cleanup
# Usage: Called by route_operation when operation is "cleanup"
# =============================================================================
handle_cleanup() {
    if [[ "$CONTAINER_NAME" == "--all" ]]; then
        print_section "Cleaning up all Docker resources"
        cleanup_docker "$FORCE"
    else
        local container_name=$(get_target_container)
        print_section "Cleaning up container: $container_name"
        
        source "$SCRIPT_DIR/operations/cleanup.sh"
        cleanup_container "$container_name" "$FORCE"
    fi
}

# =============================================================================
# FUNCTION: handle_status
# =============================================================================
# Purpose: Handle the status operation to show container status information
# Inputs: None (uses global variable CONTAINER_NAMES)
# Outputs: None
# Side Effects: 
#   - Shows overview if no container specified
#   - Sources and calls status operation module for specific container(s)
# Usage: Called by route_operation when operation is "status"
# =============================================================================
handle_status() {
    if [[ ${#CONTAINER_NAMES[@]} -eq 0 ]]; then
        print_section "Container Status Overview"
        list_all_containers
    elif [[ ${#CONTAINER_NAMES[@]} -eq 1 ]]; then
        local container_name="${CONTAINER_NAMES[0]}"
        print_section "Status for container: $container_name"
        
        source "$SCRIPT_DIR/operations/status.sh"
        show_container_status "$container_name"
    else
        print_section "Status for multiple containers"
        
        source "$SCRIPT_DIR/operations/status.sh"
        
        for container_name in "${CONTAINER_NAMES[@]}"; do
            print_info "Status for container: $container_name"
            show_container_status "$container_name"
            echo ""
        done
    fi
}

# =============================================================================
# FUNCTION: handle_logs
# =============================================================================
# Purpose: Handle the logs operation to show container logs
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls logs operation module
# Usage: Called by route_operation when operation is "logs"
# =============================================================================
handle_logs() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Logs for container: $container_name"
        
        source "$SCRIPT_DIR/operations/logs.sh"
        show_container_logs "$container_name"
    else
        print_section "Logs for multiple containers"
        
        source "$SCRIPT_DIR/operations/logs.sh"
        show_multiple_containers_logs "${containers[@]}"
    fi
}

# =============================================================================
# FUNCTION: handle_list
# =============================================================================
# Purpose: Handle the list operation to show Docker resources
# Inputs: None (uses global variable CONTAINER_NAMES for resource type)
# Outputs: None
# Side Effects: Calls appropriate list function based on resource type
# Usage: Called by route_operation when operation is "list"
# =============================================================================
handle_list() {
    source "$SCRIPT_DIR/operations/list.sh"
    
    local resource_type="all"
    if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
        resource_type="${CONTAINER_NAMES[0]}"
    fi
    local format="table"
    
    case "$resource_type" in
        "containers"|"container")
            list_containers "$format" "all"
            ;;
        "images"|"image")
            list_images "$format" "all"
            ;;
        "projects"|"project")
            list_projects "$format"
            ;;
        "volumes"|"volume")
            list_volumes "$format"
            ;;
        "networks"|"network")
            list_networks "$format"
            ;;
        "all"|"")
            list_all_resources "$format"
            ;;
        *)
            print_error "Unknown resource type: $resource_type"
            print_info "Available resource types: containers, images, projects, volumes, networks, all"
            exit 1
            ;;
    esac
}

# =============================================================================
# FUNCTION: handle_config
# =============================================================================
# Purpose: Handle the config operation to show configuration information
# Inputs: None
# Outputs: None
# Side Effects: Calls print_config to display configuration
# Usage: Called by route_operation when operation is "config"
# =============================================================================
handle_config() {
    print_section "Configuration"
    print_config
}

# =============================================================================
# FUNCTION: handle_state
# =============================================================================
# Purpose: Handle the state operation to show state information
# Inputs: None
# Outputs: None
# Side Effects: Calls get_state_summary to display state information
# Usage: Called by route_operation when operation is "state"
# =============================================================================
handle_state() {
    print_section "State Information"
    get_state_summary
}

# =============================================================================
# FUNCTION: handle_env
# =============================================================================
# Purpose: Handle the env operation to show environment information
# Inputs: None
# Outputs: None
# Side Effects: Displays environment variables and directory locations
# Usage: Called by route_operation when operation is "env"
# =============================================================================
handle_env() {
    print_section "Environment Information"
    
    # Get configuration values
    local config_dir="${DOCKER_OPS_CONFIG_DIR:-~/.config/docker-ops-manager}"
    local log_dir="${DOCKER_OPS_LOG_DIR:-~/.config/docker-ops-manager/logs}"
    local state_file="${DOCKER_OPS_STATE_FILE:-~/.config/docker-ops-manager/state.json}"
    local config_file="${DOCKER_OPS_CONFIG_FILE:-~/.config/docker-ops-manager/config.json}"
    local max_history="${DOCKER_OPS_MAX_CONTAINER_HISTORY:-10}"
    local project_pattern="${DOCKER_OPS_PROJECT_NAME_PATTERN:-project-<service.name>-<DD-MM-YY>}"
    
    # Expand tilde to home directory
    config_dir=$(eval echo "$config_dir")
    log_dir=$(eval echo "$log_dir")
    state_file=$(eval echo "$state_file")
    config_file=$(eval echo "$config_file")
    
    # Get temp directory for docker-compose files
    local temp_dir="/tmp/docker-ops-manager"
    
    echo "Directory Locations:"
    echo "  Configuration Directory: $config_dir"
    echo "  Log Directory:          $log_dir"
    echo "  State File:             $state_file"
    echo "  Config File:            $config_file"
    echo "  Temp Directory:         $temp_dir"
    echo ""
    
    echo "Environment Variables:"
    echo "  DOCKER_OPS_CONFIG_DIR:              ${DOCKER_OPS_CONFIG_DIR:-<not set>}"
    echo "  DOCKER_OPS_LOG_DIR:                 ${DOCKER_OPS_LOG_DIR:-<not set>}"
    echo "  DOCKER_OPS_LOG_LEVEL:               ${DOCKER_OPS_LOG_LEVEL:-<not set>}"
    echo "  DOCKER_OPS_STATE_FILE:              ${DOCKER_OPS_STATE_FILE:-<not set>}"
    echo "  DOCKER_OPS_CONFIG_FILE:             ${DOCKER_OPS_CONFIG_FILE:-<not set>}"
    echo "  DOCKER_OPS_MAX_CONTAINER_HISTORY:   ${DOCKER_OPS_MAX_CONTAINER_HISTORY:-<not set>}"
    echo "  DOCKER_OPS_PROJECT_NAME_PATTERN:    ${DOCKER_OPS_PROJECT_NAME_PATTERN:-<not set>}"
    echo ""
    
    echo "Current Values (with defaults):"
    echo "  Configuration Directory: $config_dir"
    echo "  Log Directory:          $log_dir"
    echo "  State File:             $state_file"
    echo "  Config File:            $config_file"
    echo "  Max Container History:  $max_history"
    echo "  Project Name Pattern:   $project_pattern"
    echo ""
    
    # Check if directories exist
    echo "Directory Status:"
    if [[ -d "$config_dir" ]]; then
        echo "  ✓ Configuration Directory exists"
    else
        echo "  ✗ Configuration Directory does not exist"
    fi
    
    if [[ -d "$log_dir" ]]; then
        echo "  ✓ Log Directory exists"
    else
        echo "  ✗ Log Directory does not exist"
    fi
    
    if [[ -d "$temp_dir" ]]; then
        echo "  ✓ Temp Directory exists"
    else
        echo "  ✗ Temp Directory does not exist"
    fi
    
    # Check if files exist
    echo ""
    echo "File Status:"
    if [[ -f "$state_file" ]]; then
        echo "  ✓ State File exists"
    else
        echo "  ✗ State File does not exist"
    fi
    
    if [[ -f "$config_file" ]]; then
        echo "  ✓ Config File exists"
    else
        echo "  ✗ Config File does not exist"
    fi
}

# =============================================================================
# FUNCTION: print_help
# =============================================================================
# Purpose: Display comprehensive help information for the Docker Ops Manager
# Inputs: None
# Outputs: Help text to stdout
# Side Effects: None
# Usage: Called when --help is specified or operation is "help"
# =============================================================================
print_help() {
    echo "Docker Ops Manager - A comprehensive Docker operations management tool"
    echo
    echo "Usage: ./docker_ops_manager.sh [OPERATION] [OPTIONS] [CONTAINER_NAME]"
    echo
    echo "Operations:"
    echo "  generate <yaml_file> [yaml_file2...]    Generate containers from YAML files"
    echo "  install [container_name] [container2...] Install/update containers"
    echo "  reinstall [container_name] [container2...] Reinstall containers"
    echo "  start|run [container_name] [container2...] Start containers"
    echo "  stop [container_name] [container2...]     Stop containers"
    echo "  restart [container_name] [container2...]  Restart containers"
    echo "  cleanup [container_name] [container2...] [--all] Remove specific containers or all state-managed containers"
    echo "  cleanup all                             Remove ALL containers, images, volumes, networks (DANGER)"
    echo "  nuke                                    Nuke Docker system (remove all containers, images, volumes, networks)"
    echo "  status [container_name] [container2...]  Show container status"
    echo "  logs [container_name] [container2...]    Show container logs"
    echo "  list [resource_type]                    List Docker resources (containers, images, projects, volumes, networks, all)"
    echo "  config                                  Show configuration"
    echo "  state                                   Show state summary"
    echo "  env                                     Show environment variables and directory locations"
    echo "  help                                    Show this help"
    echo
    echo "Options:"
    echo "  --yaml <file>                          Specify YAML file"
    echo "  --force                                Force operation"
    echo "  --timeout <seconds>                    Operation timeout"
    echo "  --log-level <level>                    Set log level (DEBUG, INFO, WARN, ERROR)"
    echo "  --trace                                Enable detailed method tracing for debugging"
    echo
    echo "Examples:"
    echo "  ./docker_ops_manager.sh generate docker-compose.yml my-app"
    echo "  ./docker_ops_manager.sh generate app1.yml app2.yml app3.yml"
    # echo "  ./docker_ops_manager.sh start my-app"
    # echo "  ./docker_ops_manager.sh start nginx-app web-app db-app"
    echo "  ./docker_ops_manager.sh stop"
    echo "  ./docker_ops_manager.sh stop nginx-app web-app"
    echo "  ./docker_ops_manager.sh cleanup nginx"
    echo "  ./docker_ops_manager.sh cleanup nginx-app web-app db-app"
    echo "  ./docker_ops_manager.sh cleanup --all"
    echo "  ./docker_ops_manager.sh cleanup all"
    echo "  ./docker_ops_manager.sh nuke"
    echo "  ./docker_ops_manager.sh status"
    echo "  ./docker_ops_manager.sh status nginx-app web-app"
    echo "  ./docker_ops_manager.sh logs nginx-app web-app"
    echo "  ./docker_ops_manager.sh list containers"
    echo "  ./docker_ops_manager.sh list images"
    echo "  ./docker_ops_manager.sh list projects"
    echo "  ./docker_ops_manager.sh env"
    # echo
    # echo "Environment Variables:"
    # echo "  DOCKER_OPS_CONFIG_DIR                  Configuration directory"
    # echo "  DOCKER_OPS_LOG_DIR                     Log directory"
    # echo "  DOCKER_OPS_LOG_LEVEL                   Log level"
    # echo "  DOCKER_OPS_STATE_FILE                  State file path"
    # echo
    # echo "Cleanup Options:"
    # echo "  ./docker_ops_manager.sh cleanup nginx        # Remove specific container"
    # echo "  ./docker_ops_manager.sh cleanup --all        # Remove all state-managed containers only"
    # echo "  ./docker_ops_manager.sh cleanup all          # Remove ALL containers, images, volumes, networks (DANGER)"
    # echo "  ./docker_ops_manager.sh nuke                 # Interactive nuke with confirmation prompt"
    # echo
    echo "For more information, see the documentation."
    echo
    echo "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
    echo "Licensed under MIT License with Attribution Requirement"
    echo "Copyright (c) 2024 Gaurav Gupta"
}

# =============================================================================
# FUNCTION: main
# =============================================================================
# Purpose: Main entry point for the Docker Ops Manager script
# Inputs: All command line arguments
# Outputs: None
# Side Effects: 
#   - Parses arguments and sets global variables
#   - Initializes system components
#   - Validates and routes operations
#   - Shows help if no operation specified
# Usage: Called automatically at script startup with all arguments
# =============================================================================
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Initialize system
    initialize_system
    
    # Validate operation
    if [[ -n "$OPERATION" ]]; then
        validate_operation
        route_operation
    else
        # Show help by default when no operation is specified
        print_help
        exit 0
    fi
}

# =============================================================================
# FUNCTION: cleanup_on_exit
# =============================================================================
# Purpose: Cleanup function called when the script exits
# Inputs: None
# Outputs: None
# Side Effects: 
#   - Logs script completion
#   - Syncs state with Docker
#   - Cleans up temporary files
#   - Cleans up tracing resources
# Usage: Called automatically via trap on script exit
# =============================================================================
cleanup_on_exit() {
    log_info "EXIT" "" "Script execution completed"
    
    # Sync state with Docker before exiting
    sync_state_with_docker
    
    cleanup_temp_files
    
    # Clean up tracing if enabled
    if [[ "$TRACE_ENABLED" == "true" ]]; then
        cleanup_tracing
    fi
}

# Set up exit trap
trap cleanup_on_exit EXIT

# Run main function with all arguments
main "$@"