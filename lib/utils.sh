#!/usr/bin/env bash

# Utility Functions Module
# Provides common helper functions, input validation, error handling, and color output

# Color codes for output formatting
# These ANSI escape codes provide colored output for better user experience
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Print colored output
# Generic function to print text with a specified color.
# Automatically resets the color after printing.
#
# Input:
#   $1 - color: The color code to use
#   $2 - message: The message to print
# Output: Colored message to stdout
# Example: print_color "$RED" "Error message"
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Print red text
# Convenience function for printing error messages in red.
#
# Input:
#   $1 - message: The message to print in red
# Output: Red message to stdout
# Example: print_red "This is an error"
print_red() {
    print_color "$RED" "$1"
}

# Print green text
# Convenience function for printing success messages in green.
#
# Input:
#   $1 - message: The message to print in green
# Output: Green message to stdout
# Example: print_green "Operation successful"
print_green() {
    print_color "$GREEN" "$1"
}

# Print yellow text
# Convenience function for printing warning messages in yellow.
#
# Input:
#   $1 - message: The message to print in yellow
# Output: Yellow message to stdout
# Example: print_yellow "Warning: disk space low"
print_yellow() {
    print_color "$YELLOW" "$1"
}

# Print blue text
# Convenience function for printing info messages in blue.
#
# Input:
#   $1 - message: The message to print in blue
# Output: Blue message to stdout
# Example: print_blue "Processing container..."
print_blue() {
    print_color "$BLUE" "$1"
}

# Print purple text
# Convenience function for printing special messages in purple.
#
# Input:
#   $1 - message: The message to print in purple
# Output: Purple message to stdout
# Example: print_purple "Special operation"
print_purple() {
    print_color "$PURPLE" "$1"
}

# Print cyan text
# Convenience function for printing headers in cyan.
#
# Input:
#   $1 - message: The message to print in cyan
# Output: Cyan message to stdout
# Example: print_cyan "Section Header"
print_cyan() {
    print_color "$CYAN" "$1"
}

# Print white text
# Convenience function for printing highlighted text in white.
#
# Input:
#   $1 - message: The message to print in white
# Output: White message to stdout
# Example: print_white "Important information"
print_white() {
    print_color "$WHITE" "$1"
}

# Print success message
# Prints a success message with a green checkmark prefix.
# Used for indicating successful operations.
#
# Input:
#   $1 - message: The success message to print
# Output: Success message with checkmark to stdout
# Example: print_success "Container started successfully"
print_success() {
    print_green "✓ $1"
}

# Print error message
# Prints an error message with a red X prefix.
# Used for indicating failed operations.
#
# Input:
#   $1 - message: The error message to print
# Output: Error message with X to stdout
# Example: print_error "Failed to start container"
print_error() {
    print_red "✗ $1"
}

# Print warning message
# Prints a warning message with a yellow warning symbol prefix.
# Used for indicating potential issues.
#
# Input:
#   $1 - message: The warning message to print
# Output: Warning message with warning symbol to stdout
# Example: print_warning "Container may not be fully ready"
print_warning() {
    print_yellow "⚠ $1"
}

# Print info message
# Prints an info message with a blue info symbol prefix.
# Used for providing general information.
#
# Input:
#   $1 - message: The info message to print
# Output: Info message with info symbol to stdout
# Example: print_info "Container is starting up"
print_info() {
    print_blue "ℹ $1"
}

# Print header
# Prints a formatted header with cyan borders.
# Used for section headers in output.
#
# Input:
#   $1 - message: The header message to print
# Output: Formatted header to stdout
# Example: print_header "Docker Operations"
print_header() {
    echo
    print_cyan "=========================================="
    print_cyan "$1"
    print_cyan "=========================================="
    echo
}

# Print section
# Prints a section divider with blue formatting.
# Used for subsection headers in output.
#
# Input:
#   $1 - message: The section message to print
# Output: Formatted section to stdout
# Example: print_section "Container Status"
print_section() {
    echo
    print_blue "--- $1 ---"
    echo
}

# Validate input parameters
# Checks if a parameter has a value and optionally if it's required.
# Used for validating function parameters.
#
# Input:
#   $1 - param_name: The name of the parameter (for error messages)
#   $2 - param_value: The value to validate
#   $3 - required: Whether the parameter is required (optional, defaults to true)
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_input "container_name" "$container_name" "true"
validate_input() {
    local param_name="$1"
    local param_value="$2"
    local required="${3:-true}"
    
    # Check if parameter is required and empty
    if [[ "$required" == "true" && -z "$param_value" ]]; then
        print_error "Parameter '$param_name' is required"
        return 1
    fi
    
    return 0
}

# Validate file path
# Checks if a file exists, is readable, and optionally provides a description.
# Used for validating file paths before operations.
#
# Input:
#   $1 - file_path: The file path to validate
#   $2 - description: Description of the file (optional, defaults to "File")
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_file_path "docker-compose.yml" "YAML configuration file"
validate_file_path() {
    local file_path="$1"
    local description="${2:-File}"
    
    # Check if path is provided
    if [[ -z "$file_path" ]]; then
        print_error "$description path is required"
        return 1
    fi
    
    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
        print_error "$description not found: $file_path"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$file_path" ]]; then
        print_error "$description not readable: $file_path"
        return 1
    fi
    
    return 0
}

# Validate directory path
# Checks if a directory exists, is writable, and optionally provides a description.
# Used for validating directory paths before operations.
#
# Input:
#   $1 - dir_path: The directory path to validate
#   $2 - description: Description of the directory (optional, defaults to "Directory")
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_directory_path "/tmp" "Temporary directory"
validate_directory_path() {
    local dir_path="$1"
    local description="${2:-Directory}"
    
    # Check if path is provided
    if [[ -z "$dir_path" ]]; then
        print_error "$description path is required"
        return 1
    fi
    
    # Check if directory exists
    if [[ ! -d "$dir_path" ]]; then
        print_error "$description not found: $dir_path"
        return 1
    fi
    
    # Check if directory is writable
    if [[ ! -w "$dir_path" ]]; then
        print_error "$description not writable: $dir_path"
        return 1
    fi
    
    return 0
}

# Check if command exists
# Verifies whether a command is available in the system PATH.
# Used for checking dependencies before operations.
#
# Input:
#   $1 - command: The command to check
# Output: None
# Return code: 0 if command exists, 1 if it doesn't exist
# Example: command_exists "docker"
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if user has sudo privileges
# Tests whether the current user has sudo privileges without requiring a password.
# Used for determining if elevated privileges are available.
#
# Input: None
# Output: None
# Return code: 0 if sudo privileges available, 1 if not
# Example: has_sudo_privileges
has_sudo_privileges() {
    sudo -n true 2>/dev/null
}

# Get script directory
# Returns the absolute path of the directory containing the current script.
# Useful for finding relative paths from the script location.
#
# Input: None
# Output: Absolute path to script directory
# Example: get_script_dir
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

# Get script name
# Returns the filename of the current script.
# Useful for logging and error messages.
#
# Input: None
# Output: Script filename
# Example: get_script_name
get_script_name() {
    basename "${BASH_SOURCE[0]}"
}

# Get absolute path
# Converts a relative path to an absolute path.
# Handles both files and directories.
#
# Input:
#   $1 - path: The path to convert to absolute
# Output: Absolute path
# Example: get_absolute_path "./config.json"
get_absolute_path() {
    local path="$1"
    if [[ -d "$path" ]]; then
        # For directories, change to the directory and get current path
        cd "$path" && pwd
    else
        # For files, get the directory path and append the filename
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

# Create backup of file
# Creates a timestamped backup copy of a file.
# Useful for preserving files before modifications.
#
# Input:
#   $1 - file_path: The path to the file to backup
#   $2 - backup_suffix: Custom suffix for backup file (optional)
# Output: Path to backup file
# Return code: 0 if successful, 1 if failed
# Example: create_backup "config.json" ".backup"
create_backup() {
    local file_path="$1"
    local backup_suffix="${2:-.backup.$(date +%Y%m%d_%H%M%S)}"
    
    # Check if file exists before attempting backup
    if [[ -f "$file_path" ]]; then
        local backup_path="${file_path}${backup_suffix}"
        cp "$file_path" "$backup_path"
        print_info "Backup created: $backup_path"
        echo "$backup_path"
    else
        print_warning "File not found for backup: $file_path"
        return 1
    fi
}

# Restore file from backup
# Restores a file from a backup copy.
# Useful for recovering from failed operations.
#
# Input:
#   $1 - backup_path: The path to the backup file
#   $2 - target_path: The path where the file should be restored
# Output: None
# Return code: 0 if successful, 1 if failed
# Example: restore_from_backup "config.json.backup" "config.json"
restore_from_backup() {
    local backup_path="$1"
    local target_path="$2"
    
    # Check if backup file exists before attempting restore
    if [[ -f "$backup_path" ]]; then
        cp "$backup_path" "$target_path"
        print_success "File restored from backup: $backup_path"
        return 0
    else
        print_error "Backup file not found: $backup_path"
        return 1
    fi
}

# Generate random string
# Generates a random alphanumeric string of specified length.
# Useful for creating temporary names or tokens.
#
# Input:
#   $1 - length: The length of the random string (optional, defaults to 8)
# Output: Random alphanumeric string
# Example: generate_random_string 12
generate_random_string() {
    local length="${1:-8}"
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

# Generate timestamp
# Generates a human-readable timestamp in local time.
# Format: YYYY-MM-DD HH:MM:SS
#
# Input: None
# Output: Timestamp string
# Example: generate_timestamp
generate_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Generate ISO timestamp
# Generates an ISO 8601 compliant timestamp in UTC.
# Format: YYYY-MM-DDTHH:MM:SSZ
#
# Input: None
# Output: ISO timestamp string
# Example: generate_iso_timestamp
generate_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Format duration
# Converts seconds into a human-readable duration format.
# Shows hours, minutes, and seconds as appropriate.
#
# Input:
#   $1 - seconds: The number of seconds to format
# Output: Formatted duration string
# Example: format_duration 3661
format_duration() {
    local seconds="$1"
    
    if [[ $seconds -lt 60 ]]; then
        # Less than a minute: show seconds only
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        # Less than an hour: show minutes and seconds
        local minutes=$((seconds / 60))
        local remaining_seconds=$((seconds % 60))
        echo "${minutes}m ${remaining_seconds}s"
    else
        # An hour or more: show hours, minutes, and seconds
        local hours=$((seconds / 3600))
        local minutes=$(((seconds % 3600) / 60))
        local remaining_seconds=$((seconds % 60))
        echo "${hours}h ${minutes}m ${remaining_seconds}s"
    fi
}

# Wait for user confirmation
# Prompts the user for confirmation with a customizable message and default.
# Returns true if user confirms, false otherwise.
#
# Input:
#   $1 - message: The confirmation message to display
#   $2 - default: The default response (optional, defaults to "n")
# Output: None
# Return code: 0 if confirmed, 1 if not confirmed
# Example: confirm_action "Are you sure you want to delete this container?"
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    # Build the prompt based on the default value
    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi
    
    # Read user input
    read -p "$prompt" -r response
    
    # Use default if no response provided
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    # Return true if response is yes (case insensitive)
    [[ "$response" =~ ^[Yy]$ ]]
}

# Show progress bar
# Displays a visual progress bar with percentage.
# Useful for long-running operations.
#
# Input:
#   $1 - current: Current progress value
#   $2 - total: Total value for 100%
#   $3 - width: Width of the progress bar (optional, defaults to 50)
#   $4 - label: Label for the progress bar (optional, defaults to "Progress")
# Output: Progress bar to stdout
# Example: show_progress 25 100 50 "Downloading"
show_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local label="${4:-Progress}"
    
    # Calculate percentage
    local percentage=$((current * 100 / total))
    # Calculate filled and empty segments
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Build the progress bar
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done
    for ((i=0; i<empty; i++)); do
        bar="${bar}░"
    done
    
    # Display the progress bar (carriage return for overwriting)
    printf "\r%s: [%s] %d%%" "$label" "$bar" "$percentage"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Show simple dots animation
# Displays a simple dots animation for waiting operations.
# Uses minimal resources and provides visual feedback.
#
# Input:
#   $1 - message: The message to display before the animation (optional)
# Output: Animated dots to stdout
# Example: show_dots_animation "Waiting for container"
show_dots_animation() {
    local message="${1:-}"
    local dots=""
    local max_dots=3
    
    # Print initial message if provided
    if [[ -n "$message" ]]; then
        printf "%s" "$message"
    fi
    
    # Animate dots
    for ((i=0; i<=max_dots; i++)); do
        printf "\r%s%s" "$message" "$dots"
        sleep 0.5
        dots="${dots}."
    done
    
    # Clear the line
    printf "\r%*s\r" 80 ""
}

# Show simple dots animation only
# Displays only animating dots for waiting operations.
# Uses minimal resources and provides visual feedback.
#
# Input:
#   $1 - max_dots: Maximum number of dots to show (optional, defaults to 3)
# Output: Animated dots to stdout
# Example: show_waiting_dots 3
show_waiting_dots() {
    local max_dots="${1:-5}"  # Default to 5 if no parameter provided
   

    # Show one cycle of dots animation
    for ((i=0; i<=max_dots; i++)); do
        # Clear previous dots and show current state
        printf "\r%*s\r" 80 ""
        for ((j=0; j<i; j++)); do
            printf "."
        done
        sleep 0.3
    done
    
    # Don't clear the line at the end - let the next cycle handle it
    # This makes the animation more visible
}

# Global spinner index for maintaining state between calls
# _SPINNER_INDEX=0

# Show spinner animation
# Displays a simple spinner animation for waiting operations.
# Uses minimal resources and provides visual feedback.
#
# Input:
#   $1 - message: The message to display before the spinner (optional)
# Output: Spinner animation to stdout
# Example: show_spinner_animation "Processing"
# show_spinner_animation() {
#     local message="${1:-}"
#     local spinner_chars=("-" "\\" "|" "/")
#     
#     # Print initial message if provided
#     if [[ -n "$message" ]]; then
#         printf "%s " "$message"
#     fi
#     
#     # Animate spinner
#     printf "%s" "${spinner_chars[$_SPINNER_INDEX]}"
#     sleep 0.2
#     
#     # Update spinner index for next call
#     _SPINNER_INDEX=$(( (_SPINNER_INDEX + 1) % ${#spinner_chars[@]} ))
#     
#     # Clear the spinner character and move back
#     printf "\b \b"
# }

# Show waiting animation with timeout
# Displays a waiting animation for a specified duration.
# Provides visual feedback during wait operations.
#
# Input:
#   $1 - duration: Duration to show animation in seconds
#   $2 - message: The message to display (optional, defaults to "Waiting")
#   $3 - animation_type: Type of animation - "dots" or "spinner" (optional, defaults to "dots")
# Output: Animation for the specified duration
# Example: show_waiting_animation 10 "Waiting for container" "dots"
show_waiting_animation() {
    local duration="$1"
    local message="${2:-Waiting}"
    local animation_type="${3:-dots}"
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    # Show animation until timeout
    while [[ $(date +%s) -lt $end_time ]]; do
        if [[ "$animation_type" == "spinner" ]]; then
            # show_spinner_animation "$message"  # Commented out for now
            show_dots_animation "$message"
        else
            show_dots_animation "$message"
        fi
    done
    
    # Clear the line when done
    printf "\r%*s\r" 80 ""
}

# Show waiting animation with condition
# Displays a waiting animation until a condition is met or timeout occurs.
# Provides visual feedback during wait operations with condition checking.
#
# Input:
#   $1 - condition_command: Command to check condition (should return 0 when condition is met)
#   $2 - timeout: Maximum time to wait in seconds
#   $3 - message: The message to display (optional, defaults to "Waiting")
#   $4 - animation_type: Type of animation - "dots" or "spinner" (optional, defaults to "dots")
#   $5 - check_interval: Interval between condition checks in seconds (optional, defaults to 1)
# Output: Animation until condition is met or timeout
# Return code: 0 if condition met, 1 if timeout
# Example: show_waiting_animation_with_condition "test -f /tmp/file" 30 "Waiting for file" "dots"
show_waiting_animation_with_condition() {
    local condition_command="$1"
    local timeout="$2"
    local message="${3:-Waiting}"
    local animation_type="${4:-dots}"
    local check_interval="${5:-1}"
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    local last_check_time=0
    
    # Show animation until condition is met or timeout
    while [[ $(date +%s) -lt $end_time ]]; do
        # Check condition at specified intervals
        local current_time=$(date +%s)
        if [[ $((current_time - last_check_time)) -ge $check_interval ]]; then
            if eval "$condition_command" >/dev/null 2>&1; then
                # Clear the line when condition is met
                printf "\r%*s\r" 80 ""
                return 0
            fi
            last_check_time=$current_time
        fi
        
        # Show animation
        if [[ "$animation_type" == "spinner" ]]; then
            # show_spinner_animation "$message"  # Commented out for now
            show_dots_animation "$message"
        else
            show_dots_animation "$message"
        fi
    done
    
    # Clear the line when timeout occurs
    printf "\r%*s\r" 80 ""
    return 1
}

# =============================================================================
# SIGNAL-BASED ANIMATION CONTROL
# =============================================================================

# Global variables for signal-based animation control
_ANIMATION_PID=""
_ANIMATION_RUNNING=false
_ANIMATION_SIGNAL_RECEIVED=false
_ANIMATION_SIGNAL_FILE=""

# Signal handler for stopping animation
# Called when SIGUSR1 is received to stop the animation
animation_signal_handler() {
    _ANIMATION_SIGNAL_RECEIVED=true
    _ANIMATION_RUNNING=false
}

# Start continuous dots animation with signal control
# Starts a background process that shows dots animation until SIGUSR1 is received
# Uses SIGUSR1 to signal the animation to stop
#
# Input:
#   $1 - dots_count: Number of dots to show in animation (optional, defaults to 3)
# Output: None
# Side Effects: 
#   - Starts background animation process
#   - Sets up signal handler for SIGUSR1
#   - Sets _ANIMATION_PID to the background process ID
# Example: start_signal_animation 5
start_signal_animation() {
    local dots_count="${1:-3}"  # Default to 3 dots if not specified
    
    # Clear any existing animation state
    _ANIMATION_SIGNAL_RECEIVED=false
    _ANIMATION_RUNNING=true
    
    # Create a temporary file for signaling
    local signal_file="/tmp/docker_ops_animation_$$"
    rm -f "$signal_file"
    
    # Start animation in background process
    (
        # Set up signal handler for this process
        trap 'rm -f "$signal_file"; printf "\r%*s\r" 80 ""; exit 0' SIGUSR1 EXIT
        
        # Run animation until signal file is created or signal received
        while [[ ! -f "$signal_file" ]]; do
            show_waiting_dots "$dots_count"
        done
        
        # Clean up and exit
        rm -f "$signal_file"
        printf "\r%*s\r" 80 ""
    ) &
    
    _ANIMATION_PID=$!
    _ANIMATION_SIGNAL_FILE="$signal_file"
    log_debug "ANIMATION" "" "Started signal-based animation with PID: $_ANIMATION_PID, dots: $dots_count"
}

# Stop continuous animation via signal
# Sends SIGUSR1 to the animation process to stop it gracefully
#
# Input: None
# Output: None
# Side Effects:
#   - Sends SIGUSR1 to animation process
#   - Waits for process to terminate
#   - Clears _ANIMATION_PID
# Example: stop_signal_animation
stop_signal_animation() {
    if [[ -n "$_ANIMATION_PID" ]] && kill -0 "$_ANIMATION_PID" 2>/dev/null; then
        log_debug "ANIMATION" "" "Stopping signal-based animation (PID: $_ANIMATION_PID)"
        
        # Create signal file to stop animation
        if [[ -n "$_ANIMATION_SIGNAL_FILE" ]]; then
            touch "$_ANIMATION_SIGNAL_FILE" 2>/dev/null
        fi
        
        # Also send SIGUSR1 as backup
        kill -SIGUSR1 "$_ANIMATION_PID" 2>/dev/null
        
        # Wait for process to terminate (with timeout)
        local wait_time=0
        local max_wait=3
        while [[ $wait_time -lt $max_wait ]] && kill -0 "$_ANIMATION_PID" 2>/dev/null; do
            sleep 0.1
            wait_time=$((wait_time + 1))
        done
        
        # Force kill if still running
        if kill -0 "$_ANIMATION_PID" 2>/dev/null; then
            log_debug "ANIMATION" "" "Force killing animation process (PID: $_ANIMATION_PID)"
            kill -9 "$_ANIMATION_PID" 2>/dev/null
        fi
        
        # Wait for process to be reaped
        wait "$_ANIMATION_PID" 2>/dev/null || true
        
        # Clean up signal file
        if [[ -n "$_ANIMATION_SIGNAL_FILE" ]]; then
            rm -f "$_ANIMATION_SIGNAL_FILE" 2>/dev/null
        fi
        
        _ANIMATION_PID=""
        _ANIMATION_RUNNING=false
        _ANIMATION_SIGNAL_RECEIVED=false
        _ANIMATION_SIGNAL_FILE=""
        
        # Ensure line is cleared after animation stops
        printf "\r%*s\r" 80 ""
        
        log_debug "ANIMATION" "" "Signal-based animation stopped"
    fi
}

# Check if animation is currently running
# Returns true if animation process is active
#
# Input: None
# Output: None
# Return code: 0 if animation is running, 1 if not
# Example: if is_animation_running; then echo "Animation active"; fi
is_animation_running() {
    [[ -n "$_ANIMATION_PID" ]] && kill -0 "$_ANIMATION_PID" 2>/dev/null
}

# Cleanup animation resources
# Ensures any running animation is stopped and resources are cleaned up
# Should be called on script exit or error conditions
#
# Input: None
# Output: None
# Side Effects: Stops any running animation and clears state
# Example: cleanup_animation
cleanup_animation() {
    # Always try to stop animation, even if we're not sure it's running
    if [[ -n "$_ANIMATION_PID" ]]; then
        log_debug "ANIMATION" "" "Cleaning up animation resources (PID: $_ANIMATION_PID)"
        
        # Try graceful stop first
        kill -SIGUSR1 "$_ANIMATION_PID" 2>/dev/null
        
        # Wait briefly for graceful termination
        local wait_time=0
        local max_wait=2
        while [[ $wait_time -lt $max_wait ]] && kill -0 "$_ANIMATION_PID" 2>/dev/null; do
            sleep 0.1
            wait_time=$((wait_time + 1))
        done
        
        # Force kill if still running
        if kill -0 "$_ANIMATION_PID" 2>/dev/null; then
            log_debug "ANIMATION" "" "Force killing animation process (PID: $_ANIMATION_PID)"
            kill -9 "$_ANIMATION_PID" 2>/dev/null
        fi
        
        # Wait for process to be reaped
        wait "$_ANIMATION_PID" 2>/dev/null || true
        
        # Clear state
        _ANIMATION_PID=""
        _ANIMATION_RUNNING=false
        _ANIMATION_SIGNAL_RECEIVED=false
        _ANIMATION_SIGNAL_FILE=""
        
        log_debug "ANIMATION" "" "Animation cleanup completed"
    fi
    
    # Also kill any orphaned animation processes that might be running
    # Look for background processes that might be animation processes
    local orphaned_pids=$(ps aux | grep -E "show_waiting_dots|animation" | grep -v grep | awk '{print $2}' 2>/dev/null || true)
    if [[ -n "$orphaned_pids" ]]; then
        log_debug "ANIMATION" "" "Killing orphaned animation processes: $orphaned_pids"
        echo "$orphaned_pids" | xargs -r kill -9 2>/dev/null || true
    fi
    
    # Clean up any orphaned signal files
    rm -f /tmp/docker_ops_animation_* 2>/dev/null || true
}

# Wait with signal-based animation
# Waits for a condition to be met while showing continuous animation
# Uses signal-based animation control for efficient operation
#
# Input:
#   $1 - condition_command: Command to check condition (should return 0 when condition is met)
#   $2 - timeout: Maximum time to wait in seconds
#   $3 - check_interval: Interval between condition checks in seconds (optional, defaults to 1)
#   $4 - dots_count: Number of dots to show in animation (optional, defaults to 3)
# Output: None
# Return code: 0 if condition met, 1 if timeout
# Example: wait_with_signal_animation "test -f /tmp/file" 30 1 5
wait_with_signal_animation() {
    local condition_command="$1"
    local timeout="$2"
    local check_interval="${3:-1}"
    local dots_count="${4:-3}"
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    local last_check_time=0
    
    # Start signal-based animation with specified dots
    start_signal_animation "$dots_count"
    
    # Wait for condition or timeout
    while [[ $(date +%s) -lt $end_time ]]; do
        # Check condition at specified intervals
        local current_time=$(date +%s)
        if [[ $((current_time - last_check_time)) -ge $check_interval ]]; then
            if eval "$condition_command" >/dev/null 2>&1; then
                stop_signal_animation
                return 0
            fi
            last_check_time=$current_time
        fi
        
        # Small sleep to prevent busy waiting
        sleep 0.1
    done
    
    # Timeout reached
    stop_signal_animation
    return 1
}

# Check if string contains substring
# Tests whether a string contains a specific substring.
# Case-sensitive comparison.
#
# Input:
#   $1 - string: The string to search in
#   $2 - substring: The substring to search for
# Output: None
# Return code: 0 if substring found, 1 if not found
# Example: contains "hello world" "world"
contains() {
    local string="$1"
    local substring="$2"
    [[ "$string" == *"$substring"* ]]
}

# Check if string starts with prefix
# Tests whether a string starts with a specific prefix.
# Case-sensitive comparison.
#
# Input:
#   $1 - string: The string to check
#   $2 - prefix: The prefix to check for
# Output: None
# Return code: 0 if string starts with prefix, 1 if not
# Example: starts_with "hello world" "hello"
starts_with() {
    local string="$1"
    local prefix="$2"
    [[ "$string" == "$prefix"* ]]
}

# Check if string ends with suffix
# Tests whether a string ends with a specific suffix.
# Case-sensitive comparison.
#
# Input:
#   $1 - string: The string to check
#   $2 - suffix: The suffix to check for
# Output: None
# Return code: 0 if string ends with suffix, 1 if not
# Example: ends_with "hello world" "world"
ends_with() {
    local string="$1"
    local suffix="$2"
    [[ "$string" == *"$suffix" ]]
}

# Trim whitespace from string
# Removes leading and trailing whitespace from a string.
# Uses sed for efficient processing.
#
# Input:
#   $1 - string: The string to trim
# Output: Trimmed string
# Example: trim "  hello world  "
trim() {
    local string="$1"
    echo "$string" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Convert string to lowercase
# Converts all characters in a string to lowercase.
# Uses tr for efficient processing.
#
# Input:
#   $1 - string: The string to convert
# Output: Lowercase string
# Example: to_lowercase "Hello World"
to_lowercase() {
    local string="$1"
    echo "$string" | tr '[:upper:]' '[:lower:]'
}

# Convert string to uppercase
# Converts all characters in a string to uppercase.
# Uses tr for efficient processing.
#
# Input:
#   $1 - string: The string to convert
# Output: Uppercase string
# Example: to_uppercase "hello world"
to_uppercase() {
    local string="$1"
    echo "$string" | tr '[:lower:]' '[:upper:]'
}

# Escape special characters in string
# Escapes special regex characters in a string for safe use in patterns.
# Useful for search and replace operations.
#
# Input:
#   $1 - string: The string to escape
# Output: Escaped string
# Example: escape_string "file.txt"
escape_string() {
    local string="$1"
    echo "$string" | sed 's/[][\\^$.*+?{}()|]/\\&/g'
}

# Unescape special characters in string
# Removes escape characters from a string.
# Reverse operation of escape_string.
#
# Input:
#   $1 - string: The string to unescape
# Output: Unescaped string
# Example: unescape_string "file\.txt"
unescape_string() {
    local string="$1"
    echo "$string" | sed 's/\\\([][\\^$.*+?{}()|]\)/\1/g'
}

# Split string by delimiter
# Splits a string into lines based on a delimiter.
# Useful for processing comma-separated values.
#
# Input:
#   $1 - string: The string to split
#   $2 - delimiter: The delimiter character
# Output: Lines of split string
# Example: split_string "a,b,c" ","
split_string() {
    local string="$1"
    local delimiter="$2"
    echo "$string" | tr "$delimiter" '\n'
}

# Join array elements with delimiter
# Joins array elements into a single string with a delimiter.
# Useful for building command arguments or paths.
#
# Input:
#   $1 - delimiter: The delimiter to use between elements
#   $2... - array elements: The elements to join
# Output: Joined string
# Example: join_array "," "a" "b" "c"
join_array() {
    local delimiter="$1"
    shift
    local array=("$@")
    local result=""
    
    # Build the result string with delimiters
    for ((i=0; i<${#array[@]}; i++)); do
        if [[ $i -gt 0 ]]; then
            result="${result}${delimiter}"
        fi
        result="${result}${array[i]}"
    done
    
    echo "$result"
}

# Check if port is available
# Tests whether a network port is available (not in use).
# Uses netstat to check for listening ports.
#
# Input:
#   $1 - port: The port number to check
# Output: None
# Return code: 0 if port is available, 1 if port is in use
# Example: is_port_available 8080
is_port_available() {
    local port="$1"
    ! netstat -tuln 2>/dev/null | grep -q ":$port "
}

# Find available port
# Finds an available port within a specified range.
# Useful for dynamic port allocation.
#
# Input:
#   $1 - start_port: Starting port number (optional, defaults to 8000)
#   $2 - end_port: Ending port number (optional, defaults to 9000)
# Output: Available port number or empty string if none found
# Return code: 0 if port found, 1 if no port available
# Example: find_available_port 8000 9000
find_available_port() {
    local start_port="${1:-8000}"
    local end_port="${2:-9000}"
    
    # Check each port in the range
    for port in $(seq "$start_port" "$end_port"); do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    return 1
}

# Get system information
# Displays basic system information for debugging and logging.
# Shows OS, architecture, hostname, user, and shell.
#
# Input: None
# Output: Formatted system information
# Example: get_system_info
get_system_info() {
    echo "=== System Information ==="
    echo "OS: $(uname -s)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Shell: $SHELL"
    echo "=========================="
}

# Get disk usage
# Retrieves disk usage percentage for a specified path.
# Useful for monitoring disk space.
#
# Input:
#   $1 - path: The path to check (optional, defaults to current directory)
# Output: Disk usage percentage (without % symbol)
# Example: get_disk_usage "/home"
get_disk_usage() {
    local path="${1:-.}"
    df -h "$path" | tail -1 | awk '{print $5}' | sed 's/%//'
}

# Get memory usage
# Retrieves current memory usage percentage.
# Shows percentage of used memory.
#
# Input: None
# Output: Memory usage percentage (without % symbol)
# Example: get_memory_usage
get_memory_usage() {
    free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}'
}

# Get CPU usage
# Retrieves current CPU usage percentage.
# Shows percentage of CPU being used.
#
# Input: None
# Output: CPU usage percentage (without % symbol)
# Example: get_cpu_usage
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
}

# Check if system is under load
# Determines if the system is under high load based on CPU and memory thresholds.
# Useful for deciding whether to proceed with resource-intensive operations.
#
# Input:
#   $1 - cpu_threshold: CPU usage threshold percentage (optional, defaults to 80)
#   $2 - memory_threshold: Memory usage threshold percentage (optional, defaults to 80)
# Output: None
# Return code: 0 if system is under load, 1 if not
# Example: is_system_under_load 90 85
is_system_under_load() {
    local cpu_threshold="${1:-80}"
    local memory_threshold="${2:-80}"
    
    # Get current usage
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    
    # Check if either CPU or memory exceeds thresholds
    if [[ $(echo "$cpu_usage > $cpu_threshold" | bc -l) -eq 1 ]] || \
       [[ $(echo "$memory_usage > $memory_threshold" | bc -l) -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Wait for system to be ready
# Waits for the system to be ready (not under high load) before proceeding.
# Useful for ensuring optimal conditions for operations.
#
# Input:
#   $1 - max_wait: Maximum time to wait in seconds (optional, defaults to 300)
#   $2 - check_interval: Interval between checks in seconds (optional, defaults to 10)
# Output: None
# Return code: 0 if system ready, 1 if timeout
# Example: wait_for_system_ready 600 30
wait_for_system_ready() {
    local max_wait="${1:-300}"
    local check_interval="${2:-10}"
    
    print_info "Waiting for system to be ready..."
    
    # Calculate end time
    local start_time=$(date +%s)
    local end_time=$((start_time + max_wait))
    
    # Poll system load until ready or timeout
    while [[ $(date +%s) -lt $end_time ]]; do
        if ! is_system_under_load; then
            print_success "System is ready"
            return 0
        fi
        
        # Show static waiting message with animating dots
        show_waiting_dots "Waiting for completion"
        
        sleep "$check_interval"
    done
    
    print_warning "System may still be under load after $max_wait seconds"
    return 1
}

# Create temporary file
# Creates a temporary file with a specified prefix and suffix.
# Falls back to timestamp-based naming if mktemp fails.
#
# Input:
#   $1 - prefix: Prefix for the temporary file (optional, defaults to "docker_ops")
#   $2 - suffix: Suffix for the temporary file (optional, defaults to ".tmp")
# Output: Path to created temporary file
# Example: create_temp_file "config" ".json"
create_temp_file() {
    local prefix="${1:-docker_ops}"
    local suffix="${2:-.tmp}"
    mktemp "/tmp/${prefix}_XXXXXX${suffix}" 2>/dev/null || mktemp "/tmp/${prefix}_$(date +%s)_$$${suffix}"
}

# Create temporary directory
# Creates a temporary directory with a specified prefix.
# Uses mktemp for secure temporary directory creation.
#
# Input:
#   $1 - prefix: Prefix for the temporary directory (optional, defaults to "docker_ops")
# Output: Path to created temporary directory
# Example: create_temp_dir "backup"
create_temp_dir() {
    local prefix="${1:-docker_ops}"
    mktemp -d "/tmp/${prefix}_XXXXXX"
}

# Clean up temporary files
# Removes temporary files older than one day.
# Helps prevent accumulation of temporary files.
#
# Input:
#   $1 - pattern: Pattern to match files for cleanup (optional, defaults to "docker_ops_*")
# Output: None
# Example: cleanup_temp_files "myapp_*"
cleanup_temp_files() {
    local pattern="${1:-docker_ops_*}"
    find /tmp -name "$pattern" -type f -mtime +1 -delete 2>/dev/null || true
}

# Send notification (if available)
# Sends a desktop notification if supported by the system.
# Supports both Linux (notify-send) and macOS (osascript).
#
# Input:
#   $1 - title: The notification title
#   $2 - message: The notification message
# Output: None
# Example: send_notification "Docker Ops" "Container started successfully"
send_notification() {
    local title="$1"
    local message="$2"
    
    # Try Linux notification system
    if command_exists notify-send; then
        notify-send "$title" "$message"
    elif command_exists osascript; then
        # Try macOS notification system
        osascript -e "display notification \"$message\" with title \"$title\""
    fi
}

# =============================================================================
# PROGRESS INDICATORS FOR CONTAINER GENERATION
# =============================================================================

# Show generation progress with animation
# Displays animated progress messages for container generation steps
# Provides visual feedback during the generation process
#
# Input:
#   $1 - step: The current step (1-4)
#   $2 - yaml_file: The YAML file being processed
#   $3 - container_name: The container name being generated
# Output: Animated progress message to stdout
# Example: show_generation_progress 1 "docker-compose.yml" "nginx"
show_generation_progress() {
    local step="$1"
    local yaml_file="$2"
    local container_name="$3"
    
    case "$step" in
        1)
            printf "\r%s" "📋 Extracting config from $(basename "$yaml_file")"
            show_waiting_dots 3
            ;;
        2)
            printf "\r%s" "🔧 Generating docker-compose file"
            show_waiting_dots 3
            ;;
        3)
            printf "\r%s" "🐳 Creating container '$container_name'"
            show_waiting_dots 3
            ;;
        4)
            printf "\r%s" "✅ Finalizing container setup"
            show_waiting_dots 3
            ;;
    esac
}

# Show generation step completion
# Displays a completion message for each generation step
# Clears the progress line and shows completion status
#
# Input:
#   $1 - step: The completed step (1-4)
#   $2 - yaml_file: The YAML file being processed
#   $3 - container_name: The container name being generated
# Output: Completion message to stdout
# Example: show_generation_step_complete 1 "docker-compose.yml" "nginx"
show_generation_step_complete() {
    local step="$1"
    local yaml_file="$2"
    local container_name="$3"
    
    # Clear the progress line
    printf "\r%*s\r" 80 ""
    
    case "$step" in
        1)
            print_success "Config extracted from $(basename "$yaml_file")"
            ;;
        2)
            print_success "Docker-compose file generated"
            ;;
        3)
            print_success "Container '$container_name' created"
            ;;
        4)
            print_success "Container setup completed"
            ;;
    esac
}

# =============================================================================
# INTERACTIVE MENU SYSTEM FOR GENERATE COMMAND
# =============================================================================

# Display main generate menu
# Shows the main menu for container generation options
#
# Input: None
# Output: Menu display to stdout
# Example: show_generate_menu
show_generate_menu() {
    clear
    print_header "Docker Container Generation"
    echo
    print_info "Configure your container (select options in any order):"
    echo
    echo "1) Select YAML file"
    echo "2) Select Docker image"
    echo "3) Build from Dockerfile"
    echo "4) Configure port mapping"
    echo "5) Configure volume mounting"
    echo "6) Configure environment variables"
    echo "7) Configure custom network"
    echo "8) Configure resource limits"
    echo "9) Build only (no run) - Show docker build command"
    echo "10) Generate container with current configuration"
    echo "11) Cancel"
    echo
    print_info "Enter your choice (1-11): "
}

# Display YAML generation submenu
# Shows available YAML files and allows selection
#
# Input: None (uses global YAML_FILES array)
# Output: Updates YAML_FILES global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_yaml_generation_menu
show_yaml_generation_menu() {
    clear
    print_header "Generate from YAML File"
    echo
    print_info "Available YAML files in current directory:"
    echo
    
    local yaml_files=($(find . -maxdepth 2 -name "*.yml" -o -name "*.yaml" | head -10))
    
    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        print_warning "No YAML files found in current directory"
        echo
        print_info "Please provide a YAML file path:"
        read -p "YAML file path: " yaml_path
        if [[ -n "$yaml_path" ]]; then
            YAML_FILES=("$yaml_path")
            return 0
        else
            return 1
        fi
    fi
    
    for i in "${!yaml_files[@]}"; do
        local file="${yaml_files[$i]}"
        local size=$(du -h "$file" | cut -f1)
        echo "$((i+1))) $(basename "$file") ($size)"
    done
    
    echo "$(( ${#yaml_files[@]} + 1 ))) Browse other location"
    echo "$(( ${#yaml_files[@]} + 2 ))) Back to main menu"
    echo
    print_info "Select YAML file (1-$(( ${#yaml_files[@]} + 2 ))): "
    
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#yaml_files[@]} ]]; then
        YAML_FILES=("${yaml_files[$((choice-1))]}")
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -eq $(( ${#yaml_files[@]} + 1 )) ]]; then
        print_info "Enter YAML file path:"
        read -p "Path: " yaml_path
        if [[ -n "$yaml_path" ]]; then
            YAML_FILES=("$yaml_path")
            return 0
        fi
    fi
    
    return 1
}

# Display Dockerfile build submenu
# Shows available Dockerfiles and allows selection
#
# Input: None (uses global DOCKERFILE_PATH and BUILD_CONTEXT variables)
# Output: Updates DOCKERFILE_PATH and BUILD_CONTEXT global variables
# Return code: 0 if selection made, 1 if cancelled
# Example: show_dockerfile_build_menu
show_dockerfile_build_menu() {
    clear
    print_header "Build from Dockerfile"
    echo
    print_info "Available Dockerfiles in current directory:"
    echo
    
    local dockerfiles=($(find . -maxdepth 3 -name "*Dockerfile*" | head -10))
    
    if [[ ${#dockerfiles[@]} -eq 0 ]]; then
        print_warning "No Dockerfile found in current directory"
        echo
        print_info "Please provide a Dockerfile path:"
        read -p "Dockerfile path: " dockerfile_path
        if [[ -n "$dockerfile_path" ]]; then
            DOCKERFILE_PATH="$dockerfile_path"
            BUILD_CONTEXT="."
            return 0
        else
            return 1
        fi
    fi
    
    for i in "${!dockerfiles[@]}"; do
        local dockerfile="${dockerfiles[$i]}"
        local dir=$(dirname "$dockerfile")
        echo "$((i+1))) $dockerfile (context: $dir)"
    done
    
    echo "$(( ${#dockerfiles[@]} + 1 ))) Browse other location"
    echo "$(( ${#dockerfiles[@]} + 2 ))) Back to main menu"
    echo
    print_info "Select Dockerfile (1-$(( ${#dockerfiles[@]} + 2 ))): "
    
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#dockerfiles[@]} ]]; then
        DOCKERFILE_PATH="${dockerfiles[$((choice-1))]}"
        BUILD_CONTEXT=$(dirname "${dockerfiles[$((choice-1))]}")
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -eq $(( ${#dockerfiles[@]} + 1 )) ]]; then
        print_info "Enter Dockerfile path:"
        read -p "Path: " dockerfile_path
        if [[ -n "$dockerfile_path" ]]; then
            DOCKERFILE_PATH="$dockerfile_path"
            print_info "Enter build context directory (default: current directory):"
            read -p "Context: " build_context
            BUILD_CONTEXT="${build_context:-.}"
            return 0
        fi
    fi
    
    return 1
}

# Display image generation submenu
# Shows available Docker images and allows selection
#
# Input: None (uses global IMAGE_NAME variable)
# Output: Updates IMAGE_NAME global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_image_generation_menu
show_image_generation_menu() {
    clear
    print_header "Generate from Docker Image"
    echo
    print_info "Available local images:"
    echo
    
    local images=($(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | head -10))
    
    if [[ ${#images[@]} -eq 0 ]]; then
        print_warning "No local images found"
        echo
        print_info "Please provide an image name:"
        read -p "Image name: " image_name
        if [[ -n "$image_name" ]]; then
            IMAGE_NAME="$image_name"
            return 0
        else
            return 1
        fi
    fi
    
    for i in "${!images[@]}"; do
        local image="${images[$i]}"
        echo "$((i+1))) $image"
    done
    
    echo "$(( ${#images[@]} + 1 ))) Enter custom image name"
    echo "$(( ${#images[@]} + 2 ))) Back to main menu"
    echo
    print_info "Select image (1-$(( ${#images[@]} + 2 ))): "
    
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#images[@]} ]]; then
        IMAGE_NAME="${images[$((choice-1))]}"
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -eq $(( ${#images[@]} + 1 )) ]]; then
        print_info "Enter image name:"
        read -p "Image: " image_name
        if [[ -n "$image_name" ]]; then
            IMAGE_NAME="$image_name"
            return 0
        fi
    fi
    
    return 1
}

# Display port mapping submenu
# Allows selection of common port mappings or custom input
#
# Input: None (uses global PORT_MAPPING variable)
# Output: Updates PORT_MAPPING global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_port_mapping_menu
show_port_mapping_menu() {
    clear
    print_header "Configure Port Mapping"
    echo
    print_info "Common port mappings:"
    echo
    echo "1) Web server (80:80)"
    echo "2) HTTPS (443:443)"
    echo "3) Database (3306:3306)"
    echo "4) Monitoring (8080:8080)"
    echo "5) Custom port mapping"
    echo "6) No port mapping"
    echo
    print_info "Select option (1-6): "
    
    read -r choice
    case "$choice" in
        1) PORT_MAPPING="80:80" ;;
        2) PORT_MAPPING="443:443" ;;
        3) PORT_MAPPING="3306:3306" ;;
        4) PORT_MAPPING="8080:8080" ;;
        5)
            print_info "Enter custom port mapping (host:container):"
            read -p "Port mapping: " PORT_MAPPING
            ;;
        6) PORT_MAPPING="" ;;
        *) return 1 ;;
    esac
    
    return 0
}

# Display volume mapping submenu
# Allows configuration of volume mappings
#
# Input: None (uses global VOLUME_MAPPING variable)
# Output: Updates VOLUME_MAPPING global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_volume_mapping_menu
show_volume_mapping_menu() {
    clear
    print_header "Configure Volume Mapping"
    echo
    print_info "Volume mapping options:"
    echo
    echo "1) No volume mapping"
    echo "2) Custom volume mapping"
    echo "3) Back to main menu"
    echo
    print_info "Select option (1-3): "
    
    read -r choice
    case "$choice" in
        1) VOLUME_MAPPING="" ;;
        2)
            print_info "Enter volume mapping (host_path:container_path):"
            read -p "Volume mapping: " volume_input
            
            if [[ -n "$volume_input" ]]; then
                # Extract host path for validation
                local host_path=$(echo "$volume_input" | cut -d':' -f1)
                
                if validate_volume_path "$host_path"; then
                    VOLUME_MAPPING="$volume_input"
                else
                    print_info "Volume mapping not set due to validation error"
                fi
            fi
            ;;
        3) return 1 ;;
        *) return 1 ;;
    esac
    
    return 0
}

# Display environment variables submenu
# Allows configuration of environment variables
#
# Input: None (uses global ENV_VARS variable)
# Output: Updates ENV_VARS global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_environment_menu
show_environment_menu() {
    clear
    print_header "Configure Environment Variables"
    echo
    print_info "Environment variable options:"
    echo
    echo "1) No environment variables"
    echo "2) Custom environment variables"
    echo "3) Back to main menu"
    echo
    print_info "Select option (1-3): "
    
    read -r choice
    case "$choice" in
        1) ENV_VARS="" ;;
        2)
            print_info "Enter environment variables (KEY=value,KEY2=value2):"
            read -p "Environment variables: " ENV_VARS
            ;;
        3) return 1 ;;
        *) return 1 ;;
    esac
    
    return 0
}

# Display network submenu
# Shows available networks and allows selection
#
# Input: None (uses global NETWORK_NAME variable)
# Output: Updates NETWORK_NAME global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_network_menu
show_network_menu() {
    clear
    print_header "Configure Network"
    echo
    print_info "Available networks:"
    echo
    
    local networks=($(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none"))
    
    if [[ ${#networks[@]} -eq 0 ]]; then
        print_warning "No custom networks found"
        echo
        echo "1) Use default bridge network"
        echo "2) Create new network"
        echo "3) Back to main menu"
        echo
        print_info "Select option (1-3): "
        
        read -r choice
        case "$choice" in
            1) NETWORK_NAME="" ;;
            2)
                print_info "Enter network name:"
                read -p "Network name: " NETWORK_NAME
                ;;
            3) return 1 ;;
            *) return 1 ;;
        esac
    else
        echo "1) Use default bridge network"
        for i in "${!networks[@]}"; do
            local network="${networks[$i]}"
            echo "$((i+2))) $network"
        done
        echo "$(( ${#networks[@]} + 2 ))) Create new network"
        echo "$(( ${#networks[@]} + 3 ))) Back to main menu"
        echo
        print_info "Select network (1-$(( ${#networks[@]} + 3 ))): "
        
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -eq 1 ]]; then
            NETWORK_NAME=""
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 2 ]] && [[ $choice -le $(( ${#networks[@]} + 1 )) ]]; then
            NETWORK_NAME="${networks[$((choice-2))]}"
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -eq $(( ${#networks[@]} + 2 )) ]]; then
            print_info "Enter network name:"
            read -p "Network name: " NETWORK_NAME
        else
            return 1
        fi
    fi
    
    return 0
}

# Display resource limits submenu
# Allows configuration of memory and CPU limits
#
# Input: None (uses global RESOURCE_LIMITS variable)
# Output: Updates RESOURCE_LIMITS global variable
# Return code: 0 if selection made, 1 if cancelled
# Example: show_resource_menu
show_resource_menu() {
    clear
    print_header "Configure Resource Limits"
    echo
    print_info "Resource limit options:"
    echo
    echo "1) No resource limits"
    echo "2) Memory limit only"
    echo "3) CPU limit only"
    echo "4) Both memory and CPU limits"
    echo "5) Back to main menu"
    echo
    print_info "Select option (1-5): "
    
    read -r choice
    case "$choice" in
        1) RESOURCE_LIMITS="" ;;
        2)
            print_info "Enter memory limit (e.g., 512m, 1g):"
            read -p "Memory limit: " memory_limit
            if [[ -n "$memory_limit" ]]; then
                RESOURCE_LIMITS="--memory $memory_limit"
            fi
            ;;
        3)
            print_info "Enter CPU limit (e.g., 0.5, 1.0):"
            read -p "CPU limit: " cpu_limit
            if [[ -n "$cpu_limit" ]]; then
                RESOURCE_LIMITS="--cpus $cpu_limit"
            fi
            ;;
        4)
            print_info "Enter memory limit (e.g., 512m, 1g):"
            read -p "Memory limit: " memory_limit
            print_info "Enter CPU limit (e.g., 0.5, 1.0):"
            read -p "CPU limit: " cpu_limit
            if [[ -n "$memory_limit" ]] && [[ -n "$cpu_limit" ]]; then
                RESOURCE_LIMITS="--memory $memory_limit --cpus $cpu_limit"
            fi
            ;;
        5) return 1 ;;
        *) return 1 ;;
    esac
    
    return 0
}

# Get container name from user input
# Prompts for container name or auto-generates one
#
# Input: None (uses global CONTAINER_NAME_FROM_FLAG variable)
# Output: Updates CONTAINER_NAME_FROM_FLAG global variable
# Return code: 0 if name set, 1 if cancelled
# Example: get_container_name
get_container_name() {
    clear
    print_header "Container Name"
    echo
    print_info "Enter container name (or press Enter for auto-generated name):"
    read -p "Container name: " container_name
    
    if [[ -n "$container_name" ]]; then
        CONTAINER_NAME_FROM_FLAG="$container_name"
    else
        # Auto-generate name based on image or YAML
        if [[ -n "$IMAGE_NAME" ]]; then
            CONTAINER_NAME_FROM_FLAG=$(generate_container_name_from_image "$IMAGE_NAME")
        else
            CONTAINER_NAME_FROM_FLAG="container-$(date +%Y%m%d_%H%M%S)"
        fi
        print_info "Auto-generated name: $CONTAINER_NAME_FROM_FLAG"
    fi
    
    return 0
}

# Build docker build command preview
# Constructs the docker build command based on selected options
#
# Input: None (uses global configuration variables)
# Output: Docker build command string
# Example: build_docker_build_preview
build_docker_build_preview() {
    local docker_build_cmd="docker build"
    
    # Add Dockerfile path if specified
    if [[ -n "$DOCKERFILE_PATH" ]]; then
        docker_build_cmd="$docker_build_cmd -f $DOCKERFILE_PATH"
    fi
    
    # Add image name
    if [[ -n "$BUILD_IMAGE_NAME" ]]; then
        docker_build_cmd="$docker_build_cmd -t $BUILD_IMAGE_NAME"
    else
        # Generate default image name
        local dir_name=$(basename "$BUILD_CONTEXT")
        if [[ "$dir_name" == "." ]]; then
            dir_name="app"
        fi
        docker_build_cmd="$docker_build_cmd -t ${dir_name}-image:latest"
    fi
    
    # Add build context
    docker_build_cmd="$docker_build_cmd $BUILD_CONTEXT"
    
    echo "$docker_build_cmd"
}

# Build docker run command preview
# Constructs the docker run command based on all selected options
#
# Input: None (uses global configuration variables)
# Output: Docker run command string
# Example: build_docker_run_preview
build_docker_run_preview() {
    local docker_run_cmd="docker run"
    
    # Add container name
    docker_run_cmd="$docker_run_cmd --name $CONTAINER_NAME_FROM_FLAG"
    
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
        # Split multiple env vars and add each one
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
    if [[ -n "$BUILD_IMAGE_NAME" ]]; then
        docker_run_cmd="$docker_run_cmd $BUILD_IMAGE_NAME"
    else
        docker_run_cmd="$docker_run_cmd $IMAGE_NAME"
    fi
    
    echo "$docker_run_cmd"
}

# Validate volume path for Docker on macOS
# Checks if the volume path is accessible to Docker
#
# Input: $1 - volume path (e.g., "/Users/username/path")
# Output: None
# Return code: 0 if valid, 1 if invalid
# Example: validate_volume_path "/Users/username/myapp"
validate_volume_path() {
    local volume_path="$1"
    
    # Check if path exists
    if [[ ! -e "$volume_path" ]]; then
        print_error "Volume path does not exist: $volume_path"
        return 1
    fi
    
    # On macOS, check if path is in Docker's shared directories
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Common Docker shared paths on macOS
        local shared_paths=(
            "/Users"
            "/tmp"
            "/var/folders"
            "/private"
        )
        
        local is_shared=false
        for shared_path in "${shared_paths[@]}"; do
            if [[ "$volume_path" == "$shared_path"* ]]; then
                is_shared=true
                break
            fi
        done
        
        if [[ "$is_shared" == "false" ]]; then
            print_warning "Volume path may not be shared with Docker on macOS: $volume_path"
            print_info "To fix this:"
            print_info "1. Open Docker Desktop"
            print_info "2. Go to Settings -> Resources -> File Sharing"
            print_info "3. Add the directory containing: $(dirname "$volume_path")"
            print_info "4. Restart Docker Desktop"
            return 1
        fi
    fi
    
    return 0
}

# Generate container name from image name
# Creates a container name based on the image name
#
# Input: $1 - image name (e.g., "nginx:latest")
# Output: Container name (e.g., "nginx-container")
# Example: generate_container_name_from_image "nginx:latest"
generate_container_name_from_image() {
    local image_name="$1"
    
    # Extract repository name (remove tag)
    local repo_name=$(echo "$image_name" | cut -d':' -f1)
    
    # Remove any registry prefix
    repo_name=$(echo "$repo_name" | sed 's/.*\///')
    
    # Add timestamp to make it unique
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    echo "${repo_name}-container-${timestamp}"
}

# Display build-only confirmation with preview
# Shows configuration summary and docker build command preview
#
# Input: None (uses global configuration variables)
# Output: Confirmation prompt
# Return code: 0 if confirmed, 1 if cancelled
# Example: show_build_confirmation
show_build_confirmation() {
    clear
    print_header "Build Only - No Container Creation"
    echo
    print_info "Selected Configuration:"
    echo
    
    # Show source (Dockerfile only for build)
    if [[ -n "$DOCKERFILE_PATH" ]]; then
        echo "🔨 Source: Dockerfile"
        echo "   Dockerfile: $DOCKERFILE_PATH"
        echo "   Build context: $BUILD_CONTEXT"
        echo "   Image name: $BUILD_IMAGE_NAME"
    else
        echo "❌ No Dockerfile selected for building"
        return 1
    fi
    
    echo
    echo "🚫 Mode: Build only (no container creation)"
    
    echo
    print_info "Docker build command that will be executed:"
    echo
    local preview_cmd=$(build_docker_build_preview)
    print_cyan "$preview_cmd"
    echo
    print_info "Proceed with build only? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Show image build confirmation (for existing images)
# Displays confirmation screen for image-based build-only operations
#
# Input: None (uses global variables)
# Output: None
# Return code: 0 if confirmed, 1 if cancelled
# Example: show_image_build_confirmation
show_image_build_confirmation() {
    clear
    print_header "Build Only - No Container Creation"
    echo
    print_info "Selected Configuration:"
    echo
    
    # Show source (existing image)
    if [[ -n "$IMAGE_NAME" ]]; then
        echo "📦 Source: Existing Docker Image"
        echo "   Image: $IMAGE_NAME"
    else
        echo "❌ No image selected for building"
        return 1
    fi
    
    echo
    echo "🚫 Mode: Build only (no container creation)"
    echo
    print_info "Docker run command that would be executed:"
    echo
    # Set container name if not provided for preview
    if [[ -z "$CONTAINER_NAME_FROM_FLAG" ]]; then
        CONTAINER_NAME_FROM_FLAG=$(generate_container_name_from_image "$IMAGE_NAME")
    fi
    local preview_cmd=$(build_docker_run_preview)
    print_cyan "$preview_cmd"
    echo
    print_info "Note: This will show the docker run command without creating a container"
    echo
    print_info "Proceed with build preview only? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Display final confirmation with preview
# Shows configuration summary and docker command preview
#
# Input: None (uses global configuration variables)
# Output: Confirmation prompt
# Return code: 0 if confirmed, 1 if cancelled
# Example: show_generation_confirmation
show_generation_confirmation() {
    clear
    print_header "Generation Summary"
    echo
    print_info "Selected Configuration:"
    echo
    
    # Show source (image, YAML, or Dockerfile)
    if [[ -n "$IMAGE_NAME" ]]; then
        echo "📦 Source: Docker Image"
        echo "   Image: $IMAGE_NAME"
    elif [[ -n "$DOCKERFILE_PATH" ]]; then
        echo "🔨 Source: Dockerfile"
        echo "   Dockerfile: $DOCKERFILE_PATH"
        echo "   Build context: $BUILD_CONTEXT"
        echo "   Image name: $BUILD_IMAGE_NAME"
    elif [[ ${#YAML_FILES[@]} -gt 0 ]]; then
        echo "📄 Source: YAML File"
        echo "   File: ${YAML_FILES[0]}"
    fi
    
    echo
    echo "🏷️  Container: $CONTAINER_NAME_FROM_FLAG"
    
    # Show all configured options
    local has_config=false
    
    if [[ -n "$PORT_MAPPING" ]]; then
        echo "🔌 Port Mapping: $PORT_MAPPING"
        has_config=true
    fi
    
    if [[ -n "$VOLUME_MAPPING" ]]; then
        echo "💾 Volume Mapping: $VOLUME_MAPPING"
        has_config=true
    fi
    
    if [[ -n "$ENV_VARS" ]]; then
        echo "🔧 Environment Variables: $ENV_VARS"
        has_config=true
    fi
    
    if [[ -n "$NETWORK_NAME" ]]; then
        echo "🌐 Network: $NETWORK_NAME"
        has_config=true
    fi
    
    if [[ -n "$RESOURCE_LIMITS" ]]; then
        echo "⚡ Resource Limits: $RESOURCE_LIMITS"
        has_config=true
    fi
    
    if [[ "$has_config" == "false" ]]; then
        echo "📝 No additional configuration options set"
    fi
    
    if [[ "$NO_START" == "true" ]]; then
        echo "🚫 Mode: Create only (not started)"
    else
        echo "▶️  Mode: Create and start"
    fi
    
    echo
    print_info "Docker command that will be executed:"
    echo
    local preview_cmd=$(build_docker_run_preview)
    print_cyan "$preview_cmd"
    echo
    print_info "Proceed with generation? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

 