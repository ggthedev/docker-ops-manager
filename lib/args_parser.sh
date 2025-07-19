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
# Purpose: Parse command line arguments using a simple, reliable approach
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
            --generate|-g)
                OPERATION="generate"
                i=$((i+1))
                ;;
            --install|-i)
                OPERATION="install"
                i=$((i+1))
                ;;
            --update|--refresh|-U)
                OPERATION="update"
                i=$((i+1))
                ;;
            --start|--run|--up|-r)
                OPERATION="start"
                i=$((i+1))
                ;;
            --restart|-R)
                OPERATION="restart"
                i=$((i+1))
                ;;
            --stop|--down|-s)
                OPERATION="stop"
                i=$((i+1))
                ;;
            --status|--state|-S)
                OPERATION="status"
                i=$((i+1))
                ;;
            --clean|--delete|--remove|-c)
                OPERATION="clean"
                i=$((i+1))
                ;;
            --list|-l)
                OPERATION="list"
                i=$((i+1))
                ;;
            --nuke|-n)
                OPERATION="nuke"
                i=$((i+1))
                ;;
            --env|--config|-e)
                OPERATION="env"
                i=$((i+1))
                ;;
            --logs|-L)
                OPERATION="logs"
                i=$((i+1))
                ;;
            --force|-f)
                FORCE=true
                i=$((i+1))
                ;;
            --no-start)
                NO_START=true
                i=$((i+1))
                ;;
            --timeout|-t)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    TIMEOUT="${args[$((i+1))]}"
                    i=$((i+2))
                else
                    print_error "Missing value for --timeout option"
                    exit 1
                fi
                ;;
            --yaml|-y)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    YAML_FILES+=("${args[$((i+1))]}")
                    i=$((i+2))
                else
                    print_error "Missing value for --yaml option"
                    exit 1
                fi
                ;;
            --log-level|-d)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    LOG_LEVEL="${args[$((i+1))]}"
                    i=$((i+2))
                else
                    print_error "Missing value for --log-level option"
                    exit 1
                fi
                ;;
            --trace|-T)
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
                print_error "Unknown short option: $arg"
                print_info "Use --help to see available options"
                exit 1
                ;;
            *)
                # Handle positional arguments based on operation
                if [[ -z "$OPERATION" ]]; then
                    OPERATION="$arg"
                elif [[ "$OPERATION" == "help" ]]; then
                    # For help operation, treat next argument as command name
                    if [[ ${#CONTAINER_NAMES[@]} -eq 0 ]]; then
                        CONTAINER_NAMES+=("$arg")
                    else
                        print_error "Too many arguments for help command"
                        print_info "Use './docker_mgr.sh help [COMMAND]'"
                        exit 1
                    fi
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
        "generate" "install" "update" "refresh" "start" "run" "up" "stop" "down" "restart"
        "clean" "delete" "remove" "nuke" "status" "state" "logs" "list" "config" "env" "help"
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
# Purpose: Display concise help information for the Docker Ops Manager
# Inputs: None
# Outputs: Help text to stdout
# Side Effects: None
# Usage: Called when --help is specified or operation is "help"
# =============================================================================
print_help() {
    echo "Usage: ./docker_mgr.sh [COMMAND] [OPTIONS] [ARGUMENTS]"
    echo
    echo "Commands:"
    echo "  generate|install  -g, (generates the image, generates container, but does not start it)"
    echo "  update/refresh    -U, (stops if needed, deletes container/image, regenerates image/container)"
    echo "  start|run|up      -r, (starts the container, image must be generated and container must exist)"
    echo "  restart           -R, (stops running container and starts it again)"
    echo "  stop|down         -s, (stops the container)"
    echo "  state|status      -S, (shows the container status)"
    echo "  clean|delete|remove -c, (removes the container and image)"
    echo "  list              -l, (detail listing all containers and images)"
    echo "  nuke              -n, (removes all containers and images)"
    echo "  env/config        -e, (shows environment variables and configuration)"
    echo "  logs              -L (shows container logs)"
    echo
    echo "Options:"
    echo "  --help, -h        (shows this help message)"
    echo "  --version, -v     (shows the version of the tool)"
    echo "  --timeout, -t     (sets the timeout duration)"
    echo "  --force, -f       (forces the action)"
    echo "  --no-start        (create container without starting it - generate/install only)"
    echo "  --yaml, -y        (specifies YAML file for generate operation)"
    echo "  --log-level, -d   (sets log level: DEBUG, INFO, WARN, ERROR)"
    echo "  --trace, -T       (enables detailed method tracing)"
    echo
    echo "For help on a command: ./docker_mgr.sh help [COMMAND]"
    echo "For examples: ./docker_mgr.sh help examples"
    echo "For more information: visit https://github.com/ggthedev/docker-ops-manager"
}

# =============================================================================
# FUNCTION: print_command_help
# =============================================================================
# Purpose: Display detailed help for a specific command
# Inputs: $1 - Command name
# Outputs: Help text to stdout
# Side Effects: None
# Usage: Called when help [COMMAND] is specified
# =============================================================================
print_command_help() {
    local command="$1"
    
    # Handle short options by mapping them to full command names
    case "$command" in
        -g) command="generate" ;;
        -i) command="install" ;;
        -U) command="update" ;;
        -r) command="start" ;;
        -R) command="restart" ;;
        -s) command="stop" ;;
        -S) command="status" ;;
        -c) command="clean" ;;
        -l) command="list" ;;
        -n) command="nuke" ;;
        -e) command="env" ;;
        -L) command="logs" ;;
    esac
    
    case "$command" in
        generate|g)
            echo "Usage: ./docker_mgr.sh generate [options] YAML_FILE [CONTAINER_NAME]"
            echo
            echo "Generate containers from YAML files. Creates image and container but does not start it."
            echo
            echo "Arguments:"
            echo "  YAML_FILE        Path to YAML file (docker-compose.yml, app.yml, etc.)"
            echo "  CONTAINER_NAME   Optional container name (extracted from YAML if not provided)"
            echo
            echo "Options:"
            echo "  -y, --yaml YAML_FILE    Specify YAML file (alternative to positional argument)"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  -f, --force             Force operation, overwrite existing containers"
            echo "  --no-start              Create container without starting it"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh generate docker-compose.yml"
            echo "  ./docker_mgr.sh -g docker-compose.yml"
            echo "  ./docker_mgr.sh generate app.yml my-app"
            echo "  ./docker_mgr.sh generate docker-compose.yml --no-start"
            ;;
        install|i)
            echo "Usage: ./docker_mgr.sh install [options] [CONTAINER_NAME...]"
            echo
            echo "Install containers from their stored YAML configuration."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to install"
            echo
            echo "Options:"
            echo "  -f, --force             Force operation, skip confirmation"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  --no-start              Create container without starting it"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh install my-container"
            echo "  ./docker_mgr.sh -i my-container"
            echo "  ./docker_mgr.sh install nginx-app web-app"
            echo "  ./docker_mgr.sh install my-container --no-start"
            ;;
        update|refresh|U)
            echo "Usage: ./docker_mgr.sh update [options] [CONTAINER_NAME...]"
            echo
            echo "Update/refresh containers. Stops if needed, deletes container/image, regenerates image/container."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to update"
            echo
            echo "Options:"
            echo "  -f, --force             Force operation, skip confirmation"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh update my-container"
            echo "  ./docker_mgr.sh -U my-container"
            echo "  ./docker_mgr.sh update nginx-app web-app"
            ;;
        start|run|up|r)
            echo "Usage: ./docker_mgr.sh start [options] [CONTAINER_NAME...]"
            echo
            echo "Start containers. Image must be generated and container must exist."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to start"
            echo
            echo "Options:"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  -f, --force             Force operation"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh start"
            echo "  ./docker_mgr.sh -r my-container"
            echo "  ./docker_mgr.sh start nginx-app web-app"
            ;;
        restart|R)
            echo "Usage: ./docker_mgr.sh restart [options] [CONTAINER_NAME...]"
            echo
            echo "Restart containers. Stops running container and starts it again."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to restart"
            echo
            echo "Options:"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  -f, --force             Force operation"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh restart my-container"
            echo "  ./docker_mgr.sh -R my-container"
            echo "  ./docker_mgr.sh restart nginx-app web-app"
            ;;
        stop|down|s)
            echo "Usage: ./docker_mgr.sh stop [options] [CONTAINER_NAME...]"
            echo
            echo "Stop containers."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to stop"
            echo
            echo "Options:"
            echo "  -f, --force             Force operation"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh stop"
            echo "  ./docker_mgr.sh -s my-container"
            echo "  ./docker_mgr.sh stop nginx-app web-app"
            ;;
        state|status|S)
            echo "Usage: ./docker_mgr.sh status [options] [CONTAINER_NAME...]"
            echo
            echo "Show container status."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to check status"
            echo
            echo "Options:"
            echo "  -t, --timeout SECONDS   Operation timeout (default: 60)"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh status"
            echo "  ./docker_mgr.sh -S"
            echo "  ./docker_mgr.sh status nginx-app web-app"
            ;;
        clean|delete|remove|c)
            echo "Usage: ./docker_mgr.sh clean [options] [CONTAINER_NAME...] [--all]"
            echo
            echo "Remove containers and images."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to remove"
            echo "  --all            Remove all state-managed containers only"
            echo "  all              Remove ALL containers, images, volumes, networks (DANGER)"
            echo
            echo "Options:"
            echo "  -f, --force             Force operation, skip confirmation"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh clean nginx-app"
            echo "  ./docker_mgr.sh -c nginx-app"
            echo "  ./docker_mgr.sh clean nginx-app web-app db-app"
            echo "  ./docker_mgr.sh clean --all"
            echo "  ./docker_mgr.sh clean all"
            ;;
        list|l)
            echo "Usage: ./docker_mgr.sh list [RESOURCE_TYPE]"
            echo
            echo "List Docker resources. Shows containers by default if no resource type specified."
            echo
            echo "Arguments:"
            echo "  RESOURCE_TYPE    Type of resource to list (containers, images, volumes, networks, all)"
            echo "                   Use 'running' or 'lr' for running containers only"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh list"
            echo "  ./docker_mgr.sh -l"
            echo "  ./docker_mgr.sh list containers"
            echo "  ./docker_mgr.sh list running"
            echo "  ./docker_mgr.sh -l running"
            echo "  ./docker_mgr.sh list images"
            ;;
        nuke|n)
            echo "Usage: ./docker_mgr.sh nuke [options]"
            echo
            echo "Remove ALL Docker resources (containers, images, volumes, networks). This is a destructive operation."
            echo
            echo "Options:"
            echo "  -f, --force             Force operation, skip confirmation"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh nuke"
            echo "  ./docker_mgr.sh -n -f"
            ;;
        env|config|e)
            echo "Usage: ./docker_mgr.sh env"
            echo
            echo "Show environment variables and configuration."
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh env"
            echo "  ./docker_mgr.sh -e"
            ;;
        logs|L)
            echo "Usage: ./docker_mgr.sh logs [options] [CONTAINER_NAME...]"
            echo
            echo "Show container logs."
            echo
            echo "Arguments:"
            echo "  CONTAINER_NAME   Container name(s) to show logs for"
            echo
            echo "Options:"
            echo "  -d, --log-level LEVEL   Set log level (DEBUG, INFO, WARN, ERROR)"
            echo "  -T, --trace             Enable detailed method tracing"
            echo
            echo "Examples:"
            echo "  ./docker_mgr.sh logs"
            echo "  ./docker_mgr.sh -L"
            echo "  ./docker_mgr.sh logs nginx-app"
            echo "  ./docker_mgr.sh logs nginx-app web-app"
            ;;
        examples)
            echo "Docker Ops Manager - Usage Examples"
            echo "=================================="
            echo
            echo "Basic Operations:"
            echo "  # Generate containers from YAML"
            echo "  ./docker_mgr.sh generate docker-compose.yml"
            echo "  ./docker_mgr.sh -g docker-compose.yml"
            echo "  ./docker_mgr.sh generate app.yml my-app"
            echo
            echo "  # Start containers"
            echo "  ./docker_mgr.sh start"
            echo "  ./docker_mgr.sh -r my-container"
            echo "  ./docker_mgr.sh start nginx-app web-app"
            echo
            echo "  # Stop containers"
            echo "  ./docker_mgr.sh stop"
            echo "  ./docker_mgr.sh -s my-container"
            echo "  ./docker_mgr.sh stop nginx-app web-app"
            echo
            echo "Container Management:"
            echo "  # Update/refresh containers"
            echo "  ./docker_mgr.sh update nginx-app"
            echo "  ./docker_mgr.sh -U nginx-app web-app db-app"
            echo
            echo "  # Restart containers"
            echo "  ./docker_mgr.sh restart nginx-app"
            echo "  ./docker_mgr.sh -R nginx-app web-app"
            echo
            echo "Cleanup Operations:"
            echo "  # Remove specific containers"
            echo "  ./docker_mgr.sh clean nginx-app"
            echo "  ./docker_mgr.sh -c nginx-app web-app db-app"
            echo
            echo "  # Cleanup all state-managed containers"
            echo "  ./docker_mgr.sh clean --all"
            echo
            echo "  # Full system cleanup (DANGER)"
            echo "  ./docker_mgr.sh clean all"
            echo "  ./docker_mgr.sh nuke"
            echo "  ./docker_mgr.sh -n -f"
            echo
            echo "Information & Status:"
            echo "  # Check container status"
            echo "  ./docker_mgr.sh status"
            echo "  ./docker_mgr.sh -S"
            echo "  ./docker_mgr.sh status nginx-app web-app"
            echo
            echo "  # View container logs"
            echo "  ./docker_mgr.sh logs nginx-app"
            echo "  ./docker_mgr.sh -L nginx-app web-app"
            echo
            echo "  # List Docker resources"
            echo "  ./docker_mgr.sh list"
            echo "  ./docker_mgr.sh -l"
            echo "  ./docker_mgr.sh list containers"
            echo "  ./docker_mgr.sh list running"
            echo "  ./docker_mgr.sh list images"
            echo
            echo "Configuration & Environment:"
            echo "  # Show environment info"
            echo "  ./docker_mgr.sh env"
            echo "  ./docker_mgr.sh -e"
            echo
            echo "Advanced Usage:"
            echo "  # Mixed short and long options"
            echo "  ./docker_mgr.sh -g --yaml docker-compose.yml"
            echo "  ./docker_mgr.sh --clean -f nginx"
            echo "  ./docker_mgr.sh -S --timeout 30 my-app"
            echo
            echo "  # Multiple YAML files"
            echo "  ./docker_mgr.sh generate app1.yml app2.yml app3.yml"
            echo
            echo "  # With logging and tracing"
            echo "  ./docker_mgr.sh -g -d DEBUG -T docker-compose.yml"
            echo
            echo "For more detailed help on specific commands:"
            echo "  ./docker_mgr.sh help [COMMAND]"
            ;;
        *)
            echo "Unknown command: $command"
            echo
            echo "Available commands:"
            echo "  generate, install, update, start, stop, restart, status, clean, list, nuke, env, logs"
            echo
            echo "Use './docker_mgr.sh help [COMMAND]' for detailed help on a specific command."
            echo "Use './docker_mgr.sh help examples' for usage examples."
            ;;
    esac
} 