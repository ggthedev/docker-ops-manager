#!/usr/bin/env bash

# Test: Help System Refactor
# Description: Tests the refactored help system after moving to brew-style format

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test variables
TEST_NAME="test_help_refactor"
TEST_LOG="$SCRIPT_DIR/logs/${TEST_NAME}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$TEST_LOG")"

# Test functions
test_general_help() {
    echo "Testing general help output..."
    
    local result=$("$PROJECT_ROOT/docker_mgr.sh" -h 2>&1)
    
    # Check for brew-style format
    if echo "$result" | grep -q "Example usage:"; then
        echo "✓ General help shows 'Example usage:' section"
    else
        echo "✗ General help missing 'Example usage:' section"
        return 1
    fi
    
    if echo "$result" | grep -q "Container Management:"; then
        echo "✓ General help shows 'Container Management:' section"
    else
        echo "✗ General help missing 'Container Management:' section"
        return 1
    fi
    
    if echo "$result" | grep -q "Information:"; then
        echo "✓ General help shows 'Information:' section"
    else
        echo "✗ General help missing 'Information:' section"
        return 1
    fi
    
    if echo "$result" | grep -q "Further help:"; then
        echo "✓ General help shows 'Further help:' section"
    else
        echo "✗ General help missing 'Further help:' section"
        return 1
    fi
    
    # Check that it's concise (not too long)
    local line_count=$(echo "$result" | wc -l)
    if [[ $line_count -le 35 ]]; then
        echo "✓ General help is concise ($line_count lines)"
    else
        echo "✗ General help is too verbose ($line_count lines)"
        return 1
    fi
}

test_command_specific_help() {
    echo "Testing command-specific help..."
    
    # Test generate command help
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help generate 2>&1)
    if echo "$result" | grep -q "Usage: ./docker_mgr.sh generate"; then
        echo "✓ Generate command help shows correct usage"
    else
        echo "✗ Generate command help missing correct usage"
        return 1
    fi
    
    if echo "$result" | grep -q "Arguments:"; then
        echo "✓ Generate command help shows arguments section"
    else
        echo "✗ Generate command help missing arguments section"
        return 1
    fi
    
    if echo "$result" | grep -q "Options:"; then
        echo "✓ Generate command help shows options section"
    else
        echo "✗ Generate command help missing options section"
        return 1
    fi
    
    if echo "$result" | grep -q "Examples:"; then
        echo "✓ Generate command help shows examples section"
    else
        echo "✗ Generate command help missing examples section"
        return 1
    fi
    
    # Test cleanup command help
    result=$("$PROJECT_ROOT/docker_mgr.sh" help cleanup 2>&1)
    if echo "$result" | grep -q "Usage: ./docker_mgr.sh cleanup"; then
        echo "✓ Cleanup command help shows correct usage"
    else
        echo "✗ Cleanup command help missing correct usage"
        return 1
    fi
    
    if echo "$result" | grep -q "all.*Cleanup ALL containers"; then
        echo "✓ Cleanup command help shows danger warning"
    else
        echo "✗ Cleanup command help missing danger warning"
        return 1
    fi
}

test_short_option_help() {
    echo "Testing short option help..."
    
    # Test short option mapping
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help -g 2>&1)
    if echo "$result" | grep -q "Usage: ./docker_mgr.sh generate"; then
        echo "✓ Short option -g maps to generate help"
    else
        echo "✗ Short option -g does not map to generate help"
        return 1
    fi
    
    result=$("$PROJECT_ROOT/docker_mgr.sh" help -c 2>&1)
    if echo "$result" | grep -q "Usage: ./docker_mgr.sh cleanup"; then
        echo "✓ Short option -c maps to cleanup help"
    else
        echo "✗ Short option -c does not map to cleanup help"
        return 1
    fi
    
    result=$("$PROJECT_ROOT/docker_mgr.sh" help -s 2>&1)
    if echo "$result" | grep -q "Usage: ./docker_mgr.sh start"; then
        echo "✓ Short option -s maps to start help"
    else
        echo "✗ Short option -s does not map to start help"
        return 1
    fi
}

test_unknown_command_help() {
    echo "Testing unknown command help..."
    
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help unknown-command 2>&1)
    if echo "$result" | grep -q "Unknown command: unknown-command"; then
        echo "✓ Unknown command shows appropriate error"
    else
        echo "✗ Unknown command does not show appropriate error"
        return 1
    fi
    
    if echo "$result" | grep -q "Available commands:"; then
        echo "✓ Unknown command shows available commands list"
    else
        echo "✗ Unknown command does not show available commands list"
        return 1
    fi
}

test_help_without_command() {
    echo "Testing help without command argument..."
    
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help 2>&1)
    if echo "$result" | grep -q "Example usage:"; then
        echo "✓ Help without command shows general help"
    else
        echo "✗ Help without command does not show general help"
        return 1
    fi
}

test_help_error_handling() {
    echo "Testing help error handling..."
    
    # Test too many arguments for help
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help generate cleanup 2>&1)
    if echo "$result" | grep -q "Too many arguments for help command"; then
        echo "✓ Help with too many arguments shows appropriate error"
    else
        echo "✗ Help with too many arguments does not show appropriate error"
        return 1
    fi
}

test_help_content_quality() {
    echo "Testing help content quality..."
    
    # Test that help content is informative
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help generate 2>&1)
    
    # Check for key information
    if echo "$result" | grep -q "YAML_FILE"; then
        echo "✓ Generate help explains YAML_FILE argument"
    else
        echo "✗ Generate help missing YAML_FILE argument explanation"
        return 1
    fi
    
    if echo "$result" | grep -q "docker-compose"; then
        echo "✓ Generate help mentions docker-compose support"
    else
        echo "✗ Generate help missing docker-compose mention"
        return 1
    fi
    
    if echo "$result" | grep -q "Examples:"; then
        echo "✓ Generate help includes examples"
    else
        echo "✗ Generate help missing examples"
        return 1
    fi
}

test_help_examples() {
    echo "Testing help examples command..."
    
    # Test help examples command
    local result=$("$PROJECT_ROOT/docker_mgr.sh" help examples 2>&1)
    
    # Check for examples structure
    if echo "$result" | grep -q "Docker Ops Manager - Usage Examples"; then
        echo "✓ Help examples shows proper header"
    else
        echo "✗ Help examples missing proper header"
        return 1
    fi
    
    if echo "$result" | grep -q "Basic Operations:"; then
        echo "✓ Help examples shows basic operations section"
    else
        echo "✗ Help examples missing basic operations section"
        return 1
    fi
    
    if echo "$result" | grep -q "Container Management:"; then
        echo "✓ Help examples shows container management section"
    else
        echo "✗ Help examples missing container management section"
        return 1
    fi
    
    if echo "$result" | grep -q "Cleanup Operations:"; then
        echo "✓ Help examples shows cleanup operations section"
    else
        echo "✗ Help examples missing cleanup operations section"
        return 1
    fi
    
    if echo "$result" | grep -q "Advanced Usage:"; then
        echo "✓ Help examples shows advanced usage section"
    else
        echo "✗ Help examples missing advanced usage section"
        return 1
    fi
    
    # Check for specific examples
    if echo "$result" | grep -q "./docker_mgr.sh generate docker-compose.yml"; then
        echo "✓ Help examples includes generate example"
    else
        echo "✗ Help examples missing generate example"
        return 1
    fi
    
    if echo "$result" | grep -q "./docker_mgr.sh -g -y docker-compose.yml -o 30 -f"; then
        echo "✓ Help examples includes advanced generate example"
    else
        echo "✗ Help examples missing advanced generate example"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting Help System Refactor Tests"
    echo "==================================="
    
    # Test general help
    test_general_help
    echo
    
    # Test command-specific help
    test_command_specific_help
    echo
    
    # Test short option help
    test_short_option_help
    echo
    
    # Test unknown command help
    test_unknown_command_help
    echo
    
    # Test help without command
    test_help_without_command
    echo
    
    # Test help error handling
    test_help_error_handling
    echo
    
    # Test help content quality
    test_help_content_quality
    echo
    
    # Test help examples
    test_help_examples
    echo
    
    echo "All help system refactor tests completed successfully!"
}

# Run the tests
main "$@" 