#!/usr/bin/env bash

# YAML Parser Module
# Handles YAML file validation, container name extraction, and Docker-compose parsing

# Validate YAML file
# Performs basic validation checks on a YAML file including existence, readability,
# and syntax validation. Uses yq if available for better validation.
#
# Input:
#   $1 - yaml_file: Path to the YAML file to validate
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_yaml_file "docker-compose.yml"
validate_yaml_file() {
    local yaml_file="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "validate_yaml_file" "yaml_file=$yaml_file" "YAML file validation"
    
    # Check if file exists
    if [[ ! -f "$yaml_file" ]]; then
        trace_log "YAML file not found: $yaml_file" "ERROR"
        log_error "YAML_PARSER" "" "YAML file not found: $yaml_file"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "validate_yaml_file" "1" "File not found" "$duration"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$yaml_file" ]]; then
        trace_log "YAML file not readable: $yaml_file" "ERROR"
        log_error "YAML_PARSER" "" "YAML file not readable: $yaml_file"
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "validate_yaml_file" "1" "File not readable" "$duration"
        return 1
    fi
    
    # Basic YAML syntax check using yq if available
    trace_log "Checking YAML syntax" "INFO"
    if command -v yq &> /dev/null; then
        trace_log "Using yq for YAML validation" "DEBUG"
        if ! yq eval '.' "$yaml_file" &> /dev/null; then
            trace_log "Invalid YAML syntax detected by yq" "ERROR"
            log_error "YAML_PARSER" "" "Invalid YAML syntax in file: $yaml_file"
            
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "validate_yaml_file" "1" "Invalid YAML syntax" "$duration"
            return 1
        fi
    else
        trace_log "yq not available, using fallback validation" "WARN"
        # Fallback to basic check for common YAML patterns
        # Look for key-value pairs (lines with colon after alphanumeric characters)
        if ! grep -q '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:' "$yaml_file"; then
            trace_log "No key-value pairs found, may not be valid YAML" "WARN"
            log_warn "YAML_PARSER" "" "File may not be valid YAML (no key-value pairs found): $yaml_file"
        fi
    fi
    
    trace_log "YAML file validation successful" "INFO"
    log_debug "YAML_PARSER" "" "YAML file validated: $yaml_file"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "validate_yaml_file" "0" "Validation successful" "$duration"
    return 0
}

# Detect YAML file type
# Analyzes a YAML file to determine its type (docker-compose, docker-stack, or custom).
# Uses filename patterns and content analysis to make the determination.
#
# Input:
#   $1 - yaml_file: Path to the YAML file to analyze
# Output: YAML type string ("docker-compose", "docker-stack", or "custom")
# Example: detect_yaml_type "docker-compose.yml"
detect_yaml_type() {
    local yaml_file="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "detect_yaml_type" "yaml_file=$yaml_file" "YAML type detection"
    
    # Check for docker-compose.yml by filename
    if [[ "$(basename "$yaml_file")" == "docker-compose.yml" || "$(basename "$yaml_file")" == "docker-compose.yaml" ]]; then
        trace_log "Detected docker-compose by filename" "INFO"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "detect_yaml_type" "0" "docker-compose" "$duration"
        echo "docker-compose"
        return 0
    fi
    
    # Check for docker-stack.yml by filename
    if [[ "$(basename "$yaml_file")" == "docker-stack.yml" || "$(basename "$yaml_file")" == "docker-stack.yaml" ]]; then
        trace_log "Detected docker-stack by filename" "INFO"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "detect_yaml_type" "0" "docker-stack" "$duration"
        echo "docker-stack"
        return 0
    fi
    
    # Check content for docker-compose indicators
    # Look for version and services sections which are typical of docker-compose files
    if grep -q '^[[:space:]]*version:' "$yaml_file" && grep -q '^[[:space:]]*services:' "$yaml_file"; then
        trace_log "Detected docker-compose by content (version + services)" "INFO"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "detect_yaml_type" "0" "docker-compose" "$duration"
        echo "docker-compose"
        return 0
    fi
    
    # Check for docker-stack indicators
    # Docker stack files typically have version, services, and networks sections
    if grep -q '^[[:space:]]*version:' "$yaml_file" && grep -q '^[[:space:]]*services:' "$yaml_file" && grep -q '^[[:space:]]*networks:' "$yaml_file"; then
        trace_log "Detected docker-stack by content (version + services + networks)" "INFO"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "detect_yaml_type" "0" "docker-stack" "$duration"
        echo "docker-stack"
        return 0
    fi
    
    # Default to custom YAML if no specific patterns are detected
    trace_log "No specific patterns detected, defaulting to custom YAML" "INFO"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "detect_yaml_type" "0" "custom" "$duration"
    echo "custom"
    return 0
}

# Extract container names from YAML
# Extracts all container/service names from a YAML file based on its type.
# Delegates to specific extraction functions based on the detected YAML type.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - yaml_type: The type of YAML file ("docker-compose", "docker-stack", or "custom")
# Output: List of container names (one per line)
# Example: extract_container_names "docker-compose.yml" "docker-compose"
extract_container_names() {
    local yaml_file="$1"
    local yaml_type="$2"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "extract_container_names" "yaml_file=$yaml_file, yaml_type=$yaml_type" "Container name extraction"
    
    case "$yaml_type" in
        "docker-compose"|"docker-stack")
            trace_log "Extracting from docker-compose/stack format" "INFO"
            local result=$(extract_docker_compose_containers "$yaml_file")
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "extract_container_names" "0" "Found containers: $result" "$duration"
            echo "$result"
            ;;
        "custom")
            trace_log "Extracting from custom YAML format" "INFO"
            local result=$(extract_custom_containers "$yaml_file")
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "extract_container_names" "0" "Found containers: $result" "$duration"
            echo "$result"
            ;;
        *)
            trace_log "Unknown YAML type: $yaml_type" "ERROR"
            log_error "YAML_PARSER" "" "Unknown YAML type: $yaml_type"
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "extract_container_names" "1" "Unknown YAML type" "$duration"
            return 1
            ;;
    esac
}

# Extract containers from docker-compose YAML
# Extracts service names from docker-compose files using yq if available,
# or falls back to grep/sed parsing for basic extraction.
#
# Input:
#   $1 - yaml_file: Path to the docker-compose YAML file
# Output: List of service names (one per line)
# Example: extract_docker_compose_containers "docker-compose.yml"
extract_docker_compose_containers() {
    local yaml_file="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "extract_docker_compose_containers" "yaml_file=$yaml_file" "Docker Compose container extraction"
    
    # Use yq if available for better parsing
    if command -v yq &> /dev/null; then
        trace_log "Using yq for docker-compose parsing" "INFO"
        # Extract all keys from the services section
        local result=$(yq eval '.services | keys | .[]' "$yaml_file" 2>/dev/null)
        trace_log "Extracted containers using yq: $result" "DEBUG"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "extract_docker_compose_containers" "0" "Found: $result" "$duration"
        echo "$result"
    else
        trace_log "yq not available, using grep/sed fallback" "WARN"
        # Fallback to grep/sed parsing
        # Look for service definitions (lines with service names followed by colon)
        local result=$(grep -A 1 '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:' "$yaml_file" | \
        grep '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:' | \
        sed 's/^[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\):.*/\1/')
        trace_log "Extracted containers using grep/sed: $result" "DEBUG"
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        trace_exit "extract_docker_compose_containers" "0" "Found: $result" "$duration"
        echo "$result"
    fi
}

# Extract containers from custom YAML
# Extracts container names from custom YAML files by looking for common patterns
# like image definitions and container_name specifications.
#
# Input:
#   $1 - yaml_file: Path to the custom YAML file
# Output: List of container names (one per line)
# Example: extract_custom_containers "custom-app.yml"
extract_custom_containers() {
    local yaml_file="$1"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "extract_custom_containers" "yaml_file=$yaml_file" "Custom YAML container extraction"
    
    # Look for common container indicators
    local containers=()
    
    # Look for image: patterns and extract container names from image names
    trace_log "Searching for image patterns" "DEBUG"
    while IFS= read -r line; do
        if [[ "$line" =~ image:[[:space:]]*([a-zA-Z0-9._/-]+) ]]; then
            local image="${BASH_REMATCH[1]}"
            # Extract container name from image name (before the colon if present)
            local container_name=$(basename "$image" | cut -d: -f1)
            containers+=("$container_name")
            trace_log "Found container from image: $container_name (from $image)" "DEBUG"
        fi
    done < "$yaml_file"
    
    # Look for explicit container_name: patterns
    trace_log "Searching for explicit container_name patterns" "DEBUG"
    while IFS= read -r line; do
        if [[ "$line" =~ container_name:[[:space:]]*([a-zA-Z0-9._-]+) ]]; then
            local container_name="${BASH_REMATCH[1]}"
            containers+=("$container_name")
            trace_log "Found explicit container name: $container_name" "DEBUG"
        fi
    done < "$yaml_file"
    
    # Remove duplicates and output
    local result=$(printf '%s\n' "${containers[@]}" | sort -u)
    trace_log "Final container list (deduplicated): $result" "INFO"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    trace_exit "extract_custom_containers" "0" "Found: $result" "$duration"
    echo "$result"
}

# Get container configuration from YAML
# Extracts the complete configuration for a specific container from a YAML file.
# Delegates to specific extraction functions based on the YAML type.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - container_name: The name of the container to extract config for
#   $3 - yaml_type: The type of YAML file
# Output: Container configuration as text
# Example: get_container_config "docker-compose.yml" "web" "docker-compose"
get_container_config() {
    local yaml_file="$1"
    local container_name="$2"
    local yaml_type="$3"
    local start_time=$(date +%s.%N)
    
    # Trace function entry
    trace_enter "get_container_config" "yaml_file=$yaml_file, container_name=$container_name, yaml_type=$yaml_type" "Container configuration extraction"
    
    case "$yaml_type" in
        "docker-compose"|"docker-stack")
            trace_log "Getting docker-compose/stack configuration" "INFO"
            local result=$(get_docker_compose_config "$yaml_file" "$container_name")
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "get_container_config" "0" "Configuration extracted" "$duration"
            echo "$result"
            ;;
        "custom")
            trace_log "Getting custom YAML configuration" "INFO"
            local result=$(get_custom_config "$yaml_file" "$container_name")
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "get_container_config" "0" "Configuration extracted" "$duration"
            echo "$result"
            ;;
        *)
            trace_log "Unknown YAML type: $yaml_type" "ERROR"
            log_error "YAML_PARSER" "$container_name" "Unknown YAML type: $yaml_type"
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            trace_exit "get_container_config" "1" "Unknown YAML type" "$duration"
            return 1
            ;;
    esac
}

# Get docker-compose configuration
# Extracts the configuration for a specific service from a docker-compose file.
# Uses yq if available for better parsing, otherwise falls back to awk.
#
# Input:
#   $1 - yaml_file: Path to the docker-compose YAML file
#   $2 - container_name: The name of the service to extract
# Output: Service configuration as text
# Example: get_docker_compose_config "docker-compose.yml" "web"
get_docker_compose_config() {
    local yaml_file="$1"
    local container_name="$2"
    
    if command -v yq &> /dev/null; then
        # Use yq to extract the specific service configuration
        yq eval ".services.$container_name" "$yaml_file" 2>/dev/null
    else
        # Fallback to awk parsing for service extraction
        awk -v container="$container_name" '
        BEGIN { in_service = 0; in_target = 0; indent = 0 }
        /^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*:/ {
            if (in_target) {
                if (indent <= current_indent) {
                    in_target = 0
                }
            }
            current_indent = length($0) - length(gensub(/^[[:space:]]*/, "", 1, $0))
            service_name = gensub(/^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*):.*/, "\\1", 1, $0)
            if (service_name == container) {
                in_target = 1
                current_indent = current_indent
            }
        }
        in_target { print }
        ' "$yaml_file"
    fi
}

# Get custom configuration
# Extracts configuration for a specific container from a custom YAML file.
# This is a simplified version that looks for container-related lines.
#
# Input:
#   $1 - yaml_file: Path to the custom YAML file
#   $2 - container_name: The name of the container to extract
# Output: Container configuration as text
# Example: get_custom_config "custom-app.yml" "my-app"
get_custom_config() {
    local yaml_file="$1"
    local container_name="$2"
    
    # This is a simplified version for custom YAML
    # In practice, you might want more sophisticated parsing
    # Look for lines around the container name (10 lines before and 2 after)
    grep -A 10 -B 2 "$container_name" "$yaml_file" 2>/dev/null
}

# Extract image name from container config
# Extracts the image name from a container configuration block.
# Uses yq if available, otherwise falls back to grep/sed.
#
# Input:
#   $1 - container_config: The container configuration text
# Output: Image name or empty string
# Example: extract_image_name "$container_config"
extract_image_name() {
    local container_config="$1"
    
    if command -v yq &> /dev/null; then
        # Use yq to extract the image field
        echo "$container_config" | yq eval '.image' 2>/dev/null
    else
        # Fallback to grep/sed extraction
        echo "$container_config" | grep '^[[:space:]]*image:' | sed 's/^[[:space:]]*image:[[:space:]]*//'
    fi
}

# Extract ports from container config
# Extracts port mappings from a container configuration block.
# Uses yq if available, otherwise falls back to grep/sed.
#
# Input:
#   $1 - container_config: The container configuration text
# Output: List of port mappings (one per line)
# Example: extract_ports "$container_config"
extract_ports() {
    local container_config="$1"
    
    if command -v yq &> /dev/null; then
        # Use yq to extract all port mappings
        echo "$container_config" | yq eval '.ports[]' 2>/dev/null
    else
        # Fallback to grep/sed extraction
        # Look for port mappings (lines starting with dash followed by port numbers)
        echo "$container_config" | grep '^[[:space:]]*-[[:space:]]*[0-9]' | sed 's/^[[:space:]]*-[[:space:]]*//'
    fi
}

# Extract environment variables from container config
# Extracts environment variable definitions from a container configuration block.
# Uses yq if available, otherwise falls back to grep/sed.
#
# Input:
#   $1 - container_config: The container configuration text
# Output: List of environment variables (one per line)
# Example: extract_environment "$container_config"
extract_environment() {
    local container_config="$1"
    
    if command -v yq &> /dev/null; then
        # Use yq to extract all environment variables
        echo "$container_config" | yq eval '.environment[]' 2>/dev/null
    else
        # Fallback to grep/sed extraction
        # Look for environment variables (lines starting with dash followed by uppercase variable names)
        echo "$container_config" | grep '^[[:space:]]*-[[:space:]]*[A-Z_][A-Z0-9_]*=' | sed 's/^[[:space:]]*-[[:space:]]*//'
    fi
}

# Extract volumes from container config
# Extracts volume mappings from a container configuration block.
# Uses yq if available, otherwise falls back to grep/sed.
#
# Input:
#   $1 - container_config: The container configuration text
# Output: List of volume mappings (one per line)
# Example: extract_volumes "$container_config"
extract_volumes() {
    local container_config="$1"
    
    if command -v yq &> /dev/null; then
        # Use yq to extract all volume mappings
        echo "$container_config" | yq eval '.volumes[]' 2>/dev/null
    else
        # Fallback to grep/sed extraction
        # Look for volume mappings (lines starting with dash followed by paths)
        echo "$container_config" | grep '^[[:space:]]*-[[:space:]]*[a-zA-Z0-9._/-]' | sed 's/^[[:space:]]*-[[:space:]]*//'
    fi
}

# Generate docker run command from YAML config
# Converts a container configuration from YAML into a docker run command.
# Extracts image, ports, environment variables, and volumes to build the command.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - container_name: The name of the container
#   $3 - yaml_type: The type of YAML file
# Output: Complete docker run command string
# Example: generate_docker_run_command "docker-compose.yml" "web" "docker-compose"
generate_docker_run_command() {
    local yaml_file="$1"
    local container_name="$2"
    local yaml_type="$3"
    
    # Get the container configuration from YAML
    local container_config=$(get_container_config "$yaml_file" "$container_name" "$yaml_type")
    if [[ -z "$container_config" ]]; then
        log_error "YAML_PARSER" "$container_name" "Could not extract container configuration"
        return 1
    fi
    
    # Extract the image name
    local image_name=$(extract_image_name "$container_config")
    if [[ -z "$image_name" ]]; then
        log_error "YAML_PARSER" "$container_name" "Could not extract image name"
        return 1
    fi
    
    # Start building the docker run command
    local docker_cmd="docker run -d --name $container_name"
    
    # Add port mappings
    local ports=$(extract_ports "$container_config")
    if [[ -n "$ports" ]]; then
        while IFS= read -r port; do
            docker_cmd="$docker_cmd -p $port"
        done <<< "$ports"
    fi
    
    # Add environment variables
    local env_vars=$(extract_environment "$container_config")
    if [[ -n "$env_vars" ]]; then
        while IFS= read -r env_var; do
            docker_cmd="$docker_cmd -e $env_var"
        done <<< "$env_vars"
    fi
    
    # Add volume mappings
    local volumes=$(extract_volumes "$container_config")
    if [[ -n "$volumes" ]]; then
        while IFS= read -r volume; do
            docker_cmd="$docker_cmd -v $volume"
        done <<< "$volumes"
    fi
    
    # Add the image name at the end
    docker_cmd="$docker_cmd $image_name"
    
    echo "$docker_cmd"
}

# Parse YAML file and return summary
# Analyzes a YAML file and provides a human-readable summary of its contents.
# Shows file type, containers, and their associated images.
#
# Input:
#   $1 - yaml_file: Path to the YAML file to analyze
# Output: Formatted summary of the YAML file contents
# Example: parse_yaml_summary "docker-compose.yml"
parse_yaml_summary() {
    local yaml_file="$1"
    
    # Validate the YAML file first
    if ! validate_yaml_file "$yaml_file"; then
        return 1
    fi
    
    # Detect the YAML type
    local yaml_type=$(detect_yaml_type "$yaml_file")
    # Extract all container names
    local containers=$(extract_container_names "$yaml_file" "$yaml_type")
    
    # Display the summary
    echo "=== YAML File Summary ==="
    echo "File: $yaml_file"
    echo "Type: $yaml_type"
    echo "Containers:"
    
    if [[ -n "$containers" ]]; then
        # Show each container with its image
        while IFS= read -r container; do
            local container_config=$(get_container_config "$yaml_file" "$container" "$yaml_type")
            local image_name=$(extract_image_name "$container_config")
            echo "  - $container (image: $image_name)"
        done <<< "$containers"
    else
        echo "  No containers found"
    fi
    
    echo "========================"
}

# Validate container name
# Checks if a container name follows Docker naming conventions.
# Ensures the name is valid for use with Docker commands.
#
# Input:
#   $1 - container_name: The container name to validate
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_container_name "my-container"
validate_container_name() {
    local container_name="$1"
    
    # Check if name is empty
    if [[ -z "$container_name" ]]; then
        return 1
    fi
    
    # Check if name contains invalid characters
    # Docker container names can only contain alphanumeric characters, hyphens, and underscores
    if [[ "$container_name" =~ [^a-zA-Z0-9._-] ]]; then
        return 1
    fi
    
    # Check if name starts with a letter or underscore
    # Docker container names must start with a letter or underscore
    if [[ ! "$container_name" =~ ^[a-zA-Z_][a-zA-Z0-9._-]*$ ]]; then
        return 1
    fi
    
    return 0
}

# Resolve actual Docker container name from YAML
# Determines the actual Docker container name from a service name in a YAML file.
# If container_name is specified in the YAML, uses that; otherwise uses the service name.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - service_name: The service name from the YAML
# Output: The actual Docker container name
# Example: resolve_container_name "docker-compose.yml" "web"
resolve_container_name() {
    local yaml_file="$1"
    local service_name="$2"
    
    if command -v yq &> /dev/null; then
        # Use yq to check if container_name is specified, otherwise use service name
        local container_name=$(yq eval ".services.$service_name.container_name // \"$service_name\"" "$yaml_file" 2>/dev/null)
        echo "$container_name"
    else
        # Fallback: try to extract with grep
        # Look for container_name in the service configuration
        local container_name=$(grep -A 10 "services:" "$yaml_file" | grep -A 10 "$service_name:" | grep "container_name:" | head -1 | sed 's/.*container_name:[[:space:]]*//' | tr -d '"' | tr -d "'")
        if [[ -n "$container_name" ]]; then
            echo "$container_name"
        else
            echo "$service_name"
        fi
    fi
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
        # Use yq to extract the custom readiness timeout
        yq eval ".services.$container_name.x-docker-ops.readiness_timeout // \"\"" "$yaml_file" 2>/dev/null | grep -E '^[0-9]+$' || true
    else
        echo ""  # Fallback: not supported without yq
    fi
}

# Extract or generate project name from YAML file
# Extracts the project name from a YAML file, or generates one if not present.
# Uses configurable pattern for dynamic generation.
#
# Input:
#   $1 - yaml_file: Path to the YAML file
#   $2 - service_name: The service name for dynamic generation
# Output: Project name (extracted or generated)
# Example: extract_project_name "docker-compose.yml" "web"
extract_project_name() {
    local yaml_file="$1"
    local service_name="$2"
    
    # Extract project name from YAML file
    local project_name=""
    
    if command -v yq &> /dev/null; then
        # Use yq to extract the name field
        project_name=$(yq eval '.name' "$yaml_file" 2>/dev/null)
    else
        # Fallback: use grep/sed to extract name
        project_name=$(grep -E '^name:' "$yaml_file" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'")
    fi
    
    # If project name is not found or is null/empty, generate it dynamically
    if [[ -z "$project_name" || "$project_name" == "null" ]]; then
        # Check for environment variable first
        if [[ -n "$DOCKER_OPS_PROJECT_NAME_PATTERN" ]]; then
            # Use the environment variable pattern
            project_name=$(echo "$DOCKER_OPS_PROJECT_NAME_PATTERN" | sed "s/<service.name>/$service_name/g" | sed "s/<DD-MM-YY>/$(date +%d-%m-%y)/g")
        else
            # Default pattern: project-<service.name>-DD-MM-YY
            project_name="project-$service_name-$(date +%d-%m-%y)"
        fi
    fi
    
    echo "$project_name"
} 