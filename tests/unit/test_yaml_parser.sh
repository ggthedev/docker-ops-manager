#!/usr/bin/env bash

# Test: YAML parser unit tests
# Description: Tests the YAML parsing and validation functionality

set -euo pipefail

# Test parameters
PROJECT_ROOT="$1"
TEST_TEMP_DIR="$2"
TEST_LOGS_DIR="$3"

# Test variables
TEST_NAME="test_yaml_parser"
TEST_LOG="$TEST_LOGS_DIR/${TEST_NAME}.log"
YAML_PARSER_LIB="$PROJECT_ROOT/lib/yaml_parser.sh"

# Test setup
setup_test() {
    echo "Setting up YAML parser test..."
    
    # Create test YAML files directory
    mkdir -p "$TEST_TEMP_DIR/yaml"
    
    # Create valid test YAML file
    cat > "$TEST_TEMP_DIR/yaml/valid-app.yml" << 'EOF'
name: test-app
version: "1.0"
description: "Test application for YAML parser"

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

networks:
  default:
    driver: bridge

volumes:
  html:
    driver: local
EOF

    # Create invalid YAML file (syntax error)
    cat > "$TEST_TEMP_DIR/yaml/invalid-syntax.yml" << 'EOF'
name: test-app
version: "1.0"
description: "Test application with syntax error"
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
networks:
  default:
    driver: bridge
volumes:
  html:
    driver: local
  # Missing closing brace
EOF

    # Create YAML file with missing required fields
    cat > "$TEST_TEMP_DIR/yaml/missing-fields.yml" << 'EOF'
version: "1.0"
description: "Test application with missing required fields"

containers:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
EOF

    # Create complex YAML file with multiple services
    cat > "$TEST_TEMP_DIR/yaml/complex-app.yml" << 'EOF'
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

    echo "Test setup complete"
}

# Test cleanup
cleanup_test() {
    echo "Cleaning up YAML parser test..."
    rm -rf "$TEST_TEMP_DIR/yaml"
}

# Test 1: Valid YAML parsing
test_valid_yaml_parsing() {
    echo "Testing valid YAML parsing..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    
    # Parse YAML file
    local parse_result=$(parse_yaml_file "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_exit_code 0 "$exit_code" "Valid YAML should parse successfully"
    assert_contains "$parse_result" "test-app" "Parsed result should contain app name"
    assert_contains "$parse_result" "nginx:alpine" "Parsed result should contain container image"
    
    echo "✓ Valid YAML parsing test passed"
}

# Test 2: Invalid YAML syntax
test_invalid_yaml_syntax() {
    echo "Testing invalid YAML syntax handling..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/invalid-syntax.yml"
    
    # Parse YAML file
    local parse_result=$(parse_yaml_file "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_not_equals 0 "$exit_code" "Invalid YAML should fail to parse"
    assert_contains "$parse_result" "error" "Error message should be present"
    
    echo "✓ Invalid YAML syntax test passed"
}

# Test 3: Missing required fields
test_missing_required_fields() {
    echo "Testing missing required fields validation..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/missing-fields.yml"
    
    # Parse YAML file
    local parse_result=$(parse_yaml_file "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_not_equals 0 "$exit_code" "YAML with missing required fields should fail validation"
    assert_contains "$parse_result" "name" "Error should mention missing name field"
    
    echo "✓ Missing required fields test passed"
}

# Test 4: Complex YAML parsing
test_complex_yaml_parsing() {
    echo "Testing complex YAML parsing..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/complex-app.yml"
    
    # Parse YAML file
    local parse_result=$(parse_yaml_file "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_exit_code 0 "$exit_code" "Complex YAML should parse successfully"
    assert_contains "$parse_result" "complex-test-app" "Parsed result should contain app name"
    assert_contains "$parse_result" "frontend" "Parsed result should contain frontend service"
    assert_contains "$parse_result" "backend" "Parsed result should contain backend service"
    assert_contains "$parse_result" "database" "Parsed result should contain database service"
    
    echo "✓ Complex YAML parsing test passed"
}

# Test 5: YAML validation
test_yaml_validation() {
    echo "Testing YAML validation..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    
    # Validate YAML file
    local validation_result=$(validate_yaml_file "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_exit_code 0 "$exit_code" "Valid YAML should pass validation"
    assert_contains "$validation_result" "valid" "Validation should report success"
    
    echo "✓ YAML validation test passed"
}

# Test 6: YAML schema validation
test_yaml_schema_validation() {
    echo "Testing YAML schema validation..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    
    # Validate YAML schema
    local schema_result=$(validate_yaml_schema "$yaml_file" 2>&1)
    local exit_code=$?
    
    # Assertions
    assert_exit_code 0 "$exit_code" "Valid YAML should pass schema validation"
    
    echo "✓ YAML schema validation test passed"
}

# Test 7: YAML field extraction
test_yaml_field_extraction() {
    echo "Testing YAML field extraction..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    
    # Extract specific fields
    local app_name=$(extract_yaml_field "$yaml_file" "name")
    local app_version=$(extract_yaml_field "$yaml_file" "version")
    local container_image=$(extract_yaml_field "$yaml_file" "containers.web.image")
    
    # Assertions
    assert_equals "test-app" "$app_name" "App name should be extracted correctly"
    assert_equals "1.0" "$app_version" "App version should be extracted correctly"
    assert_equals "nginx:alpine" "$container_image" "Container image should be extracted correctly"
    
    echo "✓ YAML field extraction test passed"
}

# Test 8: YAML modification
test_yaml_modification() {
    echo "Testing YAML modification..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    local modified_file="$TEST_TEMP_DIR/yaml/modified-app.yml"
    
    # Copy original file
    cp "$yaml_file" "$modified_file"
    
    # Modify YAML field
    modify_yaml_field "$modified_file" "version" "2.0"
    modify_yaml_field "$modified_file" "containers.web.image" "nginx:latest"
    
    # Extract modified fields
    local new_version=$(extract_yaml_field "$modified_file" "version")
    local new_image=$(extract_yaml_field "$modified_file" "containers.web.image")
    
    # Assertions
    assert_equals "2.0" "$new_version" "Version should be modified correctly"
    assert_equals "nginx:latest" "$new_image" "Container image should be modified correctly"
    
    echo "✓ YAML modification test passed"
}

# Test 9: YAML file existence check
test_yaml_file_existence() {
    echo "Testing YAML file existence check..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local existing_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    local non_existing_file="$TEST_TEMP_DIR/yaml/nonexistent.yml"
    
    # Check existing file
    local existing_result=$(check_yaml_file_exists "$existing_file" 2>&1)
    local existing_exit_code=$?
    
    # Check non-existing file
    local non_existing_result=$(check_yaml_file_exists "$non_existing_file" 2>&1)
    local non_existing_exit_code=$?
    
    # Assertions
    assert_exit_code 0 "$existing_exit_code" "Existing YAML file should be found"
    assert_not_equals 0 "$non_existing_exit_code" "Non-existing YAML file should not be found"
    
    echo "✓ YAML file existence check test passed"
}

# Test 10: YAML backup and restore
test_yaml_backup_restore() {
    echo "Testing YAML backup and restore..."
    
    # Source the YAML parser library
    source "$YAML_PARSER_LIB"
    
    local yaml_file="$TEST_TEMP_DIR/yaml/valid-app.yml"
    local backup_file="$TEST_TEMP_DIR/yaml/valid-app.yml.backup"
    
    # Create backup
    backup_yaml_file "$yaml_file"
    
    # Assertions
    assert_file_exists "$backup_file" "Backup file should be created"
    
    # Modify original file
    modify_yaml_field "$yaml_file" "version" "3.0"
    local modified_version=$(extract_yaml_field "$yaml_file" "version")
    assert_equals "3.0" "$modified_version" "Original file should be modified"
    
    # Restore from backup
    restore_yaml_file "$yaml_file"
    local restored_version=$(extract_yaml_field "$yaml_file" "version")
    assert_equals "1.0" "$restored_version" "File should be restored from backup"
    
    echo "✓ YAML backup and restore test passed"
}

# Main test execution
main() {
    echo "Starting YAML parser unit tests..."
    
    # Setup test environment
    setup_test
    
    # Run tests
    test_valid_yaml_parsing
    test_invalid_yaml_syntax
    test_missing_required_fields
    test_complex_yaml_parsing
    test_yaml_validation
    test_yaml_schema_validation
    test_yaml_field_extraction
    test_yaml_modification
    test_yaml_file_existence
    test_yaml_backup_restore
    
    # Cleanup
    cleanup_test
    
    echo "All YAML parser unit tests passed!"
}

# Run main function
main "$@" 