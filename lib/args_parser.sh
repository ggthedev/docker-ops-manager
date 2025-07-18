#!/usr/bin/env bash

# =============================================================================
# ARGUMENT PARSER LIBRARY
# =============================================================================
# Purpose: Centralized argument parsing for Docker Ops Manager
# Provides robust command line argument parsing using getopts
# Supports both short and long options with comprehensive error handling
# =============================================================================

# =============================================================================
# FUNCTION: parse_arguments
# =============================================================================
# Purpose: Parse command line arguments using getopts for robust option handling
# Inputs: All command line arguments
# Outputs: None (side effects: sets global variables)
# Side Effects:
#   - Sets global variables based on parsed arguments
#   - Exits with error if invalid options are provided
#   - Exits with help if --help is specified
#   - Exits with version if --version is specified
# Usage: Called automatically during script startup with all command line args
# =============================================================================
parse_arguments() {
    # First pass: handle long options and help/version
    local args=("$@")
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        local arg="${args[$i]}"
        
        case "$arg" in
            --help)
                print_help
                exit 0
                ;;
            --version)
                echo "Docker Ops Manager v$SCRIPT_VERSION"
                echo "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
                echo "Licensed under MIT License with Attribution Requirement"
                echo "Copyright (c) 2024 Gaurav Gupta"
                exit 0
                ;;
            --generate)
                OPERATION="generate"
                i=$((i+1))
                ;;
            --install)
                OPERATION="install"
                i=$((i+1))
                ;;
            --reinstall)
                OPERATION="reinstall"
                i=$((i+1))
                ;;
            --start|--run)
                OPERATION="start"
                i=$((i+1))
                ;;
            --stop)
                OPERATION="stop"
                i=$((i+1))
                ;;
            --restart)
                OPERATION="restart"
                i=$((i+1))
                ;;
            --cleanup)
                OPERATION="cleanup"
                i=$((i+1))
                ;;
            --nuke)
                OPERATION="nuke"
                i=$((i+1))
                ;;
            --status)
                OPERATION="status"
                i=$((i+1))
                ;;
            --logs)
                OPERATION="logs"
                i=$((i+1))
                ;;
            --list)
                OPERATION="list"
                i=$((i+1))
                ;;
            --config)
                OPERATION="config"
                i=$((i+1))
                ;;
            --state)
                OPERATION="state"
                i=$((i+1))
                ;;
            --env)
                OPERATION="env"
                i=$((i+1))
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
                print_error "Unknown long option: $arg"
                print_info "Use --help to see available options"
                exit 1
                ;;
            -*)
                # Short options will be handled by getopts in the second pass
                break
                ;;
            *)
                # Positional arguments will be handled after getopts
                break
                ;;
        esac
    done
    
    # Second pass: use getopts for short options
    # Reset OPTIND for getopts
    OPTIND=1
    
    # Define short options string for getopts
    # Format: "option:value" where : means the option requires a value
    local shortopts="hvgirxstcnualCefy:o:d:T"
    
    # Parse short options with custom error handling
    while getopts "$shortopts" opt 2>/dev/null; do
        case $opt in
            h)
                print_help
                exit 0
                ;;
            v)
                echo "Docker Ops Manager v$SCRIPT_VERSION"
                echo "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
                echo "Licensed under MIT License with Attribution Requirement"
                echo "Copyright (c) 2024 Gaurav Gupta"
                exit 0
                ;;
            g)
                OPERATION="generate"
                ;;
            i)
                OPERATION="install"
                ;;
            r)
                OPERATION="reinstall"
                ;;
            s)
                OPERATION="start"
                ;;
            x)
                OPERATION="stop"
                ;;
            t)
                OPERATION="restart"
                ;;
            c)
                OPERATION="cleanup"
                ;;
            n)
                OPERATION="nuke"
                ;;
            u)
                OPERATION="status"
                ;;
            l)
                OPERATION="logs"
                ;;
            a)
                OPERATION="list"
                ;;
            C)
                OPERATION="config"
                ;;
            e)
                OPERATION="state"
                ;;
            f)
                FORCE=true
                ;;
            y)
                YAML_FILES+=("$OPTARG")
                ;;
            o)
                TIMEOUT="$OPTARG"
                ;;
            d)
                LOG_LEVEL="$OPTARG"
                ;;
            T)
                TRACE_ENABLED=true
                ;;
            \?)
                print_error "Invalid option: -${OPTARG:-unknown}"
                print_info "Use --help to see available options"
                exit 1
                ;;
            :)
                print_error "Option -${OPTARG:-unknown} requires an argument"
                print_info "Use --help to see available options"
                exit 1
                ;;
        esac
    done
    
    # Check if getopts failed
    if [[ $? -ne 0 ]]; then
        print_error "Invalid command line options"
        print_info "Use --help to see available options"
        exit 1
    fi
    
    # Shift processed options out of argument list
    shift $((OPTIND-1))
    
    # Handle remaining positional arguments
    for arg in "$@"; do
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
    echo "  generate, -g <yaml_file> [yaml_file2...]    Generate containers from YAML files"
    echo "  install, -i [container_name] [container2...] Install/update containers"
    echo "  reinstall, -r [container_name] [container2...] Reinstall containers"
    echo "  start|run, -s [container_name] [container2...] Start containers"
    echo "  stop, -x [container_name] [container2...]     Stop containers"
    echo "  restart, -t [container_name] [container2...]  Restart containers"
    echo "  cleanup, -c [container_name] [container2...] [--all] Remove specific containers or all state-managed containers"
    echo "  cleanup, -c all                             Remove ALL containers, images, volumes, networks (DANGER)"
    echo "  nuke, -n                                    Nuke Docker system (remove all containers, images, volumes, networks)"
    echo "  status, -u [container_name] [container2...]  Show container status"
    echo "  logs, -l [container_name] [container2...]    Show container logs"
    echo "  list, -a [resource_type]                    List Docker resources (containers, images, projects, volumes, networks, all)"
    echo "  config, -C                                  Show configuration"
    echo "  state, -e                                   Show state summary"
    echo "  env                                         Show environment variables and directory locations"
    echo "  help, -h                                    Show this help"
    echo
    echo "Global Options:"
    echo "  --yaml, -y <file>                          Specify YAML file"
    echo "  --force, -f                                Force operation"
    echo "  --timeout, -o <seconds>                    Operation timeout"
    echo "  --log-level, -d <level>                    Set log level (DEBUG, INFO, WARN, ERROR)"
    echo "  --trace, -T                                Enable detailed method tracing for debugging"
    echo "  --version, -v                              Show version information"
    echo
    echo "Examples:"
    echo "  # Long format examples:"
    echo "  ./docker_ops_manager.sh generate docker-compose.yml my-app"
    echo "  ./docker_ops_manager.sh generate app1.yml app2.yml app3.yml"
    echo "  ./docker_ops_manager.sh --generate --yaml docker-compose.yml"
    echo "  ./docker_ops_manager.sh --cleanup --force nginx"
    echo "  ./docker_ops_manager.sh --status --timeout 30 my-app"
    echo
    echo "  # Short format examples:"
    echo "  ./docker_ops_manager.sh -g docker-compose.yml my-app"
    echo "  ./docker_ops_manager.sh -c -f nginx"
    echo "  ./docker_ops_manager.sh -u -o 30 my-app"
    echo "  ./docker_ops_manager.sh -n -f"
    echo "  ./docker_ops_manager.sh -a containers"
    echo "  ./docker_ops_manager.sh -l my-app"
    echo
    echo "  # Mixed format examples:"
    echo "  ./docker_ops_manager.sh -g --yaml docker-compose.yml"
    echo "  ./docker_ops_manager.sh --cleanup -f nginx"
    echo "  ./docker_ops_manager.sh -u --timeout 30 my-app"
    echo
    echo "For more information, see the documentation."
    echo
    echo "Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)"
    echo "Licensed under MIT License with Attribution Requirement"
    echo "Copyright (c) 2024 Gaurav Gupta"
} 