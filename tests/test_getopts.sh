#!/usr/bin/env bash

# Test: Getopts Argument Parsing
# Description: Tests the new getopts-based argument parsing for Docker Ops Manager

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test variables
TEST_NAME="test_getopts"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_basic_short_options() {
    echo "Testing basic short options..."
    
    # Test help
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -h 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager"; then
        echo "✓ Help short option (-h) works"
    else
        echo "✗ Help short option (-h) failed"
        return 1
    fi
    
    # Test version
    result=$("$PROJECT_ROOT/docker_mgr.sh" -v 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager v"; then
        echo "✓ Version short option (-v) works"
    else
        echo "✗ Version short option (-v) failed"
        return 1
    fi
}

test_operation_short_options() {
    echo "Testing operation short options..."
    
    # Test list
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -a containers 2>&1)
    if echo "$result" | grep -q "Docker Containers"; then
        echo "✓ List short option (-a) works"
    else
        echo "✗ List short option (-a) failed"
        return 1
    fi
    
    # Test config
    result=$("$PROJECT_ROOT/docker_mgr.sh" -C 2>&1)
    if echo "$result" | grep -q "Configuration"; then
        echo "✓ Config short option (-C) works"
    else
        echo "✗ Config short option (-C) failed"
        return 1
    fi
    
    # Test state
    result=$("$PROJECT_ROOT/docker_mgr.sh" -e 2>&1)
    if echo "$result" | grep -q "State Summary"; then
        echo "✓ State short option (-e) works"
    else
        echo "✗ State short option (-e) failed"
        return 1
    fi
}

test_global_short_options() {
    echo "Testing global short options..."
    
    # Test force option
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -c -f nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Force short option (-f) works"
    else
        echo "✗ Force short option (-f) failed"
        return 1
    fi
    
    # Test timeout option
    result=$("$PROJECT_ROOT/docker_mgr.sh" -g -o 10 examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "timeout: 10"; then
        echo "✓ Timeout short option (-o) works"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Timeout short option (-o) failed"
        return 1
    fi
    
    # Test yaml option
    result=$("$PROJECT_ROOT/docker_mgr.sh" -g -y examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ YAML short option (-y) works"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ YAML short option (-y) failed"
        return 1
    fi
}

test_combined_short_options() {
    echo "Testing combined short options..."
    
    # Test combined cleanup with force
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -cf nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Combined short options (-cf) work"
    else
        echo "✗ Combined short options (-cf) failed"
        return 1
    fi
    
    # Test generate with multiple options
    result=$("$PROJECT_ROOT/docker_mgr.sh" -g -y examples/api-service.yml -o 15 -f 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ Multiple combined short options work"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Multiple combined short options failed"
        return 1
    fi
}

test_long_options() {
    echo "Testing long options..."
    
    # Test long help
    local result=$("$PROJECT_ROOT/docker_mgr.sh" --help 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager"; then
        echo "✓ Long help option (--help) works"
    else
        echo "✗ Long help option (--help) failed"
        return 1
    fi
    
    # Test long version
    result=$("$PROJECT_ROOT/docker_mgr.sh" --version 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager v"; then
        echo "✓ Long version option (--version) works"
    else
        echo "✗ Long version option (--version) failed"
        return 1
    fi
    
    # Test long config
    result=$("$PROJECT_ROOT/docker_mgr.sh" --config 2>&1)
    if echo "$result" | grep -q "Configuration"; then
        echo "✓ Long config option (--config) works"
    else
        echo "✗ Long config option (--config) failed"
        return 1
    fi
}

test_mixed_options() {
    echo "Testing mixed short and long options..."
    
    # Test mixed options
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -g --yaml examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ Mixed short and long options work"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Mixed short and long options failed"
        return 1
    fi
    
    # Test mixed with force
    result=$("$PROJECT_ROOT/docker_mgr.sh" --cleanup -f nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Mixed options with force work"
    else
        echo "✗ Mixed options with force failed"
        return 1
    fi
}

test_error_handling() {
    echo "Testing error handling..."
    
    # Test invalid short option
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -z 2>&1)
    if echo "$result" | grep -q "Invalid option"; then
        echo "✓ Invalid short option error handling works"
    else
        echo "✗ Invalid short option error handling failed"
        return 1
    fi
    
    # Test missing argument
    result=$("$PROJECT_ROOT/docker_mgr.sh" -y 2>&1)
    if echo "$result" | grep -q "Invalid option"; then
        echo "✓ Missing argument error handling works"
    else
        echo "✗ Missing argument error handling failed"
        return 1
    fi
    
    # Test invalid long option
    result=$("$PROJECT_ROOT/docker_mgr.sh" --invalid 2>&1)
    if echo "$result" | grep -q "Unknown long option"; then
        echo "✓ Invalid long option error handling works"
    else
        echo "✗ Invalid long option error handling failed"
        return 1
    fi
}

test_positional_arguments() {
    echo "Testing positional arguments..."
    
    # Test positional operation
    local result=$("$PROJECT_ROOT/docker_mgr.sh" list containers 2>&1)
    if echo "$result" | grep -q "Docker Containers"; then
        echo "✓ Positional operation works"
    else
        echo "✗ Positional operation failed"
        return 1
    fi
    
    # Test positional with short options
    result=$("$PROJECT_ROOT/docker_mgr.sh" -f cleanup nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Positional with short options works"
    else
        echo "✗ Positional with short options failed"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting Getopts Argument Parsing Tests"
    echo "======================================="
    
    # Test basic functionality
    test_basic_short_options
    echo
    
    test_operation_short_options
    echo
    
    test_global_short_options
    echo
    
    test_combined_short_options
    echo
    
    test_long_options
    echo
    
    test_mixed_options
    echo
    
    test_error_handling
    echo
    
    test_positional_arguments
    echo
    
    echo "All getopts argument parsing tests completed successfully!"
}

# Run the tests
main "$@" 