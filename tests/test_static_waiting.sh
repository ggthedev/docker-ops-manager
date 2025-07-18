#!/usr/bin/env bash

# Test: Static Waiting Animation
# Description: Demonstrates the new static waiting animation

set -euo pipefail

# Source the main script to get access to all functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the library files
source "$PROJECT_ROOT/lib/utils.sh"

echo "Testing Static Waiting Animation"
echo "================================"
echo

echo "This will show only animating dots for 10 seconds:"
echo "You should see:"
echo "  ."
echo "  .."
echo "  ..."
echo "  (repeating for 10 seconds)"
echo

# Show the dots animation for 10 seconds
show_waiting_animation 10 "" "dots"

echo
echo "Animation completed!" 