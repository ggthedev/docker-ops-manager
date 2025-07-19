#!/usr/bin/env bash

# Test: Args Parser Refactor
# Description: Tests the refactored argument parsing after moving to lib/args_parser.sh

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test variables
TEST_NAME="test_args_parser_refactor"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_args_parser_library_loaded() {
    echo "Testing args parser library is loaded..."
    
    # Check if the args_parser.sh file exists
    if [[ -f "$PROJECT_ROOT/lib/args_parser.sh" ]]; then
        echo "✓ Args parser library file exists"
    else
        echo "✗ Args parser library file missing"
        return 1
    fi
    
    # Check if the main script sources the args parser
    if grep -q "source.*args_parser.sh" "$PROJECT_ROOT/docker_mgr.sh"; then
        echo "✓ Main script sources args parser library"
    else
        echo "✗ Main script does not source args parser library"
        return 1
    fi
}

test_basic_functionality() {
    echo "Testing basic functionality after refactor..."
    
    # Test help
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -h 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager"; then
        echo "✓ Help functionality works after refactor"
    else
        echo "✗ Help functionality broken after refactor"
        return 1
    fi
    
    # Test version
    result=$("$PROJECT_ROOT/docker_mgr.sh" -v 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager v"; then
        echo "✓ Version functionality works after refactor"
    else
        echo "✗ Version functionality broken after refactor"
        return 1
    fi
}

test_operation_parsing() {
    echo "Testing operation parsing after refactor..."
    
    # Test list operation
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -a containers 2>&1)
    if echo "$result" | grep -q "Docker Containers"; then
        echo "✓ List operation parsing works after refactor"
    else
        echo "✗ List operation parsing broken after refactor"
        return 1
    fi
    
    # Test config operation
    result=$("$PROJECT_ROOT/docker_mgr.sh" -C 2>&1)
    if echo "$result" | grep -q "Configuration"; then
        echo "✓ Config operation parsing works after refactor"
    else
        echo "✗ Config operation parsing broken after refactor"
        return 1
    fi
    
    # Test state operation
    result=$("$PROJECT_ROOT/docker_mgr.sh" -e 2>&1)
    if echo "$result" | grep -q "State Summary"; then
        echo "✓ State operation parsing works after refactor"
    else
        echo "✗ State operation parsing broken after refactor"
        return 1
    fi
}

test_global_options() {
    echo "Testing global options after refactor..."
    
    # Test force option
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -c -f nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Force option parsing works after refactor"
    else
        echo "✗ Force option parsing broken after refactor"
        return 1
    fi
    
    # Test timeout option
    result=$("$PROJECT_ROOT/docker_mgr.sh" -g -o 10 examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "timeout: 10"; then
        echo "✓ Timeout option parsing works after refactor"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Timeout option parsing broken after refactor"
        return 1
    fi
}

test_combined_options() {
    echo "Testing combined options after refactor..."
    
    # Test combined short options
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -cf nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Combined short options work after refactor"
    else
        echo "✗ Combined short options broken after refactor"
        return 1
    fi
    
    # Test mixed options
    result=$("$PROJECT_ROOT/docker_mgr.sh" -g --yaml examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ Mixed options work after refactor"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Mixed options broken after refactor"
        return 1
    fi
}

test_error_handling() {
    echo "Testing error handling after refactor..."
    
    # Test invalid option
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -z 2>&1)
    if echo "$result" | grep -q "Invalid option"; then
        echo "✓ Error handling works after refactor"
    else
        echo "✗ Error handling broken after refactor"
        return 1
    fi
}

test_positional_arguments() {
    echo "Testing positional arguments after refactor..."
    
    # Test positional operation
    local result=$("$PROJECT_ROOT/docker_mgr.sh" list containers 2>&1)
    if echo "$result" | grep -q "Docker Containers"; then
        echo "✓ Positional arguments work after refactor"
    else
        echo "✗ Positional arguments broken after refactor"
        return 1
    fi
}

test_library_functions() {
    echo "Testing library functions are accessible..."
    
    # Test that the functions are available by sourcing the library directly
    source "$PROJECT_ROOT/lib/args_parser.sh"
    
    # Test validate_operation function exists
    if declare -f validate_operation >/dev/null; then
        echo "✓ validate_operation function is available"
    else
        echo "✗ validate_operation function is missing"
        return 1
    fi
    
    # Test get_target_containers function exists
    if declare -f get_target_containers >/dev/null; then
        echo "✓ get_target_containers function is available"
    else
        echo "✗ get_target_containers function is missing"
        return 1
    fi
    
    # Test get_target_container function exists
    if declare -f get_target_container >/dev/null; then
        echo "✓ get_target_container function is available"
    else
        echo "✗ get_target_container function is missing"
        return 1
    fi
    
    # Test print_help function exists
    if declare -f print_help >/dev/null; then
        echo "✓ print_help function is available"
    else
        echo "✗ print_help function is missing"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting Args Parser Refactor Tests"
    echo "==================================="
    
    # Test library structure
    test_args_parser_library_loaded
    echo
    
    # Test library functions
    test_library_functions
    echo
    
    # Test basic functionality
    test_basic_functionality
    echo
    
    # Test operation parsing
    test_operation_parsing
    echo
    
    # Test global options
    test_global_options
    echo
    
    # Test combined options
    test_combined_options
    echo
    
    # Test error handling
    test_error_handling
    echo
    
    # Test positional arguments
    test_positional_arguments
    echo
    
    echo "All args parser refactor tests completed successfully!"
}

# Run the tests
main "$@" 