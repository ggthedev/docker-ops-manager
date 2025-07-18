#!/usr/bin/env bash

# Configuration Management Module
# Handles environment variables, default values, and configuration loading

# Default configuration values
DEFAULT_CONFIG_DIR="$HOME/.config/docker-ops-manager"
DEFAULT_LOG_DIR="$DEFAULT_CONFIG_DIR/logs"
DEFAULT_STATE_FILE="$DEFAULT_CONFIG_DIR/state.json"
DEFAULT_CONFIG_FILE="$DEFAULT_CONFIG_DIR/config.json"
DEFAULT_LOG_LEVEL="INFO"
DEFAULT_LOG_ROTATION_DAYS=7
DEFAULT_MAX_CONTAINER_HISTORY=10
DEFAULT_PROJECT_NAME_PATTERN="project-<service.name>-<DD-MM-YY>"

# Load configuration from environment variables or use defaults
# This function initializes all configuration variables by checking environment
# variables first, then falling back to default values if not set.
#
# Input: None (uses environment variables)
# Output: Sets global configuration variables
# Side effects: Creates configuration directories if they don't exist
load_config() {
    # Configuration directory - where all config files are stored
    export DOCKER_OPS_CONFIG_DIR="${DOCKER_OPS_CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
    
    # Logging configuration - controls log file location and behavior
    export DOCKER_OPS_LOG_DIR="${DOCKER_OPS_LOG_DIR:-$DEFAULT_LOG_DIR}"
    export DOCKER_OPS_LOG_LEVEL="${DOCKER_OPS_LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
    export DOCKER_OPS_LOG_ROTATION_DAYS="${DOCKER_OPS_LOG_ROTATION_DAYS:-$DEFAULT_LOG_ROTATION_DAYS}"
    
    # State management - tracks container operations and history
    export DOCKER_OPS_STATE_FILE="${DOCKER_OPS_STATE_FILE:-$DEFAULT_STATE_FILE}"
    export DOCKER_OPS_CONFIG_FILE="${DOCKER_OPS_CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
    export DOCKER_OPS_MAX_CONTAINER_HISTORY="${DOCKER_OPS_MAX_CONTAINER_HISTORY:-$DEFAULT_MAX_CONTAINER_HISTORY}"
    
    # Project naming - controls how project names are generated when not specified in YAML
    export DOCKER_OPS_PROJECT_NAME_PATTERN="${DOCKER_OPS_PROJECT_NAME_PATTERN:-$DEFAULT_PROJECT_NAME_PATTERN}"
    
    # Create directories if they don't exist to ensure the system can write files
    create_config_directories
}

# Create necessary configuration directories
# Creates the main config directory and log directory if they don't exist.
# This ensures the application can write configuration and log files.
#
# Input: None (uses global config variables)
# Output: None
# Side effects: Creates directories on the filesystem
create_config_directories() {
    # Create main configuration directory
    mkdir -p "$DOCKER_OPS_CONFIG_DIR"
    # Create log directory for storing log files
    mkdir -p "$DOCKER_OPS_LOG_DIR"
}

# Initialize default configuration file
# Creates a JSON configuration file with default values if it doesn't exist.
# This file stores user-configurable settings that can be modified.
#
# Input: None (uses global config variables)
# Output: None
# Side effects: Creates config.json file if it doesn't exist
init_config_file() {
    # Only create the file if it doesn't already exist
    if [[ ! -f "$DOCKER_OPS_CONFIG_FILE" ]]; then
        # Create JSON configuration with default values
        cat > "$DOCKER_OPS_CONFIG_FILE" << EOF
{
    "log_level": "$DOCKER_OPS_LOG_LEVEL",
    "log_rotation_days": $DOCKER_OPS_LOG_ROTATION_DAYS,
    "max_container_history": $DOCKER_OPS_MAX_CONTAINER_HISTORY,
    "project_name_pattern": "$DOCKER_OPS_PROJECT_NAME_PATTERN",
    "docker_compose_timeout": 300,
    "container_start_timeout": 60,
    "container_stop_timeout": 30
}
EOF
    fi
}

# Get configuration value from JSON config file
# Retrieves a specific configuration value from the JSON config file.
# If the key doesn't exist or the file doesn't exist, returns the default value.
#
# Input:
#   $1 - key: The configuration key to retrieve
#   $2 - default_value: Value to return if key doesn't exist
# Output: The configuration value or default value
# Example: get_config_value "log_level" "INFO"
get_config_value() {
    local key="$1"
    local default_value="$2"
    
    # Check if config file exists before trying to read from it
    if [[ -f "$DOCKER_OPS_CONFIG_FILE" ]]; then
        # Use jq to extract the value from JSON, suppress errors
        local value=$(jq -r ".$key" "$DOCKER_OPS_CONFIG_FILE" 2>/dev/null)
        # Check if value is valid (not null and not empty)
        if [[ "$value" != "null" && -n "$value" ]]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        # Return default if config file doesn't exist
        echo "$default_value"
    fi
}

# Set configuration value in JSON config file
# Updates or adds a configuration value in the JSON config file.
# Creates the config file if it doesn't exist.
#
# Input:
#   $1 - key: The configuration key to set
#   $2 - value: The value to set for the key
# Output: None
# Side effects: Updates config.json file
# Example: set_config_value "log_level" "DEBUG"
set_config_value() {
    local key="$1"
    local value="$2"
    
    # Create config file if it doesn't exist
    if [[ ! -f "$DOCKER_OPS_CONFIG_FILE" ]]; then
        init_config_file
    fi
    
    # Use jq to update the JSON file safely
    # Create temporary file, update it, then move to final location
    local temp_file=$(mktemp)
    jq ".$key = $value" "$DOCKER_OPS_CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$DOCKER_OPS_CONFIG_FILE"
}

# Validate configuration and system requirements
# Checks if all required dependencies and permissions are available.
# Returns error messages for any issues found.
#
# Input: None
# Output: Error messages (if any) or empty string if all checks pass
# Return code: 0 if valid, 1 if errors found
validate_config() {
    local errors=()
    
    # Check if Docker is available in PATH
    if ! command -v docker &> /dev/null; then
        errors+=("Docker is not installed or not in PATH")
    fi
    
    # Check if Docker daemon is running and accessible
    if ! docker info &> /dev/null; then
        errors+=("Docker daemon is not running")
    fi
    
    # Check if jq is available (required for JSON processing)
    if ! command -v jq &> /dev/null; then
        errors+=("jq is not installed (required for JSON processing)")
    fi
    
    # Check if configuration directory is writable
    if [[ ! -w "$DOCKER_OPS_CONFIG_DIR" ]]; then
        errors+=("Configuration directory is not writable: $DOCKER_OPS_CONFIG_DIR")
    fi
    
    # Check if log directory is writable
    if [[ ! -w "$DOCKER_OPS_LOG_DIR" ]]; then
        errors+=("Log directory is not writable: $DOCKER_OPS_LOG_DIR")
    fi
    
    # Return errors if any were found
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    # All checks passed
    return 0
}

# Print current configuration
# Displays all current configuration values in a readable format.
# Useful for debugging and understanding the current system state.
#
# Input: None
# Output: Formatted configuration display
# Example: print_config
print_config() {
    echo "=== Docker Ops Manager Configuration ==="
    echo "Config Directory: $DOCKER_OPS_CONFIG_DIR"
    echo "Log Directory: $DOCKER_OPS_LOG_DIR"
    echo "State File: $DOCKER_OPS_STATE_FILE"
    echo "Config File: $DOCKER_OPS_CONFIG_FILE"
    echo "Log Level: $DOCKER_OPS_LOG_LEVEL"
    echo "Log Rotation Days: $DOCKER_OPS_LOG_ROTATION_DAYS"
    echo "Max Container History: $DOCKER_OPS_MAX_CONTAINER_HISTORY"
    echo "Project Name Pattern: $DOCKER_OPS_PROJECT_NAME_PATTERN"
    echo "========================================"
} 