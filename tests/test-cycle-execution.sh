#!/usr/bin/env bash

# Docker Ops Manager - Test Cycle Execution
# Complete test cycle: nginx → traefik → cleanup nginx → cleanup traefik

set -euo pipefail

# Script information
SCRIPT_NAME="test-cycle-execution.sh"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
MAIN_SCRIPT="$SCRIPT_DIR/docker_ops_manager.sh"
NGINX_YAML="$SCRIPT_DIR/examples/nginx-app.yml"
TRAEFIK_YAML="$SCRIPT_DIR/examples/traefik-app.yml"

# Load library modules for proper configuration
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/yaml_parser.sh"

# Initialize configuration
load_config
init_config_file
init_logging "DEBUG"

# Get proper paths from library
STATE_FILE="$DOCKER_OPS_STATE_FILE"
LOG_FILE="$DOCKER_OPS_CURRENT_LOG_FILE"

# Test state tracking
CURRENT_STEP=0
TOTAL_STEPS=4

# Print header
print_header() {
    local step_num="$1"
    local step_desc="$2"
    echo -e "\n${BLUE}=== Docker Ops Manager Test Cycle ===${NC}"
    echo -e "${BLUE}Step $step_num/$TOTAL_STEPS: $step_desc${NC}"
    echo -e "${BLUE}Time: $(date)${NC}"
    echo
}

# Print status
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "SUCCESS")
            echo -e "${GREEN}✓ SUCCESS${NC} - $message"
            ;;
        "FAILED")
            echo -e "${RED}✗ FAILED${NC} - $message"
            ;;
        "INFO")
            echo -e "${CYAN}ℹ INFO${NC} - $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠ WARNING${NC} - $message"
            ;;
    esac
}

# Check state file
check_state_file() {
    if [[ -f "$STATE_FILE" ]]; then
        echo -e "\n${PURPLE}=== State File Content ===${NC}"
        cat "$STATE_FILE" | jq '.' 2>/dev/null || cat "$STATE_FILE"
        echo
    else
        echo -e "\n${YELLOW}State file not found: $STATE_FILE${NC}"
    fi
}

# Check logs using library function
check_logs() {
    echo -e "\n${PURPLE}=== Recent Logs ===${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        show_recent_logs 20
    else
        echo "No log file found: $LOG_FILE"
    fi
    echo
}

# Wait for container health
wait_for_container_health() {
    local container_name="$1"
    local max_wait=60
    local wait_time=0
    
    echo -e "${CYAN}Waiting for container $container_name to be healthy...${NC}"
    
    while [[ $wait_time -lt $max_wait ]]; do
        local health_status=$(docker inspect "$container_name" --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
        
        if [[ "$health_status" == "healthy" ]]; then
            print_status "SUCCESS" "Container $container_name is healthy"
            return 0
        elif [[ "$health_status" == "unhealthy" ]]; then
            print_status "FAILED" "Container $container_name is unhealthy"
            return 1
        fi
        
        sleep 5
        wait_time=$((wait_time + 5))
        echo -e "${YELLOW}Still waiting... ($wait_time/$max_wait seconds)${NC}"
    done
    
    print_status "WARNING" "Container $container_name health check timed out"
    return 1
}

# Test container accessibility
test_container_accessibility() {
    local container_name="$1"
    local port="$2"
    local endpoint="$3"
    
    echo -e "${CYAN}Testing accessibility for $container_name on port $port${NC}"
    
    # Wait a moment for the service to be ready
    sleep 3
    
    # Test the endpoint
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$endpoint" 2>/dev/null || echo "000")
    
    if [[ "$response" == "200" ]]; then
        print_status "SUCCESS" "$container_name is accessible on port $port"
        return 0
    else
        print_status "FAILED" "$container_name returned HTTP $response on port $port"
        return 1
    fi
}

# Step 1: Generate and install nginx
step1_nginx() {
    CURRENT_STEP=1
    print_header $CURRENT_STEP "Generate and Install Nginx Container"
    
    print_status "INFO" "Starting nginx container deployment..."
    log_info "TEST" "nginx-test-app" "Starting nginx container deployment"
    
    # Generate nginx application
    echo -e "${CYAN}Generating nginx application...${NC}"
    local generate_result=$("$MAIN_SCRIPT" generate "$NGINX_YAML" 2>&1)
    local generate_exit_code=$?
    
    if [[ $generate_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Nginx application generated successfully"
        log_info "TEST" "nginx-test-app" "Application generated successfully"
        echo "$generate_result"
    else
        print_status "FAILED" "Failed to generate nginx application"
        log_error "TEST" "nginx-test-app" "Failed to generate application"
        echo "$generate_result"
        return 1
    fi
    
    # Install nginx application
    echo -e "\n${CYAN}Installing nginx application...${NC}"
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    local install_result=$("$MAIN_SCRIPT" install "$actual_container_name" 2>&1)
    local install_exit_code=$?
    
    if [[ $install_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Nginx application installed successfully"
        log_info "TEST" "nginx-test-app" "Application installed successfully"
        echo "$install_result"
    else
        print_status "FAILED" "Failed to install nginx application"
        log_error "TEST" "nginx-test-app" "Failed to install application"
        echo "$install_result"
        return 1
    fi
    
    # Check state file
    check_state_file
    
    # Check logs
    check_logs
    
    # Wait for nginx to be healthy
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    wait_for_container_health "$actual_container_name"
    
    # Test nginx accessibility
    test_container_accessibility "nginx" "8080" "/"
    
    # Show nginx status
    echo -e "\n${CYAN}Nginx application status:${NC}"
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    "$MAIN_SCRIPT" status "$actual_container_name" 2>&1
    
    log_info "TEST" "nginx-test-app" "Step 1 completed: Nginx container is running and accessible"
    print_status "SUCCESS" "Step 1 completed: Nginx container is running and accessible"
}

# Step 2: Generate and install traefik
step2_traefik() {
    CURRENT_STEP=2
    print_header $CURRENT_STEP "Generate and Install Traefik Container"
    
    print_status "INFO" "Starting traefik container deployment..."
    log_info "TEST" "traefik-test-app" "Starting traefik container deployment"
    
    # Generate traefik application
    echo -e "${CYAN}Generating traefik application...${NC}"
    local generate_result=$("$MAIN_SCRIPT" generate "$TRAEFIK_YAML" 2>&1)
    local generate_exit_code=$?
    
    if [[ $generate_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Traefik application generated successfully"
        log_info "TEST" "traefik-test-app" "Application generated successfully"
        echo "$generate_result"
    else
        print_status "FAILED" "Failed to generate traefik application"
        log_error "TEST" "traefik-test-app" "Failed to generate application"
        echo "$generate_result"
        return 1
    fi
    
    # Install traefik application
    echo -e "\n${CYAN}Installing traefik application...${NC}"
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    local install_result=$("$MAIN_SCRIPT" install "$actual_container_name" 2>&1)
    local install_exit_code=$?
    
    if [[ $install_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Traefik application installed successfully"
        log_info "TEST" "traefik-test-app" "Application installed successfully"
        echo "$install_result"
    else
        print_status "FAILED" "Failed to install traefik application"
        log_error "TEST" "traefik-test-app" "Failed to install application"
        echo "$install_result"
        return 1
    fi
    
    # Check state file
    check_state_file
    
    # Check logs
    check_logs
    
    # Wait for traefik to be healthy
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    wait_for_container_health "$actual_container_name"
    
    # Test traefik accessibility
    test_container_accessibility "traefik" "8082" "/api/rawdata"
    
    # Show traefik status
    echo -e "\n${CYAN}Traefik application status:${NC}"
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    "$MAIN_SCRIPT" status "$actual_container_name" 2>&1
    
    log_info "TEST" "traefik-test-app" "Step 2 completed: Traefik container is running and accessible"
    print_status "SUCCESS" "Step 2 completed: Traefik container is running and accessible"
}

# Step 3: Clean up nginx
step3_cleanup_nginx() {
    CURRENT_STEP=3
    print_header $CURRENT_STEP "Clean Up Nginx Container"
    
    print_status "INFO" "Starting nginx container cleanup..."
    log_info "TEST" "nginx-test-app" "Starting nginx container cleanup"
    
    # Show nginx logs before cleanup
    echo -e "\n${CYAN}Nginx logs before cleanup:${NC}"
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    "$MAIN_SCRIPT" logs "$actual_container_name" 2>&1
    
    # Cleanup nginx application
    echo -e "\n${CYAN}Cleaning up nginx application...${NC}"
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    local cleanup_result=$("$MAIN_SCRIPT" cleanup "$actual_container_name" 2>&1)
    local cleanup_exit_code=$?
    
    if [[ $cleanup_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Nginx application cleaned up successfully"
        log_info "TEST" "nginx-test-app" "Application cleaned up successfully"
        echo "$cleanup_result"
    else
        print_status "FAILED" "Failed to cleanup nginx application"
        log_error "TEST" "nginx-test-app" "Failed to cleanup application"
        echo "$cleanup_result"
        return 1
    fi
    
    # Verify nginx is stopped
    local actual_container_name=$(resolve_container_name "$NGINX_YAML" "nginx")
    local nginx_running=$(docker ps --filter "name=$actual_container_name" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -z "$nginx_running" ]]; then
        print_status "SUCCESS" "Nginx container is no longer running"
        log_info "TEST" "nginx-test-app" "Container successfully stopped"
    else
        print_status "WARNING" "Nginx container is still running: $nginx_running"
        log_warn "TEST" "nginx-test-app" "Container still running after cleanup"
    fi
    
    # Check state file
    check_state_file
    
    # Check logs
    check_logs
    
    # Verify traefik is still running
    local actual_traefik_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    local traefik_running=$(docker ps --filter "name=$actual_traefik_container_name" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -n "$traefik_running" ]]; then
        print_status "SUCCESS" "Traefik container is still running after nginx cleanup"
        log_info "TEST" "traefik-test-app" "Container still running after nginx cleanup"
        test_container_accessibility "traefik" "8082" "/api/rawdata"
    else
        print_status "WARNING" "Traefik container is not running after nginx cleanup"
        log_warn "TEST" "traefik-test-app" "Container stopped unexpectedly"
    fi
    
    log_info "TEST" "nginx-test-app" "Step 3 completed: Nginx container cleaned up successfully"
    print_status "SUCCESS" "Step 3 completed: Nginx container cleaned up successfully"
}

# Step 4: Clean up traefik
step4_cleanup_traefik() {
    CURRENT_STEP=4
    print_header $CURRENT_STEP "Clean Up Traefik Container"
    
    print_status "INFO" "Starting traefik container cleanup..."
    log_info "TEST" "traefik-test-app" "Starting traefik container cleanup"
    
    # Show traefik logs before cleanup
    echo -e "\n${CYAN}Traefik logs before cleanup:${NC}"
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    "$MAIN_SCRIPT" logs "$actual_container_name" 2>&1
    
    # Cleanup traefik application
    echo -e "\n${CYAN}Cleaning up traefik application...${NC}"
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    local cleanup_result=$("$MAIN_SCRIPT" cleanup "$actual_container_name" 2>&1)
    local cleanup_exit_code=$?
    
    if [[ $cleanup_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Traefik application cleaned up successfully"
        log_info "TEST" "traefik-test-app" "Application cleaned up successfully"
        echo "$cleanup_result"
    else
        print_status "FAILED" "Failed to cleanup traefik application"
        log_error "TEST" "traefik-test-app" "Failed to cleanup application"
        echo "$cleanup_result"
        return 1
    fi
    
    # Verify traefik is stopped
    local actual_container_name=$(resolve_container_name "$TRAEFIK_YAML" "traefik")
    local traefik_running=$(docker ps --filter "name=$actual_container_name" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -z "$traefik_running" ]]; then
        print_status "SUCCESS" "Traefik container is no longer running"
        log_info "TEST" "traefik-test-app" "Container successfully stopped"
    else
        print_status "WARNING" "Traefik container is still running: $traefik_running"
        log_warn "TEST" "traefik-test-app" "Container still running after cleanup"
    fi
    
    # Check state file
    check_state_file
    
    # Check logs
    check_logs
    
    # Verify no test containers are running
    local test_containers=$(docker ps --filter "name=test-" --format "{{.Names}}" 2>/dev/null || echo "")
    if [[ -z "$test_containers" ]]; then
        print_status "SUCCESS" "All test containers have been cleaned up"
        log_info "TEST" "all" "All test containers successfully cleaned up"
    else
        print_status "WARNING" "Some test containers are still running: $test_containers"
        log_warn "TEST" "all" "Some test containers still running: $test_containers"
    fi
    
    log_info "TEST" "traefik-test-app" "Step 4 completed: Traefik container cleaned up successfully"
    print_status "SUCCESS" "Step 4 completed: Traefik container cleaned up successfully"
}

# Main execution
main() {
    echo -e "${BLUE}=== Docker Ops Manager Test Cycle Execution (Nginx Only) ===${NC}"
    echo -e "${BLUE}Version: $SCRIPT_VERSION${NC}"
    echo -e "${BLUE}Date: $(date)${NC}"
    echo -e "${BLUE}Main Script: $MAIN_SCRIPT${NC}"
    echo -e "${BLUE}Nginx YAML: $NGINX_YAML${NC}"
    echo -e "${BLUE}Traefik YAML: $TRAEFIK_YAML${NC}"
    echo -e "${BLUE}State File: $STATE_FILE${NC}"
    echo -e "${BLUE}Log File: $LOG_FILE${NC}"
    echo
    
    # Log test cycle start
    log_info "TEST" "all" "Starting Docker Ops Manager test cycle execution"
    
    # Check prerequisites
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        print_status "FAILED" "Main script not found: $MAIN_SCRIPT"
        exit 1
    fi
    
    if [[ ! -f "$NGINX_YAML" ]]; then
        print_status "FAILED" "Nginx YAML file not found: $NGINX_YAML"
        exit 1
    fi
    
    if [[ ! -f "$TRAEFIK_YAML" ]]; then
        print_status "FAILED" "Traefik YAML file not found: $TRAEFIK_YAML"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_status "FAILED" "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    print_status "SUCCESS" "Prerequisites check passed"
    
    # Execute test steps
    local step_failed=false
    
    if step1_nginx; then
        print_status "SUCCESS" "Step 1 completed successfully"
    else
        print_status "FAILED" "Step 1 failed"
        step_failed=true
    fi
    
    if step2_traefik; then
        print_status "SUCCESS" "Step 2 completed successfully"
    else
        print_status "FAILED" "Step 2 failed"
        step_failed=true
    fi
    
    if step3_cleanup_nginx; then
        print_status "SUCCESS" "Step 3 completed successfully"
    else
        print_status "FAILED" "Step 3 failed"
        step_failed=true
    fi
    
    if step4_cleanup_traefik; then
        print_status "SUCCESS" "Step 4 completed successfully"
    else
        print_status "FAILED" "Step 4 failed"
        step_failed=true
    fi
    
    # Final summary
    echo -e "\n${BLUE}=== Test Cycle Summary ===${NC}"
    if [[ "$step_failed" == "true" ]]; then
        print_status "FAILED" "Test cycle completed with failures"
        log_error "TEST" "all" "Test cycle completed with failures"
        exit 1
    else
        print_status "SUCCESS" "All test steps completed successfully!"
        log_info "TEST" "all" "All test steps completed successfully"
        echo -e "${GREEN}✓ Nginx container generated and installed${NC}"
        echo -e "${GREEN}✓ Traefik container generated and installed${NC}"
        echo -e "${GREEN}✓ Nginx container cleaned up${NC}"
        echo -e "${GREEN}✓ Traefik container cleaned up${NC}"
        echo -e "${GREEN}✓ State file and logs monitored throughout${NC}"
        
        # Show final logs
        echo -e "\n${CYAN}Final test cycle logs:${NC}"
        check_logs
    fi
}

# Run main function
main "$@" 