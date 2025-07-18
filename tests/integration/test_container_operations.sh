#!/usr/bin/env bash

# Test: Container operations integration tests
# Description: Tests the integration between container operations and other components

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_container_operations"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
MAIN_SCRIPT="$PROJECT_ROOT/docker_ops_manager.sh"
CONTAINER_OPS_LIB="$PROJECT_ROOT/lib/container_ops.sh"
CONFIG_LIB="$PROJECT_ROOT/lib/config.sh"
STATE_LIB="$PROJECT_ROOT/lib/state.sh"

# Test container names
TEST_CONTAINER_PREFIX="test-integration"
TEST_CONTAINER_1="${TEST_CONTAINER_PREFIX}-app1"
TEST_CONTAINER_2="${TEST_CONTAINER_PREFIX}-app2"

# Test setup
setup_test() {
    echo "Setting up container operations integration test..."
    
    # Create test YAML file
    mkdir -p "$TEST_TEMP_DIR/yaml"
    cat > "$TEST_TEMP_DIR/yaml/test-integration.yml" << 'EOF'
name: test-integration-app
version: "1.0"
description: "Test application for integration testing"

containers:
  app1:
    image: alpine:latest
    command: ["sh", "-c", "echo 'App1 started' && sleep 3600"]
    environment:
      - TEST_VAR=app1_value
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "echo", "healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  app2:
    image: alpine:latest
    command: ["sh", "-c", "echo 'App2 started' && sleep 3600"]
    environment:
      - TEST_VAR=app2_value
    restart: unless-stopped
    depends_on:
      - app1
    healthcheck:
      test: ["CMD", "echo", "healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge

volumes:
  test_data:
    driver: local
EOF

    # Source required libraries
    source "$CONFIG_LIB"
    source "$STATE_LIB"
    source "$CONTAINER_OPS_LIB"
    
    # Initialize test environment
    export CONFIG_FILE="$TEST_TEMP_DIR/test-config.conf"
    init_config_file
    load_config
    init_state_file
    
    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up container operations integration test..."
    
    # Stop and remove test containers
    docker stop "$TEST_CONTAINER_1" 2>/dev/null || true
    docker rm "$TEST_CONTAINER_1" 2>/dev/null || true
    docker stop "$TEST_CONTAINER_2" 2>/dev/null || true
    docker rm "$TEST_CONTAINER_2" 2>/dev/null || true
    
    # Remove test volumes
    docker volume rm "test_data" 2>/dev/null || true
    
    # Clean up test files
    rm -rf "$TEST_TEMP_DIR/yaml"
    rm -f "$TEST_TEMP_DIR/test-config.conf"
    
    echo "Test cleanup complete"
}

# Test 1: Full application lifecycle
test_full_application_lifecycle() {
    echo "Testing full application lifecycle..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Step 1: Generate application
    echo "Step 1: Generating application..."
    local generate_result=$("$MAIN_SCRIPT" generate "$yaml_file" 2>&1)
    local generate_exit_code=$?
    
    assert_exit_code 0 "$generate_exit_code" "Application generation should succeed"
    assert_contains "$generate_result" "generated" "Generation should report success"
    
    # Step 2: Install application
    echo "Step 2: Installing application..."
    local install_result=$("$MAIN_SCRIPT" install "$yaml_file" 2>&1)
    local install_exit_code=$?
    
    assert_exit_code 0 "$install_exit_code" "Application installation should succeed"
    assert_contains "$install_result" "installed" "Installation should report success"
    
    # Step 3: Check application status
    echo "Step 3: Checking application status..."
    local status_result=$("$MAIN_SCRIPT" status "$yaml_file" 2>&1)
    local status_exit_code=$?
    
    assert_exit_code 0 "$status_exit_code" "Status check should succeed"
    assert_contains "$status_result" "running" "Containers should be running"
    
    # Step 4: Check application logs
    echo "Step 4: Checking application logs..."
    local logs_result=$("$MAIN_SCRIPT" logs "$yaml_file" 2>&1)
    local logs_exit_code=$?
    
    assert_exit_code 0 "$logs_exit_code" "Logs retrieval should succeed"
    assert_contains "$logs_result" "App1 started" "App1 logs should be present"
    assert_contains "$logs_result" "App2 started" "App2 logs should be present"
    
    # Step 5: Stop application
    echo "Step 5: Stopping application..."
    local stop_result=$("$MAIN_SCRIPT" stop "$yaml_file" 2>&1)
    local stop_exit_code=$?
    
    assert_exit_code 0 "$stop_exit_code" "Application stop should succeed"
    assert_contains "$stop_result" "stopped" "Stop should report success"
    
    # Step 6: Start application
    echo "Step 6: Starting application..."
    local start_result=$("$MAIN_SCRIPT" start "$yaml_file" 2>&1)
    local start_exit_code=$?
    
    assert_exit_code 0 "$start_exit_code" "Application start should succeed"
    assert_contains "$start_result" "started" "Start should report success"
    
    # Step 7: Restart application
    echo "Step 7: Restarting application..."
    local restart_result=$("$MAIN_SCRIPT" restart "$yaml_file" 2>&1)
    local restart_exit_code=$?
    
    assert_exit_code 0 "$restart_exit_code" "Application restart should succeed"
    assert_contains "$restart_result" "restarted" "Restart should report success"
    
    # Step 8: Cleanup application
    echo "Step 8: Cleaning up application..."
    local cleanup_result=$("$MAIN_SCRIPT" cleanup "$yaml_file" 2>&1)
    local cleanup_exit_code=$?
    
    assert_exit_code 0 "$cleanup_exit_code" "Application cleanup should succeed"
    assert_contains "$cleanup_result" "cleaned" "Cleanup should report success"
    
    echo "✓ Full application lifecycle test passed"
}

# Test 2: Container dependency management
test_container_dependency_management() {
    echo "Testing container dependency management..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Install application
    "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1
    
    # Wait for containers to be ready
    sleep 5
    
    # Check that app1 starts before app2
    local app1_start_time=$(docker inspect "$TEST_CONTAINER_1" --format='{{.State.StartedAt}}' 2>/dev/null)
    local app2_start_time=$(docker inspect "$TEST_CONTAINER_2" --format='{{.State.StartedAt}}' 2>/dev/null)
    
    if [[ -n "$app1_start_time" && -n "$app2_start_time" ]]; then
        # Convert to timestamps for comparison
        local app1_timestamp=$(date -d "$app1_start_time" +%s 2>/dev/null || echo "0")
        local app2_timestamp=$(date -d "$app2_start_time" +%s 2>/dev/null || echo "0")
        
        # App1 should start before or at the same time as App2
        assert_equals "true" "$(($app1_timestamp <= $app2_timestamp))" "App1 should start before or with App2"
    fi
    
    # Check that app2 depends on app1
    local app2_depends=$(docker inspect "$TEST_CONTAINER_2" --format='{{.HostConfig.Links}}' 2>/dev/null)
    assert_contains "$app2_depends" "$TEST_CONTAINER_1" "App2 should depend on App1"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Container dependency management test passed"
}

# Test 3: State management integration
test_state_management_integration() {
    echo "Testing state management integration..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Install application
    "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1
    
    # Check that state is updated
    local state_content=$(cat "$STATE_FILE_PATH" 2>/dev/null || echo "{}")
    assert_contains "$state_content" "$TEST_CONTAINER_1" "State should contain container 1"
    assert_contains "$state_content" "$TEST_CONTAINER_2" "State should contain container 2"
    assert_contains "$state_content" "running" "State should indicate running status"
    
    # Stop application
    "$MAIN_SCRIPT" stop "$yaml_file" > /dev/null 2>&1
    
    # Check that state is updated
    local updated_state_content=$(cat "$STATE_FILE_PATH" 2>/dev/null || echo "{}")
    assert_contains "$updated_state_content" "stopped" "State should indicate stopped status"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ State management integration test passed"
}

# Test 4: Configuration integration
test_configuration_integration() {
    echo "Testing configuration integration..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Test with custom timeout
    local custom_timeout_result=$("$MAIN_SCRIPT" --timeout 30 install "$yaml_file" 2>&1)
    local custom_timeout_exit_code=$?
    
    assert_exit_code 0 "$custom_timeout_exit_code" "Installation with custom timeout should succeed"
    
    # Test with force flag
    local force_result=$("$MAIN_SCRIPT" --force install "$yaml_file" 2>&1)
    local force_exit_code=$?
    
    assert_exit_code 0 "$force_exit_code" "Installation with force flag should succeed"
    
    # Test with custom log level
    local log_level_result=$("$MAIN_SCRIPT" --log-level DEBUG status "$yaml_file" 2>&1)
    local log_level_exit_code=$?
    
    assert_exit_code 0 "$log_level_exit_code" "Status check with custom log level should succeed"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Configuration integration test passed"
}

# Test 5: Error handling integration
test_error_handling_integration() {
    echo "Testing error handling integration..."
    
    # Test with non-existent YAML file
    local nonexistent_result=$("$MAIN_SCRIPT" install "nonexistent.yml" 2>&1)
    local nonexistent_exit_code=$?
    
    assert_not_equals 0 "$nonexistent_exit_code" "Non-existent YAML should fail"
    assert_contains "$nonexistent_result" "error" "Error message should be present"
    
    # Test with invalid YAML file
    local invalid_yaml="$TEST_TEMP_DIR/yaml/invalid.yml"
    echo "invalid: yaml: content:" > "$invalid_yaml"
    
    local invalid_result=$("$MAIN_SCRIPT" install "$invalid_yaml" 2>&1)
    local invalid_exit_code=$?
    
    assert_not_equals 0 "$invalid_exit_code" "Invalid YAML should fail"
    assert_contains "$invalid_result" "error" "Error message should be present"
    
    # Test with missing required fields
    local missing_fields_yaml="$TEST_TEMP_DIR/yaml/missing-fields.yml"
    cat > "$missing_fields_yaml" << 'EOF'
version: "1.0"
containers:
  test:
    image: alpine:latest
EOF

    local missing_fields_result=$("$MAIN_SCRIPT" install "$missing_fields_yaml" 2>&1)
    local missing_fields_exit_code=$?
    
    assert_not_equals 0 "$missing_fields_exit_code" "YAML with missing fields should fail"
    assert_contains "$missing_fields_result" "name" "Error should mention missing name"
    
    echo "✓ Error handling integration test passed"
}

# Test 6: Performance integration
test_performance_integration() {
    echo "Testing performance integration..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Measure installation time
    local start_time=$(date +%s)
    "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1
    local end_time=$(date +%s)
    local install_duration=$((end_time - start_time))
    
    # Installation should complete within reasonable time (30 seconds)
    assert_equals "true" "$(($install_duration <= 30))" "Installation should complete within 30 seconds"
    
    # Measure status check time
    start_time=$(date +%s)
    "$MAIN_SCRIPT" status "$yaml_file" > /dev/null 2>&1
    end_time=$(date +%s)
    local status_duration=$((end_time - start_time))
    
    # Status check should be fast (5 seconds)
    assert_equals "true" "$(($status_duration <= 5))" "Status check should complete within 5 seconds"
    
    # Measure cleanup time
    start_time=$(date +%s)
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    end_time=$(date +%s)
    local cleanup_duration=$((end_time - start_time))
    
    # Cleanup should complete within reasonable time (20 seconds)
    assert_equals "true" "$(($cleanup_duration <= 20))" "Cleanup should complete within 20 seconds"
    
    echo "✓ Performance integration test passed"
}

# Test 7: Logging integration
test_logging_integration() {
    echo "Testing logging integration..."
    
    local yaml_file="$TEST_TEMP_DIR/yaml/test-integration.yml"
    
    # Install with verbose logging
    local verbose_result=$("$MAIN_SCRIPT" --log-level DEBUG install "$yaml_file" 2>&1)
    
    # Check for debug messages
    assert_contains "$verbose_result" "DEBUG" "Debug messages should be present"
    assert_contains "$verbose_result" "installing" "Installation messages should be present"
    
    # Check application logs
    local app_logs=$("$MAIN_SCRIPT" logs "$yaml_file" 2>&1)
    assert_contains "$app_logs" "App1 started" "App1 logs should be present"
    assert_contains "$app_logs" "App2 started" "App2 logs should be present"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Logging integration test passed"
}

# Main test execution
main() {
    echo "Starting container operations integration tests..."
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_full_application_lifecycle
    test_container_dependency_management
    test_state_management_integration
    test_configuration_integration
    test_error_handling_integration
    test_performance_integration
    test_logging_integration
    
    # Cleanup
    cleanup_test
    
    echo "All container operations integration tests passed!"
}

# Run main function
main "$@" 