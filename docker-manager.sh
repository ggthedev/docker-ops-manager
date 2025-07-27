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
source "$SCRIPT_DIR/lib/args_parser.sh"

# Global variables
OPERATION=""
CONTAINER_NAMES=()  # Array to store multiple container names
YAML_FILES=()       # Array to store multiple YAML files
FORCE=false
TIMEOUT=60
LOG_LEVEL=""
TRACE_ENABLED=false
NO_START=false      # Flag to create container without starting it

# Global variables for interactive menu system
IMAGE_NAME=""
CONTAINER_NAME_FROM_FLAG=""
PORT_MAPPING=""
VOLUME_MAPPING=""
ENV_VARS=""
NETWORK_NAME=""
RESOURCE_LIMITS=""
DOCKERFILE_PATH=""
BUILD_CONTEXT=""
BUILD_IMAGE_NAME=""

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
        "generate"|"install")
            handle_generate
            ;;
        "update"|"refresh")
            handle_update
            ;;
        "start"|"run"|"up")
            handle_start
            ;;
        "stop"|"down")
            handle_stop
            ;;
        "restart")
            handle_restart
            ;;
        "clean"|"delete"|"remove")
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
                # No container specified - check if we have a last container
                local last_container=$(get_last_container)
                if [[ -n "$last_container" ]]; then
                    print_section "Cleaning up container: $last_container"
                    source "$SCRIPT_DIR/operations/cleanup.sh"
                    cleanup_container "$last_container" "$FORCE"
                else
                    print_error "No containers to clean up"
                    exit 1
                fi
            fi
            ;;
        "nuke")
            print_section "Nuke Docker System"
            source "$SCRIPT_DIR/operations/cleanup.sh"
            nuke_docker_system "$FORCE"
            ;;
        "status"|"state")
            handle_status
            ;;
        "logs")
            handle_logs
            ;;
        "list")
            handle_list
            ;;
        "config"|"env")
            handle_env
            ;;
        "help")
            if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
                # Command-specific help
                local command="${CONTAINER_NAMES[0]}"
                print_command_help "$command"
            else
                # General help
                print_help
            fi
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
    # Check if we have command line arguments or should show interactive menu
    if [[ ${#YAML_FILES[@]} -eq 0 && -z "$IMAGE_NAME" ]]; then
        # No arguments provided - show interactive menu
        handle_interactive_generate
        return
    fi
    
    # Handle command line arguments
    if [[ ${#YAML_FILES[@]} -eq 0 && -n "$IMAGE_NAME" ]]; then
        # Generate from image
        handle_image_generation
        return
    fi
    
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
# FUNCTION: handle_interactive_generate
# =============================================================================
# Purpose: Handle interactive menu-driven container generation
# Inputs: None (uses global variables for menu system)
# Outputs: None
# Side Effects: 
#   - Shows interactive menus for configuration
#   - Calls appropriate generation functions
# Usage: Called by handle_generate when no arguments provided
# =============================================================================
handle_interactive_generate() {
    local menu_choice=""
    local configuration_complete=false
    local image_selected=false
    local yaml_selected=false
    local dockerfile_selected=false
    
    # Initialize configuration
    YAML_FILES=()
    IMAGE_NAME=""
    CONTAINER_NAME_FROM_FLAG=""
    PORT_MAPPING=""
    VOLUME_MAPPING=""
    ENV_VARS=""
    NETWORK_NAME=""
    RESOURCE_LIMITS=""
    DOCKERFILE_PATH=""
    BUILD_CONTEXT=""
    BUILD_IMAGE_NAME=""
    
    while [[ "$configuration_complete" == "false" ]]; do
        show_generate_menu
        read -r menu_choice
        
        case "$menu_choice" in
            1)  # Generate from YAML file
                if show_yaml_generation_menu; then
                    yaml_selected=true
                    image_selected=false
                    print_success "YAML file selected: ${YAML_FILES[0]}"
                fi
                ;;
            2)  # Generate from existing image
                if show_image_generation_menu; then
                    image_selected=true
                    yaml_selected=false
                    dockerfile_selected=false
                    print_success "Image selected: $IMAGE_NAME"
                fi
                ;;
            3)  # Build from Dockerfile
                if show_dockerfile_build_menu; then
                    dockerfile_selected=true
                    image_selected=false
                    yaml_selected=false
                    print_success "Dockerfile selected: $DOCKERFILE_PATH"
                    print_info "Build context: $BUILD_CONTEXT"
                fi
                ;;
            4)  # Configure port mapping
                if show_port_mapping_menu; then
                    if [[ -n "$PORT_MAPPING" ]]; then
                        print_success "Port mapping configured: $PORT_MAPPING"
                    else
                        print_info "Port mapping disabled"
                    fi
                fi
                ;;
            5)  # Configure volume mounting
                if show_volume_mapping_menu; then
                    if [[ -n "$VOLUME_MAPPING" ]]; then
                        print_success "Volume mapping configured: $VOLUME_MAPPING"
                    else
                        print_info "Volume mapping disabled"
                    fi
                fi
                ;;
            6)  # Configure environment variables
                if show_environment_menu; then
                    if [[ -n "$ENV_VARS" ]]; then
                        print_success "Environment variables configured: $ENV_VARS"
                    else
                        print_info "Environment variables disabled"
                    fi
                fi
                ;;
            7)  # Configure custom network
                if show_network_menu; then
                    if [[ -n "$NETWORK_NAME" ]]; then
                        print_success "Network configured: $NETWORK_NAME"
                    else
                        print_info "Using default bridge network"
                    fi
                fi
                ;;
            8)  # Configure resource limits
                if show_resource_menu; then
                    if [[ -n "$RESOURCE_LIMITS" ]]; then
                        print_success "Resource limits configured: $RESOURCE_LIMITS"
                    else
                        print_info "No resource limits set"
                    fi
                fi
                ;;
            9)  # Build only (no run)
                if [[ "$dockerfile_selected" == "true" ]]; then
                    if show_build_confirmation; then
                        handle_build_only
                        configuration_complete=true
                    fi
                elif [[ "$image_selected" == "true" ]]; then
                    if show_image_build_confirmation; then
                        handle_image_build_only
                        configuration_complete=true
                    fi
                else
                    print_error "Please select a Dockerfile (option 3) or image (option 2) first for build-only operation"
                    sleep 2
                fi
                ;;
            10)  # Generate container with current configuration
                if [[ "$image_selected" == "true" ]]; then
                    # Generate from image
                    if get_container_name; then
                        if show_generation_confirmation; then
                            handle_image_generation
                            configuration_complete=true
                        fi
                    fi
                elif [[ "$yaml_selected" == "true" ]]; then
                    # Generate from YAML
                    if get_container_name; then
                        if show_generation_confirmation; then
                            local yaml_file="${YAML_FILES[0]}"
                            local container_name="$CONTAINER_NAME_FROM_FLAG"
                            
                            print_section "Generating container from YAML"
                            parse_yaml_summary "$yaml_file"
                            
                            source "$SCRIPT_DIR/operations/generate.sh"
                            generate_from_yaml "$yaml_file" "$container_name"
                            configuration_complete=true
                        fi
                    fi
                elif [[ "$dockerfile_selected" == "true" ]]; then
                    # Generate from Dockerfile
                    if get_container_name; then
                        if show_generation_confirmation; then
                            handle_dockerfile_generation
                            configuration_complete=true
                        fi
                    fi
                else
                    print_error "Please select an image (option 2), YAML file (option 1), or Dockerfile (option 3) first"
                    sleep 2
                fi
                ;;
            11)  # Cancel
                print_info "Generation cancelled"
                return
                ;;
            *)
                print_error "Invalid choice. Please select 1-11."
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# FUNCTION: handle_image_generation
# =============================================================================
# Purpose: Handle container generation from existing Docker image
# Inputs: None (uses global variables IMAGE_NAME, CONTAINER_NAME_FROM_FLAG, etc.)
# Outputs: None
# Side Effects: 
#   - Validates image exists
#   - Creates container with specified configuration
# Usage: Called by handle_generate or handle_interactive_generate
# =============================================================================
handle_image_generation() {
    # Validate image exists
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        print_error "Image '$IMAGE_NAME' does not exist locally"
        print_info "Available images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
        exit 1
    fi
    
    # Set container name if not provided
    if [[ -z "$CONTAINER_NAME_FROM_FLAG" ]]; then
        CONTAINER_NAME_FROM_FLAG=$(generate_container_name_from_image "$IMAGE_NAME")
    fi
    
    print_section "Generating container from image"
    print_info "Image: $IMAGE_NAME"
    print_info "Container: $CONTAINER_NAME_FROM_FLAG"
    
    # Build docker run command
    local docker_run_cmd="docker run --name $CONTAINER_NAME_FROM_FLAG"
    
    # Add port mapping
    if [[ -n "$PORT_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -p $PORT_MAPPING"
    fi
    
    # Add volume mapping
    if [[ -n "$VOLUME_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -v $VOLUME_MAPPING"
    fi
    
    # Add environment variables
    if [[ -n "$ENV_VARS" ]]; then
        IFS=',' read -ra env_array <<< "$ENV_VARS"
        for env_var in "${env_array[@]}"; do
            docker_run_cmd="$docker_run_cmd -e $env_var"
        done
    fi
    
    # Add network
    if [[ -n "$NETWORK_NAME" ]]; then
        docker_run_cmd="$docker_run_cmd --network $NETWORK_NAME"
    fi
    
    # Add resource limits
    if [[ -n "$RESOURCE_LIMITS" ]]; then
        docker_run_cmd="$docker_run_cmd $RESOURCE_LIMITS"
    fi
    
    # Add detach flag
    docker_run_cmd="$docker_run_cmd -d"
    
    # Add image name
    docker_run_cmd="$docker_run_cmd $IMAGE_NAME"
    
    # Execute the command
    print_info "Executing: $docker_run_cmd"
    
    if eval "$docker_run_cmd"; then
        log_operation_success "generate" "$CONTAINER_NAME_FROM_FLAG" "Container generated successfully from image"
        print_success "Container '$CONTAINER_NAME_FROM_FLAG' created successfully"
    else
        log_operation_failure "generate" "$CONTAINER_NAME_FROM_FLAG" "Failed to create container from image"
        print_error "Failed to create container from image"
        exit 1
    fi
}

# =============================================================================
# FUNCTION: handle_dockerfile_generation
# =============================================================================
# Purpose: Handle container generation from Dockerfile
# Inputs: None (uses global variables DOCKERFILE_PATH, BUILD_CONTEXT, etc.)
# Outputs: None
# Side Effects: 
#   - Builds Docker image from Dockerfile
#   - Creates container with specified configuration
# Usage: Called by handle_interactive_generate
# =============================================================================
handle_dockerfile_generation() {
    # Validate Dockerfile exists
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        print_error "Dockerfile '$DOCKERFILE_PATH' does not exist"
        exit 1
    fi
    
    # Set image name if not provided
    if [[ -z "$BUILD_IMAGE_NAME" ]]; then
        local dir_name=$(basename "$BUILD_CONTEXT")
        if [[ "$dir_name" == "." ]]; then
            dir_name="app"
        fi
        BUILD_IMAGE_NAME="${dir_name}-image:latest"
    fi
    
    # Set container name if not provided
    if [[ -z "$CONTAINER_NAME_FROM_FLAG" ]]; then
        CONTAINER_NAME_FROM_FLAG="${BUILD_IMAGE_NAME%:*}-container"
    fi
    
    print_section "Building image from Dockerfile"
    print_info "Dockerfile: $DOCKERFILE_PATH"
    print_info "Build context: $BUILD_CONTEXT"
    print_info "Image name: $BUILD_IMAGE_NAME"
    print_info "Container: $CONTAINER_NAME_FROM_FLAG"
    
    # Build Docker image
    print_info "Building Docker image..."
    if ! docker build -f "$DOCKERFILE_PATH" -t "$BUILD_IMAGE_NAME" "$BUILD_CONTEXT"; then
        print_error "Failed to build Docker image"
        exit 1
    fi
    
    print_success "Docker image built successfully: $BUILD_IMAGE_NAME"
    
    # Now create container from the built image
    print_section "Creating container from built image"
    
    # Build docker run command
    local docker_run_cmd="docker run --name $CONTAINER_NAME_FROM_FLAG"
    
    # Add port mapping
    if [[ -n "$PORT_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -p $PORT_MAPPING"
    fi
    
    # Add volume mapping
    if [[ -n "$VOLUME_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -v $VOLUME_MAPPING"
    fi
    
    # Add environment variables
    if [[ -n "$ENV_VARS" ]]; then
        IFS=',' read -ra env_array <<< "$ENV_VARS"
        for env_var in "${env_array[@]}"; do
            docker_run_cmd="$docker_run_cmd -e $env_var"
        done
    fi
    
    # Add network
    if [[ -n "$NETWORK_NAME" ]]; then
        docker_run_cmd="$docker_run_cmd --network $NETWORK_NAME"
    fi
    
    # Add resource limits
    if [[ -n "$RESOURCE_LIMITS" ]]; then
        docker_run_cmd="$docker_run_cmd $RESOURCE_LIMITS"
    fi
    
    # Add detach flag
    docker_run_cmd="$docker_run_cmd -d"
    
    # Add image name
    docker_run_cmd="$docker_run_cmd $BUILD_IMAGE_NAME"
    
    # Execute the command
    print_info "Executing: $docker_run_cmd"
    
    if eval "$docker_run_cmd"; then
        log_operation_success "generate" "$CONTAINER_NAME_FROM_FLAG" "Container generated successfully from Dockerfile"
        print_success "Container '$CONTAINER_NAME_FROM_FLAG' created successfully from Dockerfile"
    else
        log_operation_failure "generate" "$CONTAINER_NAME_FROM_FLAG" "Failed to create container from Dockerfile"
        print_error "Failed to create container from Dockerfile"
        exit 1
    fi
}

# =============================================================================
# FUNCTION: handle_build_only
# =============================================================================
# Purpose: Handle build-only operation (no container creation)
# Inputs: None (uses global variables DOCKERFILE_PATH, BUILD_CONTEXT, etc.)
# Outputs: None
# Side Effects: 
#   - Builds Docker image from Dockerfile
#   - Does not create or start container
# Usage: Called by handle_interactive_generate
# =============================================================================
handle_build_only() {
    # Validate Dockerfile exists
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        print_error "Dockerfile '$DOCKERFILE_PATH' does not exist"
        exit 1
    fi
    
    # Set image name if not provided
    if [[ -z "$BUILD_IMAGE_NAME" ]]; then
        local dir_name=$(basename "$BUILD_CONTEXT")
        if [[ "$dir_name" == "." ]]; then
            dir_name="app"
        fi
        BUILD_IMAGE_NAME="${dir_name}-image:latest"
    fi
    
    print_section "Building Docker image (no container creation)"
    print_info "Dockerfile: $DOCKERFILE_PATH"
    print_info "Build context: $BUILD_CONTEXT"
    print_info "Image name: $BUILD_IMAGE_NAME"
    
    # Build Docker image
    print_info "Building Docker image..."
    if ! docker build -f "$DOCKERFILE_PATH" -t "$BUILD_IMAGE_NAME" "$BUILD_CONTEXT"; then
        print_error "Failed to build Docker image"
        exit 1
    fi
    
    print_success "Docker image built successfully: $BUILD_IMAGE_NAME"
    print_info "Image is ready for use. You can run it later with:"
    print_info "docker run $BUILD_IMAGE_NAME"
}

# =============================================================================
# FUNCTION: handle_image_build_only
# =============================================================================
# Purpose: Handle image-based build-only operation (no container creation)
# Inputs: None (uses global variables IMAGE_NAME, CONTAINER_NAME_FROM_FLAG, etc.)
# Outputs: None
# Side Effects: 
#   - Shows docker run command without creating container
#   - Provides helpful instructions for later use
# Usage: Called by handle_interactive_generate
# =============================================================================
handle_image_build_only() {
    # Validate image exists
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        print_error "Image '$IMAGE_NAME' does not exist locally"
        print_info "Available images:"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
        exit 1
    fi
    
    # Set container name if not provided
    if [[ -z "$CONTAINER_NAME_FROM_FLAG" ]]; then
        CONTAINER_NAME_FROM_FLAG=$(generate_container_name_from_image "$IMAGE_NAME")
    fi
    
    print_section "Build Preview - No Container Creation"
    print_info "Image: $IMAGE_NAME"
    print_info "Container: $CONTAINER_NAME_FROM_FLAG"
    
    # Build docker run command
    local docker_run_cmd="docker run --name $CONTAINER_NAME_FROM_FLAG"
    
    # Add port mapping
    if [[ -n "$PORT_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -p $PORT_MAPPING"
    fi
    
    # Add volume mapping
    if [[ -n "$VOLUME_MAPPING" ]]; then
        docker_run_cmd="$docker_run_cmd -v $VOLUME_MAPPING"
    fi
    
    # Add environment variables
    if [[ -n "$ENV_VARS" ]]; then
        docker_run_cmd="$docker_run_cmd -e $ENV_VARS"
    fi
    
    # Add network
    if [[ -n "$NETWORK_NAME" ]]; then
        docker_run_cmd="$docker_run_cmd --network $NETWORK_NAME"
    fi
    
    # Add resource limits
    if [[ -n "$RESOURCE_LIMITS" ]]; then
        docker_run_cmd="$docker_run_cmd $RESOURCE_LIMITS"
    fi
    
    # Add image and detach flag
    docker_run_cmd="$docker_run_cmd -d $IMAGE_NAME"
    
    print_success "Docker run command preview:"
    print_cyan "$docker_run_cmd"
    echo
    print_info "Container was not created. You can run the command above to create it later."
}

# =============================================================================
# FUNCTION: handle_update
# =============================================================================
# Purpose: Handle the update/refresh operation to update containers
# Inputs: None (uses global variables)
# Outputs: None
# Side Effects: Sources and calls update operation module
# Usage: Called by route_operation when operation is "update" or "refresh"
# =============================================================================
handle_update() {
    local containers=($(get_target_containers))
    
    if [[ ${#containers[@]} -eq 1 ]]; then
        local container_name="${containers[0]}"
        print_section "Updating container: $container_name"
        
        source "$SCRIPT_DIR/operations/install.sh"
        update_container "$container_name"
    else
        print_section "Updating multiple containers"
        
        source "$SCRIPT_DIR/operations/install.sh"
        update_multiple_containers "${containers[@]}"
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
    if [[ ${#CONTAINER_NAMES[@]} -eq 0 ]]; then
        # No container specified - check if we have a last container
        local last_container=$(get_last_container)
        if [[ -n "$last_container" ]]; then
            print_section "Logs for container: $last_container"
            source "$SCRIPT_DIR/operations/logs.sh"
            show_container_logs "$last_container"
        else
            print_error "No containers to show logs for"
            exit 1
        fi
    elif [[ ${#CONTAINER_NAMES[@]} -eq 1 ]]; then
        local container_name="${CONTAINER_NAMES[0]}"
        print_section "Logs for container: $container_name"
        
        source "$SCRIPT_DIR/operations/logs.sh"
        show_container_logs "$container_name"
    else
        print_section "Logs for multiple containers"
        
        source "$SCRIPT_DIR/operations/logs.sh"
        show_multiple_containers_logs "${CONTAINER_NAMES[@]}"
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
    local filter="all"
    
    if [[ ${#CONTAINER_NAMES[@]} -gt 0 ]]; then
        resource_type="${CONTAINER_NAMES[0]}"
        
        # Check for special filter options
        if [[ "$resource_type" == "running" || "$resource_type" == "lr" ]]; then
            resource_type="containers"
            filter="running"
        fi
    fi
    
    local format="table"
    
    case "$resource_type" in
        "containers"|"container")
            list_containers "$format" "$filter"
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
            print_info "Special filters: running, lr (for running containers only)"
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