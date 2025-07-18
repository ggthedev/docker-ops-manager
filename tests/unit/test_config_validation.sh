#!/usr/bin/env bash

# Test: Configuration validation unit tests
# Description: Tests the configuration loading and validation functionality

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_config_validation"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
MAIN_SCRIPT="$PROJECT_ROOT/docker_ops_manager.sh"
CONFIG_LIB="$PROJECT_ROOT/lib/config.sh"

# Test setup
setup_test() {
    echo "Setting up configuration validation test..."
    
    # Create test configuration directory
    mkdir -p "$TEST_TEMP_DIR/config"
    
    # Create test config file
    cat > "$TEST_TEMP_DIR/config/test_config.conf" << 'EOF'
# Test configuration file
LOG_LEVEL=INFO
DEFAULT_TIMEOUT=60
STATE_FILE_PATH=~/.config/docker-ops-manager/state.json
LOG_FILE_PATH=~/.config/docker-ops-manager/logs/docker-ops.log
DEFAULT_YAML_FILE=app.yml
DOCKER_SOCKET=/var/run/docker.sock
MAX_CONTAINERS=50
CLEANUP_ON_EXIT=true
EOF

    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up configuration validation test..."
    rm -rf "$TEST_TEMP_DIR/config"
}

# Test 1: Valid configuration loading
test_valid_config_loading() {
    echo "Testing valid configuration loading..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set test config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/test_config.conf"
    
    # Load configuration
    load_config
    
    # Assertions
    assert_equals "INFO" "$LOG_LEVEL" "LOG_LEVEL should be INFO"
    assert_equals "60" "$DEFAULT_TIMEOUT" "DEFAULT_TIMEOUT should be 60"
    assert_equals "~/.config/docker-ops-manager/state.json" "$STATE_FILE_PATH" "STATE_FILE_PATH should be correct"
    assert_equals "~/.config/docker-ops-manager/logs/docker-ops.log" "$LOG_FILE_PATH" "LOG_FILE_PATH should be correct"
    assert_equals "app.yml" "$DEFAULT_YAML_FILE" "DEFAULT_YAML_FILE should be app.yml"
    assert_equals "/var/run/docker.sock" "$DOCKER_SOCKET" "DOCKER_SOCKET should be correct"
    assert_equals "50" "$MAX_CONTAINERS" "MAX_CONTAINERS should be 50"
    assert_equals "true" "$CLEANUP_ON_EXIT" "CLEANUP_ON_EXIT should be true"
    
    echo "✓ Valid configuration loading test passed"
}

# Test 2: Missing configuration file
test_missing_config_file() {
    echo "Testing missing configuration file handling..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set non-existent config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/nonexistent.conf"
    
    # Load configuration (should use defaults)
    load_config
    
    # Assertions - should use default values
    assert_not_equals "" "$LOG_LEVEL" "LOG_LEVEL should have default value"
    assert_not_equals "" "$DEFAULT_TIMEOUT" "DEFAULT_TIMEOUT should have default value"
    assert_not_equals "" "$STATE_FILE_PATH" "STATE_FILE_PATH should have default value"
    
    echo "✓ Missing configuration file test passed"
}

# Test 3: Invalid configuration values
test_invalid_config_values() {
    echo "Testing invalid configuration values handling..."
    
    # Create config file with invalid values
    cat > "$TEST_TEMP_DIR/config/invalid_config.conf" << 'EOF'
# Invalid configuration file
LOG_LEVEL=INVALID_LEVEL
DEFAULT_TIMEOUT=invalid_timeout
MAX_CONTAINERS=invalid_number
CLEANUP_ON_EXIT=invalid_boolean
EOF

    # Source the config library
    source "$CONFIG_LIB"
    
    # Set invalid config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/invalid_config.conf"
    
    # Load configuration (should use defaults for invalid values)
    load_config
    
    # Assertions - should use default values for invalid entries
    assert_not_equals "INVALID_LEVEL" "$LOG_LEVEL" "LOG_LEVEL should not be INVALID_LEVEL"
    assert_not_equals "invalid_timeout" "$DEFAULT_TIMEOUT" "DEFAULT_TIMEOUT should not be invalid_timeout"
    assert_not_equals "invalid_number" "$MAX_CONTAINERS" "MAX_CONTAINERS should not be invalid_number"
    assert_not_equals "invalid_boolean" "$CLEANUP_ON_EXIT" "CLEANUP_ON_EXIT should not be invalid_boolean"
    
    echo "✓ Invalid configuration values test passed"
}

# Test 4: Configuration validation
test_config_validation() {
    echo "Testing configuration validation..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set test config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/test_config.conf"
    
    # Load configuration
    load_config
    
    # Run validation
    local validation_errors=$(validate_config)
    
    # Assertions
    assert_equals "" "$validation_errors" "Configuration validation should pass with no errors"
    
    echo "✓ Configuration validation test passed"
}

# Test 5: Configuration file creation
test_config_file_creation() {
    echo "Testing configuration file creation..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set new config file path
    local new_config_file="$TEST_TEMP_DIR/config/new_config.conf"
    export CONFIG_FILE="$new_config_file"
    
    # Initialize config file
    init_config_file
    
    # Assertions
    assert_file_exists "$new_config_file" "New configuration file should be created"
    
    # Check if file contains expected content
    local file_content=$(cat "$new_config_file")
    assert_contains "$file_content" "LOG_LEVEL" "Config file should contain LOG_LEVEL"
    assert_contains "$file_content" "DEFAULT_TIMEOUT" "Config file should contain DEFAULT_TIMEOUT"
    assert_contains "$file_content" "STATE_FILE_PATH" "Config file should contain STATE_FILE_PATH"
    
    echo "✓ Configuration file creation test passed"
}

# Test 6: Environment variable override
test_env_var_override() {
    echo "Testing environment variable override..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set test config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/test_config.conf"
    
    # Set environment variable override
    export LOG_LEVEL="DEBUG"
    export DEFAULT_TIMEOUT="120"
    
    # Load configuration
    load_config
    
    # Assertions - environment variables should override config file
    assert_equals "DEBUG" "$LOG_LEVEL" "LOG_LEVEL should be overridden by environment variable"
    assert_equals "120" "$DEFAULT_TIMEOUT" "DEFAULT_TIMEOUT should be overridden by environment variable"
    
    echo "✓ Environment variable override test passed"
}

# Test 7: Configuration reload
test_config_reload() {
    echo "Testing configuration reload..."
    
    # Source the config library
    source "$CONFIG_LIB"
    
    # Set test config file
    export CONFIG_FILE="$TEST_TEMP_DIR/config/test_config.conf"
    
    # Load configuration first time
    load_config
    local first_log_level="$LOG_LEVEL"
    
    # Modify config file
    sed -i 's/LOG_LEVEL=INFO/LOG_LEVEL=ERROR/' "$TEST_TEMP_DIR/config/test_config.conf"
    
    # Reload configuration
    load_config
    
    # Assertions
    assert_not_equals "$first_log_level" "$LOG_LEVEL" "LOG_LEVEL should change after reload"
    assert_equals "ERROR" "$LOG_LEVEL" "LOG_LEVEL should be ERROR after reload"
    
    echo "✓ Configuration reload test passed"
}

# Main test execution
main() {
    echo "Starting configuration validation unit tests..."
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_valid_config_loading
    test_missing_config_file
    test_invalid_config_values
    test_config_validation
    test_config_file_creation
    test_env_var_override
    test_config_reload
    
    # Cleanup
    cleanup_test
    
    echo "All configuration validation unit tests passed!"
}

# Run main function
main "$@" 