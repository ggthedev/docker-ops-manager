#!/usr/bin/env bash

# Test script for --no-start flag functionality
# Tests that containers are created but not started when --no-start flag is used

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/../docker-manager.sh"
TEST_TEMP_DIR="$SCRIPT_DIR/temp/no_start_test"
TEST_YAML_FILE="$TEST_TEMP_DIR/test-no-start.yml"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

cleanup_test_environment() {
    print_info "Cleaning up test environment..."
    
    # Stop and remove test containers
    docker stop test-no-start-container 2>/dev/null || true
    docker rm test-no-start-container 2>/dev/null || true
    
    # Remove test directory
    rm -rf "$TEST_TEMP_DIR"
}

setup_test_environment() {
    print_info "Setting up test environment..."
    
    # Create test directory
    mkdir -p "$TEST_TEMP_DIR"
    
    # Create test YAML file
    cat > "$TEST_YAML_FILE" << 'EOF'
version: '3.8'
services:
  test-no-start-container:
    image: nginx:alpine
    container_name: test-no-start-container
    ports:
      - "8080:80"
    environment:
      - NGINX_HOST=localhost
    volumes:
      - ./html:/usr/share/nginx/html
EOF
}

test_generate_with_no_start() {
    print_test_header "Testing generate with --no-start flag"
    
    # Test generate with --no-start
    local result=$("$MAIN_SCRIPT" generate "$TEST_YAML_FILE" --no-start 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Generate command with --no-start succeeded"
        
        # Check if container exists but is not running
        if docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "test-no-start-container.*Created"; then
            print_success "Container created but not started (status: Created)"
        else
            print_error "Container should be created but not started"
            docker ps -a | grep test-no-start-container || print_error "Container not found"
        fi
        
        # Check success message
        if echo "$result" | grep -q "created successfully (not started)"; then
            print_success "Correct success message displayed"
        else
            print_error "Expected success message not found"
            echo "Actual output: $result"
        fi
    else
        print_error "Generate command with --no-start failed"
        echo "Output: $result"
    fi
}

test_generate_without_no_start() {
    print_test_header "Testing generate without --no-start flag"
    
    # Clean up any existing container
    docker stop test-no-start-container 2>/dev/null || true
    docker rm test-no-start-container 2>/dev/null || true
    
    # Test generate without --no-start
    local result=$("$MAIN_SCRIPT" generate "$TEST_YAML_FILE" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Generate command without --no-start succeeded"
        
        # Check if container is running
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "test-no-start-container.*Up"; then
            print_success "Container created and started (status: Up)"
        else
            print_error "Container should be created and started"
            docker ps -a | grep test-no-start-container || print_error "Container not found"
        fi
        
        # Check success message
        if echo "$result" | grep -q "generated and started successfully"; then
            print_success "Correct success message displayed"
        else
            print_error "Expected success message not found"
            echo "Actual output: $result"
        fi
    else
        print_error "Generate command without --no-start failed"
        echo "Output: $result"
    fi
}

test_install_with_no_start() {
    print_test_header "Testing install with --no-start flag"
    
    # Clean up any existing container
    docker stop test-no-start-container 2>/dev/null || true
    docker rm test-no-start-container 2>/dev/null || true
    
    # First generate the container normally
    "$MAIN_SCRIPT" generate "$TEST_YAML_FILE" >/dev/null 2>&1
    
    # Stop and remove the container
    docker stop test-no-start-container >/dev/null 2>&1 || true
    docker rm test-no-start-container >/dev/null 2>&1 || true
    
    # Test install with --no-start
    local result=$("$MAIN_SCRIPT" install test-no-start-container --no-start 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Install command with --no-start succeeded"
        
        # Check if container exists but is not running
        if docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "test-no-start-container.*Created"; then
            print_success "Container installed but not started (status: Created)"
        else
            print_error "Container should be installed but not started"
            docker ps -a | grep test-no-start-container || print_error "Container not found"
        fi
        
        # Check success message
        if echo "$result" | grep -q "created successfully (not started)"; then
            print_success "Correct success message displayed"
        else
            print_error "Expected success message not found"
            echo "Actual output: $result"
        fi
    else
        print_error "Install command with --no-start failed"
        echo "Output: $result"
    fi
}

test_help_includes_no_start() {
    print_test_header "Testing help includes --no-start flag"
    
    local result=$("$MAIN_SCRIPT" help 2>&1)
    
    if echo "$result" | grep -q "--no-start"; then
        print_success "Help includes --no-start flag"
    else
        print_error "Help does not include --no-start flag"
        echo "Help output: $result"
    fi
}

# Main test execution
main() {
    echo "Starting --no-start flag tests..."
    echo "=================================="
    
    # Set up test environment
    setup_test_environment
    
    # Run tests
    test_help_includes_no_start
    test_generate_with_no_start
    test_generate_without_no_start
    test_install_with_no_start
    
    # Clean up
    cleanup_test_environment
    
    # Print summary
    echo ""
    echo "=================================="
    echo "Test Summary:"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 