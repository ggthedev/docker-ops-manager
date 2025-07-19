#!/usr/bin/env bash

# Test script to verify single trace file approach
# This script tests that all traces are written to a single file with timestamps

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Testing Single Trace File Approach"
echo "=========================================="

# Clean up any existing trace files
echo ""
echo "Cleaning up existing trace files..."
rm -f ~/.config/docker-ops-manager/logs/docker_ops_trace.log*

# Test 1: First trace session
echo ""
echo "Test 1: First trace session"
echo "----------------------------"
./docker_mgr.sh generate --yaml ./examples/nginx-app.yml --trace

# Check trace file
echo ""
echo "Checking trace file after first session..."
if [[ -f ~/.config/docker-ops-manager/logs/docker_ops_trace.log ]]; then
    echo "✓ Trace file exists"
    echo "Trace file size: $(stat -f%z ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || stat -c%s ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || echo 'unknown') bytes"
    echo "First few lines:"
    head -10 ~/.config/docker-ops-manager/logs/docker_ops_trace.log
else
    echo "✗ Trace file not found"
    exit 1
fi

# Test 2: Second trace session (should append to same file)
echo ""
echo "Test 2: Second trace session"
echo "----------------------------"
./docker_mgr.sh status --trace

# Check trace file again
echo ""
echo "Checking trace file after second session..."
if [[ -f ~/.config/docker-ops-manager/logs/docker_ops_trace.log ]]; then
    echo "✓ Trace file still exists"
    echo "Trace file size: $(stat -f%z ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || stat -c%s ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || echo 'unknown') bytes"
    echo "Session separators found: $(grep -c '=== New Session ===' ~/.config/docker-ops-manager/logs/docker_ops_trace.log || echo '0')"
    echo "Last few lines:"
    tail -10 ~/.config/docker-ops-manager/logs/docker_ops_trace.log
else
    echo "✗ Trace file not found"
    exit 1
fi

# Test 3: Third trace session
echo ""
echo "Test 3: Third trace session"
echo "----------------------------"
./docker_mgr.sh cleanup --all --trace

# Final verification
echo ""
echo "Final verification"
echo "------------------"
if [[ -f ~/.config/docker-ops-manager/logs/docker_ops_trace.log ]]; then
    echo "✓ Single trace file maintained"
    echo "Total sessions: $(grep -c '=== New Session ===' ~/.config/docker-ops-manager/logs/docker_ops_trace.log || echo '0')"
    echo "Total lines: $(wc -l < ~/.config/docker-ops-manager/logs/docker_ops_trace.log)"
    echo "File size: $(stat -f%z ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || stat -c%s ~/.config/docker-ops-manager/logs/docker_ops_trace.log 2>/dev/null || echo 'unknown') bytes"
    
    echo ""
    echo "Sample of trace entries with timestamps:"
    grep -E '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}\]' ~/.config/docker-ops-manager/logs/docker_ops_trace.log | head -5
else
    echo "✗ Trace file not found"
    exit 1
fi

echo ""
echo "=========================================="
echo "Single trace file approach test completed!"
echo "=========================================="

# Show trace file location
echo ""
echo "Trace file location: ~/.config/docker-ops-manager/logs/docker_ops_trace.log"
echo "You can view the full trace with: cat ~/.config/docker-ops-manager/logs/docker_ops_trace.log" 