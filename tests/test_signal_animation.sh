#!/usr/bin/env bash

# Test: Signal-Based Animation
# Description: Tests the new signal-based animation control system

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the library files
source "$PROJECT_ROOT/lib/utils.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/lib/logging.sh"

# Test variables
TEST_NAME="test_signal_animation"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_basic_signal_animation() {
    echo "Testing basic signal-based animation..."
    echo "This will show dots animation for 5 seconds, then stop via signal:"
    
    # Start animation
    start_signal_animation
    
    # Let it run for 5 seconds
    sleep 5
    
    # Stop animation
    stop_signal_animation
    
    echo "Basic signal animation test completed"
}

test_condition_based_signal_animation() {
    echo "Testing condition-based signal animation..."
    echo "This will show animation until a file is created (10 second timeout):"
    
    # Create a temporary file after 3 seconds
    (sleep 3 && touch /tmp/test_signal_file) &
    
    # Use the wait_with_signal_animation function
    if wait_with_signal_animation "test -f /tmp/test_signal_file" 10; then
        echo "Condition met - file was created"
    else
        echo "Timeout - file was not created"
    fi
    
    # Clean up
    rm -f /tmp/test_signal_file
}

test_animation_status() {
    echo "Testing animation status checking..."
    
    # Start animation
    start_signal_animation
    
    # Check if running
    if is_animation_running; then
        echo "✓ Animation is running"
    else
        echo "✗ Animation is not running"
    fi
    
    # Stop animation
    stop_signal_animation
    
    # Check if stopped
    if is_animation_running; then
        echo "✗ Animation is still running"
    else
        echo "✓ Animation stopped successfully"
    fi
}

test_multiple_animations() {
    echo "Testing multiple animation starts/stops..."
    
    # Start first animation
    start_signal_animation
    sleep 2
    
    # Start second animation (should stop the first)
    start_signal_animation
    sleep 2
    
    # Stop animation
    stop_signal_animation
    
    echo "Multiple animations test completed"
}

# Main test execution
main() {
    echo "Starting Signal-Based Animation Tests"
    echo "====================================="
    
    # Test basic functionality
    test_basic_signal_animation
    echo
    
    # Test condition-based animation
    test_condition_based_signal_animation
    echo
    
    # Test status checking
    test_animation_status
    echo
    
    # Test multiple animations
    test_multiple_animations
    echo
    
    echo "All signal-based animation tests completed successfully!"
}

# Run the tests
main "$@" 