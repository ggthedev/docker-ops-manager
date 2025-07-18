#!/usr/bin/env bash

# Docker Ops Manager - Test Configuration
# Configuration settings for the test suite

# Test environment settings
export TEST_ENV="development"
export TEST_TIMEOUT=300  # 5 minutes default timeout
export TEST_RETRY_COUNT=3
export TEST_PARALLEL_JOBS=4

# Docker test settings
export TEST_DOCKER_IMAGE="alpine:latest"
export TEST_DOCKER_CONTAINER_PREFIX="test-docker-ops"
export TEST_DOCKER_NETWORK="test-network"
export TEST_DOCKER_VOLUME_PREFIX="test-volume"

# Test data settings
export TEST_DATA_DIR="$SCRIPT_DIR/data"
export TEST_YAML_FILES_DIR="$SCRIPT_DIR/yaml_files"
export TEST_LOGS_DIR="$SCRIPT_DIR/logs"

# Performance test settings
export PERFORMANCE_TEST_DURATION=60  # seconds
export PERFORMANCE_TEST_CONTAINERS=10
export PERFORMANCE_TEST_ITERATIONS=5

# Security test settings
export SECURITY_TEST_TIMEOUT=120
export SECURITY_TEST_ITERATIONS=3

# Integration test settings
export INTEGRATION_TEST_TIMEOUT=600  # 10 minutes
export INTEGRATION_TEST_CLEANUP=true

# Functional test settings
export FUNCTIONAL_TEST_TIMEOUT=900   # 15 minutes
export FUNCTIONAL_TEST_VERBOSE=true

# Unit test settings
export UNIT_TEST_TIMEOUT=60
export UNIT_TEST_VERBOSE=false

# Test validation settings
export VALIDATE_YAML_SYNTAX=true
export VALIDATE_DOCKER_COMMANDS=true
export VALIDATE_PERMISSIONS=true

# Test cleanup settings
export CLEANUP_ON_SUCCESS=true
export CLEANUP_ON_FAILURE=true
export CLEANUP_TIMEOUT=300

# Test reporting settings
export GENERATE_HTML_REPORT=true
export GENERATE_JUNIT_XML=true
export GENERATE_COVERAGE_REPORT=true

# Test debugging settings
export DEBUG_MODE=false
export VERBOSE_OUTPUT=false
export LOG_LEVEL="INFO"

# Test isolation settings
export USE_TEST_NAMESPACE=true
export TEST_NAMESPACE="docker-ops-test"
export ISOLATE_TESTS=true

# Test data generation settings
export GENERATE_TEST_DATA=true
export TEST_DATA_SIZE="small"  # small, medium, large
export TEST_DATA_COMPLEXITY="simple"  # simple, moderate, complex

# Test execution settings
export EXECUTE_DANGEROUS_TESTS=false
export EXECUTE_PERFORMANCE_TESTS=true
export EXECUTE_SECURITY_TESTS=true
export EXECUTE_INTEGRATION_TESTS=true
export EXECUTE_FUNCTIONAL_TESTS=true
export EXECUTE_UNIT_TESTS=true

# Test validation functions
validate_test_environment() {
    local errors=()
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        errors+=("Docker is not installed or not in PATH")
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        errors+=("Docker daemon is not running")
    fi
    
    # Check if test directories exist
    if [[ ! -d "$TEST_DATA_DIR" ]]; then
        errors+=("Test data directory does not exist: $TEST_DATA_DIR")
    fi
    
    if [[ ! -d "$TEST_YAML_FILES_DIR" ]]; then
        errors+=("Test YAML files directory does not exist: $TEST_YAML_FILES_DIR")
    fi
    
    # Check if main script exists
    local main_script="$PROJECT_ROOT/docker_ops_manager.sh"
    if [[ ! -f "$main_script" ]]; then
        errors+=("Main script not found: $main_script")
    fi
    
    # Check if main script is executable
    if [[ ! -x "$main_script" ]]; then
        errors+=("Main script is not executable: $main_script")
    fi
    
    # Return errors if any
    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}"
        return 1
    fi
    
    return 0
}

# Test utility functions
setup_test_environment() {
    echo "Setting up test environment..."
    
    # Create test directories
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$TEST_YAML_FILES_DIR"
    mkdir -p "$TEST_LOGS_DIR"
    
    # Create test Docker network if it doesn't exist
    if ! docker network ls | grep -q "$TEST_DOCKER_NETWORK"; then
        docker network create "$TEST_DOCKER_NETWORK" 2>/dev/null || true
    fi
    
    # Generate test data if enabled
    if [[ "$GENERATE_TEST_DATA" == "true" ]]; then
        generate_test_data
    fi
    
    echo "Test environment setup complete"
}

cleanup_test_environment() {
    echo "Cleaning up test environment..."
    
    # Stop and remove test containers
    docker ps -a --filter "name=$TEST_DOCKER_CONTAINER_PREFIX" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove test volumes
    docker volume ls --filter "name=$TEST_DOCKER_VOLUME_PREFIX" --format "{{.Name}}" | xargs -r docker volume rm
    
    # Remove test network
    docker network rm "$TEST_DOCKER_NETWORK" 2>/dev/null || true
    
    # Clean up test files
    rm -rf "$TEST_TEMP_DIR"/*
    
    echo "Test environment cleanup complete"
}

generate_test_data() {
    echo "Generating test data..."
    
    # Create simple test YAML file
    cat > "$TEST_YAML_FILES_DIR/simple-app.yml" << 'EOF'
name: simple-test-app
version: "1.0"
description: "Simple test application for Docker Ops Manager"

containers:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    environment:
      - NGINX_HOST=localhost
    volumes:
      - ./html:/usr/share/nginx/html
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  default:
    driver: bridge

volumes:
  html:
    driver: local
EOF

    # Create complex test YAML file
    cat > "$TEST_YAML_FILES_DIR/complex-app.yml" << 'EOF'
name: complex-test-app
version: "2.0"
description: "Complex test application with multiple services"

containers:
  frontend:
    image: nginx:alpine
    ports:
      - "8081:80"
    environment:
      - NGINX_HOST=localhost
      - API_URL=http://backend:3000
    volumes:
      - ./frontend:/usr/share/nginx/html
    restart: unless-stopped
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    image: node:18-alpine
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DB_HOST=database
      - DB_PORT=5432
    volumes:
      - ./backend:/app
    working_dir: /app
    command: ["npm", "start"]
    restart: unless-stopped
    depends_on:
      - database
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  database:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=testdb
      - POSTGRES_USER=testuser
      - POSTGRES_PASSWORD=testpass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U testuser -d testdb"]
      interval: 30s
      timeout: 10s
      retries: 3

  cache:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge
  backend:
    driver: bridge

volumes:
  postgres_data:
    driver: local
  frontend:
    driver: local
  backend:
    driver: local
EOF

    # Create invalid test YAML file
    cat > "$TEST_YAML_FILES_DIR/invalid-app.yml" << 'EOF'
name: invalid-test-app
version: "1.0"
description: "Invalid YAML file for testing error handling"

containers:
  invalid-container:
    image: nonexistent-image:latest
    ports:
      - "invalid-port"
    environment:
      - INVALID_ENV_VAR
    volumes:
      - invalid-volume:/invalid/path
    restart: invalid-restart-policy
    healthcheck:
      test: ["INVALID", "COMMAND"]
      interval: invalid-interval
      timeout: invalid-timeout
      retries: invalid-retries

networks:
  invalid-network:
    driver: invalid-driver

volumes:
  invalid-volume:
    driver: invalid-driver
EOF

    echo "Test data generation complete"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Expected: not $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Expected to contain: $needle"
        echo "  Actual: $haystack"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Expected not to contain: $needle"
        echo "  Actual: $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-Assertion failed}"
    
    if [[ -f "$file" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  File does not exist: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-Assertion failed}"
    
    if [[ ! -f "$file" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  File should not exist: $file"
        return 1
    fi
}

assert_directory_exists() {
    local directory="$1"
    local message="${2:-Assertion failed}"
    
    if [[ -d "$directory" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Directory does not exist: $directory"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected_code" == "$actual_code" ]]; then
        echo "✓ $message"
        return 0
    else
        echo "✗ $message"
        echo "  Expected exit code: $expected_code"
        echo "  Actual exit code:   $actual_code"
        return 1
    fi
}

# Test helper functions
run_with_timeout() {
    local timeout="$1"
    local command="$2"
    local output_file="$3"
    
    timeout "$timeout" bash -c "$command" > "$output_file" 2>&1
    local exit_code=$?
    
    if [[ $exit_code -eq 124 ]]; then
        echo "Command timed out after ${timeout}s"
        return 124
    fi
    
    return $exit_code
}

capture_output() {
    local command="$1"
    local output_file="$2"
    
    bash -c "$command" > "$output_file" 2>&1
    return $?
}

wait_for_condition() {
    local condition="$1"
    local timeout="$2"
    local interval="${3:-1}"
    local message="${4:-Waiting for condition}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    echo "$message..."
    
    while [[ $(date +%s) -lt $end_time ]]; do
        if eval "$condition"; then
            echo "Condition met"
            return 0
        fi
        
        # Show static waiting message with animating dots
        show_waiting_dots "Waiting for completion"
        
        sleep "$interval"
    done
    
    echo "Condition not met within ${timeout}s"
    return 1
}

# Export functions for use in test scripts
export -f assert_equals
export -f assert_not_equals
export -f assert_contains
export -f assert_not_contains
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_directory_exists
export -f assert_exit_code
export -f run_with_timeout
export -f capture_output
export -f wait_for_condition
export -f validate_test_environment
export -f setup_test_environment
export -f cleanup_test_environment
export -f generate_test_data 