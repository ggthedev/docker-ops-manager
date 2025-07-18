#!/usr/bin/env bash

# Test: Animation Functions
# Description: Tests the new animation functions for waiting operations

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the library files
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/logging.sh"

# Test variables
TEST_NAME="test_animation"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_dots_animation() {
    echo "Testing dots animation..."
    echo "This should show a dots animation for 3 seconds:"
    show_waiting_animation 3 "Testing dots animation" "dots"
    echo "Dots animation test completed"
}

test_waiting_dots() {
    echo "Testing simple dots animation..."
    echo "This should show only animating dots for 3 seconds:"
    show_waiting_animation 3 "" "dots"
    echo "Simple dots animation test completed"
}

# test_spinner_animation() {
#     echo "Testing spinner animation..."
#     echo "This should show a spinner animation for 3 seconds:"
#     show_waiting_animation 3 "Testing spinner animation" "spinner"
#     echo "Spinner animation test completed"
# }

test_condition_animation() {
    echo "Testing condition-based animation..."
    echo "This should show animation until a file is created (5 second timeout):"
    
    # Create a temporary file after 2 seconds
    (sleep 2 && touch /tmp/test_animation_file) &
    
    if show_waiting_animation_with_condition "test -f /tmp/test_animation_file" 5 "Waiting for test file" "dots"; then
        echo "Condition met - file was created"
    else
        echo "Timeout - file was not created"
    fi
    
    # Clean up
    rm -f /tmp/test_animation_file
}

test_progress_bar() {
    echo "Testing progress bar..."
    echo "This should show a progress bar:"
    
    for i in {1..10}; do
        show_progress "$i" 10 30 "Test Progress"
        sleep 0.2
    done
    echo "Progress bar test completed"
}

# Main test execution
main() {
    echo "Starting animation function tests..."
    echo "=================================="
    
    # Test dots animation
    test_dots_animation
    echo
    
    # Test static waiting dots
    test_waiting_dots
    echo
    
    # Test spinner animation (commented out)
    # test_spinner_animation
    # echo
    
    # Test condition-based animation
    test_condition_animation
    echo
    
    # Test progress bar
    test_progress_bar
    echo
    
    echo "All animation tests completed successfully!"
}

# Run the tests
main "$@" 