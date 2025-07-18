#!/usr/bin/env bash

# Test: Short Options Support
# Description: Tests all short command line options for Docker Ops Manager

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test variables
TEST_NAME="test_short_options"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_help_short_option() {
    echo "Testing help short option (-h)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -h 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager"; then
        echo "✓ Help short option works"
    else
        echo "✗ Help short option failed"
        return 1
    fi
}

test_version_short_option() {
    echo "Testing version short option (-v)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -v 2>&1)
    if echo "$result" | grep -q "Docker Ops Manager v"; then
        echo "✓ Version short option works"
    else
        echo "✗ Version short option failed"
        return 1
    fi
}

test_list_short_option() {
    echo "Testing list short option (-a)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -a containers 2>&1)
    if echo "$result" | grep -q "Docker Containers"; then
        echo "✓ List short option works"
    else
        echo "✗ List short option failed"
        return 1
    fi
}

test_config_short_option() {
    echo "Testing config short option (-C)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -C 2>&1)
    if echo "$result" | grep -q "Configuration"; then
        echo "✓ Config short option works"
    else
        echo "✗ Config short option failed"
        return 1
    fi
}

test_state_short_option() {
    echo "Testing state short option (-e)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -e 2>&1)
    if echo "$result" | grep -q "State Summary"; then
        echo "✓ State short option works"
    else
        echo "✗ State short option failed"
        return 1
    fi
}

test_env_short_option() {
    echo "Testing env short option (--env)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" --env 2>&1)
    if echo "$result" | grep -q "Environment Variables"; then
        echo "✓ Env short option works"
    else
        echo "✗ Env short option failed"
        return 1
    fi
}

test_generate_short_option() {
    echo "Testing generate short option (-g)..."
    # Create a simple test YAML
    local test_yaml="/tmp/test_short_options.yml"
    cat > "$test_yaml" << 'EOF'
version: '3.8'
services:
  test-short:
    image: nginx:alpine
    container_name: test-short-options
    ports:
      - "8083:80"
EOF

    local result=$("$PROJECT_ROOT/docker_mgr.sh" -g "$test_yaml" 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ Generate short option works"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f test-short-options >/dev/null 2>&1 || true
    else
        echo "✗ Generate short option failed"
        rm -f "$test_yaml"
        return 1
    fi
    
    rm -f "$test_yaml"
}

test_force_short_option() {
    echo "Testing force short option (-f)..."
    # This test verifies that -f is recognized as force option
    # We'll test it with a non-existent container to see if force flag is set
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -c -f nonexistent-container 2>&1)
    if echo "$result" | grep -q "Cleaning up container"; then
        echo "✓ Force short option works"
    else
        echo "✗ Force short option failed"
        return 1
    fi
}

test_timeout_short_option() {
    echo "Testing timeout short option (-o)..."
    # Test with a short timeout to verify it's recognized
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -g -o 10 examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "timeout: 10"; then
        echo "✓ Timeout short option works"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Timeout short option failed"
        echo "Debug output: $result"
        return 1
    fi
}

test_yaml_short_option() {
    echo "Testing yaml short option (-y)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -g -y examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ YAML short option works"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ YAML short option failed"
        return 1
    fi
}

test_invalid_short_option() {
    echo "Testing invalid short option (-z)..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -z 2>&1)
    if echo "$result" | grep -q "Unknown short option"; then
        echo "✓ Invalid short option error handling works"
    else
        echo "✗ Invalid short option error handling failed"
        return 1
    fi
}

test_mixed_options() {
    echo "Testing mixed short and long options..."
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -g --yaml examples/api-service.yml 2>&1)
    if echo "$result" | grep -q "generated and started successfully"; then
        echo "✓ Mixed options work"
        # Clean up
        "$PROJECT_ROOT/docker_mgr.sh" -c -f api-service >/dev/null 2>&1 || true
    else
        echo "✗ Mixed options failed"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting Short Options Tests"
    echo "============================"
    
    # Test basic short options
    test_help_short_option
    echo
    
    test_version_short_option
    echo
    
    test_list_short_option
    echo
    
    test_config_short_option
    echo
    
    test_state_short_option
    echo
    
    test_env_short_option
    echo
    
    # Test operation short options
    test_generate_short_option
    echo
    
    # Test global option short options
    test_force_short_option
    echo
    
    test_timeout_short_option
    echo
    
    test_yaml_short_option
    echo
    
    # Test error handling
    test_invalid_short_option
    echo
    
    # Test mixed options
    test_mixed_options
    echo
    
    echo "All short options tests completed successfully!"
}

# Run the tests
main "$@" 