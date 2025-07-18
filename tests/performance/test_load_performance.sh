#!/usr/bin/env bash

# Test: Load performance tests
# Description: Tests the Docker Ops Manager performance under various load conditions

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_load_performance"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
MAIN_SCRIPT="$PROJECT_ROOT/docker_ops_manager.sh"

# Performance test configuration
PERFORMANCE_TEST_DURATION=60
PERFORMANCE_TEST_CONTAINERS=10
PERFORMANCE_TEST_ITERATIONS=5
STRESS_TEST_CONTAINERS=20
CONCURRENT_OPERATIONS=5

# Test setup
setup_test() {
    echo "Setting up load performance test..."
    
    # Create test workspace
    mkdir -p "$TEST_TEMP_DIR/performance"
    cd "$TEST_TEMP_DIR/performance"
    
    # Create performance test YAML files
    for i in $(seq 1 $PERFORMANCE_TEST_CONTAINERS); do
        cat > "perf-app-$i.yml" << EOF
name: perf-app-$i
version: "1.0"
description: "Performance test application $i"

containers:
  app-$i:
    image: alpine:latest
    command: ["sh", "-c", "echo 'Perf App $i started' && sleep 3600"]
    environment:
      - APP_ID=$i
      - TEST_MODE=performance
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "echo", "healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge

volumes:
  data_$i:
    driver: local
EOF
    done
    
    # Create stress test YAML file
    cat > "stress-app.yml" << 'EOF'
name: stress-test-app
version: "1.0"
description: "Stress test application with multiple containers"

containers:
EOF

    for i in $(seq 1 $STRESS_TEST_CONTAINERS); do
        cat >> "stress-app.yml" << EOF
  stress-$i:
    image: alpine:latest
    command: ["sh", "-c", "echo 'Stress Container $i started' && sleep 3600"]
    environment:
      - STRESS_ID=$i
      - TEST_MODE=stress
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "echo", "healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    done

    cat >> "stress-app.yml" << 'EOF'

networks:
  default:
    driver: bridge

volumes:
  stress_data:
    driver: local
EOF

    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up load performance test..."
    
    # Stop and remove all test containers
    docker ps -a --filter "name=perf-app" --format "{{.ID}}" | xargs -r docker rm -f
    docker ps -a --filter "name=stress-test" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove test volumes
    docker volume ls --filter "name=data_" --format "{{.Name}}" | xargs -r docker volume rm
    docker volume ls --filter "name=stress_data" --format "{{.Name}}" | xargs -r docker volume rm
    
    # Clean up test files
    cd "$TEST_TEMP_DIR"
    rm -rf performance
    
    echo "Test cleanup complete"
}

# Performance measurement function
measure_performance() {
    local operation="$1"
    local start_time=$(date +%s.%N)
    
    eval "$operation"
    local exit_code=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    echo "$duration:$exit_code"
}

# Test 1: Single application performance
test_single_application_performance() {
    echo "Testing single application performance..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    local yaml_file="perf-app-1.yml"
    local results=()
    
    # Measure installation performance
    echo "Measuring installation performance..."
    for i in $(seq 1 $PERFORMANCE_TEST_ITERATIONS); do
        local result=$(measure_performance "\"$MAIN_SCRIPT\" install \"$yaml_file\" > /dev/null 2>&1")
        local duration=$(echo "$result" | cut -d: -f1)
        local exit_code=$(echo "$result" | cut -d: -f2)
        
        results+=("$duration")
        
        # Cleanup for next iteration
        "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
        
        echo "  Iteration $i: ${duration}s (exit code: $exit_code)"
    done
    
    # Calculate statistics
    local total=0
    local count=0
    for duration in "${results[@]}"; do
        total=$(echo "$total + $duration" | bc -l)
        count=$((count + 1))
    done
    
    local average=$(echo "scale=2; $total / $count" | bc -l)
    local min=$(printf '%s\n' "${results[@]}" | sort -n | head -1)
    local max=$(printf '%s\n' "${results[@]}" | sort -n | tail -1)
    
    echo "Installation Performance Results:"
    echo "  Average: ${average}s"
    echo "  Min: ${min}s"
    echo "  Max: ${max}s"
    echo "  Iterations: $count"
    
    # Performance assertions
    assert_equals "true" "$(echo "$average < 30" | bc -l)" "Average installation time should be under 30 seconds"
    assert_equals "true" "$(echo "$max < 60" | bc -l)" "Maximum installation time should be under 60 seconds"
    
    echo "✓ Single application performance test passed"
}

# Test 2: Multiple applications performance
test_multiple_applications_performance() {
    echo "Testing multiple applications performance..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    local start_time=$(date +%s)
    local installed_count=0
    
    # Install multiple applications concurrently
    echo "Installing $PERFORMANCE_TEST_CONTAINERS applications..."
    for i in $(seq 1 $PERFORMANCE_TEST_CONTAINERS); do
        local yaml_file="perf-app-$i.yml"
        
        # Install in background
        "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1 &
        installed_count=$((installed_count + 1))
        
        # Limit concurrent operations
        if [[ $((installed_count % CONCURRENT_OPERATIONS)) -eq 0 ]]; then
            wait
        fi
    done
    
    # Wait for all installations to complete
    wait
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    echo "Multiple Applications Performance Results:"
    echo "  Applications installed: $installed_count"
    echo "  Total time: ${total_duration}s"
    echo "  Average per app: $(echo "scale=2; $total_duration / $installed_count" | bc -l)s"
    
    # Verify all applications are running
    local running_count=$(docker ps --filter "name=perf-app" --format "{{.Names}}" | wc -l)
    assert_equals "$installed_count" "$running_count" "All applications should be running"
    
    # Performance assertions
    local avg_per_app=$(echo "scale=2; $total_duration / $installed_count" | bc -l)
    assert_equals "true" "$(echo "$avg_per_app < 15" | bc -l)" "Average installation time per app should be under 15 seconds"
    
    # Cleanup
    echo "Cleaning up multiple applications..."
    for i in $(seq 1 $PERFORMANCE_TEST_CONTAINERS); do
        local yaml_file="perf-app-$i.yml"
        "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1 &
    done
    wait
    
    echo "✓ Multiple applications performance test passed"
}

# Test 3: Stress test with many containers
test_stress_test_performance() {
    echo "Testing stress test performance..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    local yaml_file="stress-app.yml"
    
    # Measure stress test installation
    echo "Installing stress test application with $STRESS_TEST_CONTAINERS containers..."
    local start_time=$(date +%s)
    
    local install_result=$("$MAIN_SCRIPT" install "$yaml_file" 2>&1)
    local install_exit_code=$?
    
    local end_time=$(date +%s)
    local install_duration=$((end_time - start_time))
    
    assert_exit_code 0 "$install_exit_code" "Stress test installation should succeed"
    assert_contains "$install_result" "installed" "Stress test installation should report success"
    
    echo "Stress Test Performance Results:"
    echo "  Containers: $STRESS_TEST_CONTAINERS"
    echo "  Installation time: ${install_duration}s"
    echo "  Average per container: $(echo "scale=2; $install_duration / $STRESS_TEST_CONTAINERS" | bc -l)s"
    
    # Verify all containers are running
    local running_containers=$(docker ps --filter "name=stress-test" --format "{{.Names}}" | wc -l)
    assert_equals "$STRESS_TEST_CONTAINERS" "$running_containers" "All stress test containers should be running"
    
    # Measure status check performance
    echo "Measuring status check performance..."
    local status_start=$(date +%s)
    
    local status_result=$("$MAIN_SCRIPT" status "$yaml_file" 2>&1)
    local status_exit_code=$?
    
    local status_end=$(date +%s)
    local status_duration=$((status_end - status_start))
    
    assert_exit_code 0 "$status_exit_code" "Status check should succeed"
    assert_contains "$status_result" "running" "All containers should be running"
    
    echo "Status Check Performance:"
    echo "  Duration: ${status_duration}s"
    echo "  Containers checked: $STRESS_TEST_CONTAINERS"
    
    # Performance assertions
    assert_equals "true" "$(echo "$install_duration < 120" | bc -l)" "Stress test installation should complete within 120 seconds"
    assert_equals "true" "$(echo "$status_duration < 10" | bc -l)" "Status check should complete within 10 seconds"
    
    # Cleanup
    echo "Cleaning up stress test..."
    local cleanup_start=$(date +%s)
    
    local cleanup_result=$("$MAIN_SCRIPT" cleanup "$yaml_file" 2>&1)
    local cleanup_exit_code=$?
    
    local cleanup_end=$(date +%s)
    local cleanup_duration=$((cleanup_end - cleanup_start))
    
    assert_exit_code 0 "$cleanup_exit_code" "Stress test cleanup should succeed"
    assert_contains "$cleanup_result" "cleaned" "Cleanup should report success"
    
    echo "Cleanup Performance:"
    echo "  Duration: ${cleanup_duration}s"
    
    assert_equals "true" "$(echo "$cleanup_duration < 60" | bc -l)" "Cleanup should complete within 60 seconds"
    
    echo "✓ Stress test performance test passed"
}

# Test 4: Memory and resource usage
test_memory_resource_usage() {
    echo "Testing memory and resource usage..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    # Install a test application
    local yaml_file="perf-app-1.yml"
    "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1
    
    # Wait for container to be stable
    sleep 10
    
    # Measure memory usage
    local memory_usage=$(docker stats --no-stream --format "table {{.MemUsage}}" | grep "perf-app-1" | awk '{print $1}')
    local memory_value=$(echo "$memory_usage" | sed 's/[^0-9.]//g')
    
    echo "Memory Usage Results:"
    echo "  Container: perf-app-1"
    echo "  Memory usage: $memory_usage"
    echo "  Memory value: ${memory_value}MB"
    
    # Measure CPU usage
    local cpu_usage=$(docker stats --no-stream --format "table {{.CPUPerc}}" | grep "perf-app-1" | sed 's/%//')
    
    echo "CPU Usage Results:"
    echo "  CPU usage: ${cpu_usage}%"
    
    # Measure disk usage
    local disk_usage=$(docker system df --format "table {{.Size}}" | grep "perf-app-1" | awk '{print $1}')
    
    echo "Disk Usage Results:"
    echo "  Disk usage: $disk_usage"
    
    # Resource usage assertions
    assert_equals "true" "$(echo "$memory_value < 100" | bc -l)" "Memory usage should be under 100MB"
    assert_equals "true" "$(echo "$cpu_usage < 5" | bc -l)" "CPU usage should be under 5%"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Memory and resource usage test passed"
}

# Test 5: Concurrent operations performance
test_concurrent_operations_performance() {
    echo "Testing concurrent operations performance..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    # Create multiple test applications
    local test_apps=("perf-app-1.yml" "perf-app-2.yml" "perf-app-3.yml" "perf-app-4.yml" "perf-app-5.yml")
    
    # Test concurrent installations
    echo "Testing concurrent installations..."
    local start_time=$(date +%s)
    
    for yaml_file in "${test_apps[@]}"; do
        "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1 &
    done
    wait
    
    local end_time=$(date +%s)
    local concurrent_install_duration=$((end_time - start_time))
    
    echo "Concurrent Installation Results:"
    echo "  Applications: ${#test_apps[@]}"
    echo "  Duration: ${concurrent_install_duration}s"
    echo "  Average per app: $(echo "scale=2; $concurrent_install_duration / ${#test_apps[@]}" | bc -l)s"
    
    # Test concurrent status checks
    echo "Testing concurrent status checks..."
    local status_start=$(date +%s)
    
    for yaml_file in "${test_apps[@]}"; do
        "$MAIN_SCRIPT" status "$yaml_file" > /dev/null 2>&1 &
    done
    wait
    
    local status_end=$(date +%s)
    local concurrent_status_duration=$((status_end - status_start))
    
    echo "Concurrent Status Check Results:"
    echo "  Duration: ${concurrent_status_duration}s"
    echo "  Average per app: $(echo "scale=2; $concurrent_status_duration / ${#test_apps[@]}" | bc -l)s"
    
    # Test concurrent cleanups
    echo "Testing concurrent cleanups..."
    local cleanup_start=$(date +%s)
    
    for yaml_file in "${test_apps[@]}"; do
        "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1 &
    done
    wait
    
    local cleanup_end=$(date +%s)
    local concurrent_cleanup_duration=$((cleanup_end - cleanup_start))
    
    echo "Concurrent Cleanup Results:"
    echo "  Duration: ${concurrent_cleanup_duration}s"
    echo "  Average per app: $(echo "scale=2; $concurrent_cleanup_duration / ${#test_apps[@]}" | bc -l)s"
    
    # Performance assertions
    local avg_install=$(echo "scale=2; $concurrent_install_duration / ${#test_apps[@]}" | bc -l)
    local avg_status=$(echo "scale=2; $concurrent_status_duration / ${#test_apps[@]}" | bc -l)
    local avg_cleanup=$(echo "scale=2; $concurrent_cleanup_duration / ${#test_apps[@]}" | bc -l)
    
    assert_equals "true" "$(echo "$avg_install < 20" | bc -l)" "Average concurrent installation time should be under 20 seconds"
    assert_equals "true" "$(echo "$avg_status < 3" | bc -l)" "Average concurrent status check time should be under 3 seconds"
    assert_equals "true" "$(echo "$avg_cleanup < 15" | bc -l)" "Average concurrent cleanup time should be under 15 seconds"
    
    echo "✓ Concurrent operations performance test passed"
}

# Test 6: Long-running application performance
test_long_running_performance() {
    echo "Testing long-running application performance..."
    
    cd "$TEST_TEMP_DIR/performance"
    
    local yaml_file="perf-app-1.yml"
    
    # Install application
    "$MAIN_SCRIPT" install "$yaml_file" > /dev/null 2>&1
    
    # Monitor performance over time
    echo "Monitoring performance over $PERFORMANCE_TEST_DURATION seconds..."
    local start_time=$(date +%s)
    local end_time=$((start_time + PERFORMANCE_TEST_DURATION))
    local measurements=()
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local measurement_start=$(date +%s.%N)
        
        # Perform status check
        "$MAIN_SCRIPT" status "$yaml_file" > /dev/null 2>&1
        
        local measurement_end=$(date +%s.%N)
        local measurement_duration=$(echo "$measurement_end - $measurement_start" | bc -l)
        measurements+=("$measurement_duration")
        
        sleep 5
    done
    
    # Calculate statistics
    local total=0
    local count=0
    for duration in "${measurements[@]}"; do
        total=$(echo "$total + $duration" | bc -l)
        count=$((count + 1))
    done
    
    local average=$(echo "scale=3; $total / $count" | bc -l)
    local min=$(printf '%s\n' "${measurements[@]}" | sort -n | head -1)
    local max=$(printf '%s\n' "${measurements[@]}" | sort -n | tail -1)
    
    echo "Long-running Performance Results:"
    echo "  Duration: ${PERFORMANCE_TEST_DURATION}s"
    echo "  Measurements: $count"
    echo "  Average response time: ${average}s"
    echo "  Min response time: ${min}s"
    echo "  Max response time: ${max}s"
    
    # Performance assertions
    assert_equals "true" "$(echo "$average < 2" | bc -l)" "Average response time should be under 2 seconds"
    assert_equals "true" "$(echo "$max < 5" | bc -l)" "Maximum response time should be under 5 seconds"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Long-running application performance test passed"
}

# Main test execution
main() {
    echo "Starting load performance tests..."
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        echo "Error: 'bc' command is required for performance calculations"
        echo "Please install bc: brew install bc (macOS) or apt-get install bc (Ubuntu)"
        exit 1
    fi
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_single_application_performance
    test_multiple_applications_performance
    test_stress_test_performance
    test_memory_resource_usage
    test_concurrent_operations_performance
    test_long_running_performance
    
    # Cleanup
    cleanup_test
    
    echo "All load performance tests passed!"
}

# Run main function
main "$@" 