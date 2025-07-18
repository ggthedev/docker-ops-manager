#!/usr/bin/env bash

# Docker Ops Manager - Test Runner
# Comprehensive test suite for Docker Ops Manager

set -euo pipefail

# Script information
SCRIPT_NAME="test_runner.sh"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_CONFIG_FILE="$SCRIPT_DIR/test_config.sh"
TEST_RESULTS_DIR="$SCRIPT_DIR/results"
TEST_LOGS_DIR="$SCRIPT_DIR/logs"
TEST_TEMP_DIR="$SCRIPT_DIR/temp"

# Test state
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
CURRENT_TEST=""
TEST_START_TIME=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load test configuration
source "$TEST_CONFIG_FILE"

# Initialize test environment
initialize_test_env() {
    echo -e "${BLUE}=== Docker Ops Manager Test Suite ===${NC}"
    echo -e "${BLUE}Version: $SCRIPT_VERSION${NC}"
    echo -e "${BLUE}Date: $(date)${NC}"
    echo
    
    # Create test directories
    mkdir -p "$TEST_RESULTS_DIR"
    mkdir -p "$TEST_LOGS_DIR"
    mkdir -p "$TEST_TEMP_DIR"
    
    # Clean up previous test artifacts
    cleanup_test_artifacts
    
    # Initialize test results file
    echo "# Docker Ops Manager Test Results" > "$TEST_RESULTS_DIR/test_results.md"
    echo "Generated: $(date)" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "" >> "$TEST_RESULTS_DIR/test_results.md"
    
    echo -e "${GREEN}✓ Test environment initialized${NC}"
}

# Clean up test artifacts
cleanup_test_artifacts() {
    rm -rf "$TEST_TEMP_DIR"/*
    rm -rf "$TEST_LOGS_DIR"/*
}

# Print test header
print_test_header() {
    local test_name="$1"
    local test_description="$2"
    
    echo -e "\n${CYAN}=== $test_name ===${NC}"
    echo -e "${CYAN}Description: $test_description${NC}"
    echo -e "${CYAN}Started: $(date)${NC}"
    echo
}

# Print test result
print_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    local message="$4"
    
    case "$result" in
        "PASS")
            echo -e "${GREEN}✓ PASS${NC} - $test_name ($duration)"
            if [[ -n "$message" ]]; then
                echo -e "  ${GREEN}$message${NC}"
            fi
            ;;
        "FAIL")
            echo -e "${RED}✗ FAIL${NC} - $test_name ($duration)"
            if [[ -n "$message" ]]; then
                echo -e "  ${RED}$message${NC}"
            fi
            ;;
        "SKIP")
            echo -e "${YELLOW}⚠ SKIP${NC} - $test_name"
            if [[ -n "$message" ]]; then
                echo -e "  ${YELLOW}$message${NC}"
            fi
            ;;
    esac
    echo
}

# Record test result
record_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    local message="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$result" in
        "PASS")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            ;;
        "FAIL")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            ;;
        "SKIP")
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            ;;
    esac
    
    # Record in results file
    echo "## $test_name" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Result:** $result" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Duration:** $duration" >> "$TEST_RESULTS_DIR/test_results.md"
    if [[ -n "$message" ]]; then
        echo "- **Message:** $message" >> "$TEST_RESULTS_DIR/test_results.md"
    fi
    echo "" >> "$TEST_RESULTS_DIR/test_results.md"
}

# Run a single test
run_test() {
    local test_script="$1"
    local test_name="$2"
    local test_description="$3"
    
    CURRENT_TEST="$test_name"
    TEST_START_TIME=$(date +%s)
    
    print_test_header "$test_name" "$test_description"
    
    # Check if test should be skipped
    if [[ -f "$test_script" ]]; then
        # Run the test
        if bash "$test_script" "$PROJECT_ROOT" "$TEST_TEMP_DIR" "$TEST_LOGS_DIR"; then
            local end_time=$(date +%s)
            local duration=$((end_time - TEST_START_TIME))
            print_test_result "$test_name" "PASS" "${duration}s" "Test completed successfully"
            record_test_result "$test_name" "PASS" "${duration}s" "Test completed successfully"
        else
            local end_time=$(date +%s)
            local duration=$((end_time - TEST_START_TIME))
            print_test_result "$test_name" "FAIL" "${duration}s" "Test failed with exit code $?"
            record_test_result "$test_name" "FAIL" "${duration}s" "Test failed with exit code $?"
        fi
    else
        print_test_result "$test_name" "SKIP" "" "Test script not found: $test_script"
        record_test_result "$test_name" "SKIP" "" "Test script not found: $test_script"
    fi
}

# Run all tests in a category
run_test_category() {
    local category="$1"
    local category_name="$2"
    
    echo -e "\n${PURPLE}=== Running $category_name Tests ===${NC}"
    
    local test_dir="$SCRIPT_DIR/$category"
    if [[ ! -d "$test_dir" ]]; then
        echo -e "${YELLOW}No tests found for category: $category_name${NC}"
        return
    fi
    
    # Find all test scripts in the category
    local test_scripts=($(find "$test_dir" -name "test_*.sh" -type f | sort))
    
    if [[ ${#test_scripts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No test scripts found in $category_name${NC}"
        return
    fi
    
    for test_script in "${test_scripts[@]}"; do
        local test_name=$(basename "$test_script" .sh)
        local test_description=$(grep -m 1 "^# Test:" "$test_script" | cut -d: -f2- | xargs || echo "No description")
        run_test "$test_script" "$test_name" "$test_description"
    done
}

# Print test summary
print_test_summary() {
    echo -e "\n${BLUE}=== Test Summary ===${NC}"
    echo -e "${BLUE}Total Tests: $TOTAL_TESTS${NC}"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED_TESTS${NC}"
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "${BLUE}Pass Rate: ${pass_rate}%${NC}"
    fi
    
    echo -e "\n${BLUE}Test Results: $TEST_RESULTS_DIR/test_results.md${NC}"
    echo -e "${BLUE}Test Logs: $TEST_LOGS_DIR/${NC}"
    
    # Update results file with summary
    echo "## Test Summary" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Total Tests:** $TOTAL_TESTS" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Passed:** $PASSED_TESTS" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Failed:** $FAILED_TESTS" >> "$TEST_RESULTS_DIR/test_results.md"
    echo "- **Skipped:** $SKIPPED_TESTS" >> "$TEST_RESULTS_DIR/test_results.md"
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        echo "- **Pass Rate:** ${pass_rate}%" >> "$TEST_RESULTS_DIR/test_results.md"
    fi
    echo "" >> "$TEST_RESULTS_DIR/test_results.md"
}

# Show help
show_help() {
    echo "Docker Ops Manager Test Runner"
    echo ""
    echo "Usage: $0 [OPTIONS] [CATEGORIES...]"
    echo ""
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --version, -v       Show version"
    echo "  --clean, -c         Clean test artifacts before running"
    echo "  --verbose, -V       Enable verbose output"
    echo ""
    echo "Categories:"
    echo "  unit                Unit tests for individual components"
    echo "  integration         Integration tests for component interactions"
    echo "  functional          Functional tests for complete operations"
    echo "  performance         Performance and stress tests"
    echo "  security            Security and validation tests"
    echo "  all                 Run all test categories (default)"
    echo ""
    echo "Examples:"
    echo "  $0                  Run all tests"
    echo "  $0 unit             Run only unit tests"
    echo "  $0 unit integration Run unit and integration tests"
    echo "  $0 --clean          Clean artifacts and run all tests"
}

# Parse command line arguments
parse_arguments() {
    local categories=()
    local clean_artifacts=false
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "Test Runner v$SCRIPT_VERSION"
                exit 0
                ;;
            --clean|-c)
                clean_artifacts=true
                shift
                ;;
            --verbose|-V)
                verbose=true
                shift
                ;;
            unit|integration|functional|performance|security)
                categories+=("$1")
                shift
                ;;
            all)
                categories=("unit" "integration" "functional" "performance" "security")
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to all categories if none specified
    if [[ ${#categories[@]} -eq 0 ]]; then
        categories=("unit" "integration" "functional" "performance" "security")
    fi
    
    # Clean artifacts if requested
    if [[ "$clean_artifacts" == "true" ]]; then
        echo -e "${YELLOW}Cleaning test artifacts...${NC}"
        cleanup_test_artifacts
    fi
    
    # Set verbose mode
    if [[ "$verbose" == "true" ]]; then
        set -x
    fi
    
    # Run tests for each category
    for category in "${categories[@]}"; do
        case "$category" in
            unit)
                run_test_category "unit" "Unit"
                ;;
            integration)
                run_test_category "integration" "Integration"
                ;;
            functional)
                run_test_category "functional" "Functional"
                ;;
            performance)
                run_test_category "performance" "Performance"
                ;;
            security)
                run_test_category "security" "Security"
                ;;
        esac
    done
}

# Main execution
main() {
    # Initialize test environment
    initialize_test_env
    
    # Parse arguments and run tests
    parse_arguments "$@"
    
    # Print final summary
    print_test_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "\n${RED}Some tests failed. Check the logs for details.${NC}"
        exit 1
    else
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run main function with all arguments
main "$@" 