# Single Trace File Approach

## Overview

The Docker Ops Manager tracing system has been updated to use a single trace file approach, similar to the logging system. Instead of creating individual timestamped trace files for each session, all trace information is now consolidated into a single file with timestamps.

## Key Changes

### 1. Single Trace File
- **Before**: `docker_ops_trace_20250118_143022.log` (individual files per session)
- **After**: `docker_ops_trace.log` (single file for all sessions)

### 2. Session Management
- Each script execution creates a new session within the same file
- Sessions are separated by clear markers
- All sessions maintain their individual timestamps

### 3. File Rotation
- Automatic rotation when file exceeds 10MB
- Old trace files are backed up with timestamps
- Automatic cleanup of old trace files based on retention period

## Benefits

### 1. **Easier Debugging**
- All trace information in one place
- No need to search through multiple files
- Complete history of all operations

### 2. **Better Performance**
- No file creation overhead for each session
- Faster file system operations
- Reduced disk fragmentation

### 3. **Consistent with Logging**
- Same approach as the logging system
- Familiar patterns for users
- Unified file management

### 4. **Space Management**
- Automatic rotation prevents unlimited growth
- Configurable retention period
- Cleanup of old files

## File Structure

### Trace File Location
```
~/.config/docker-ops-manager/logs/docker_ops_trace.log
```

### File Format
```
=== Docker Ops Manager Trace Log ===
Started: 2025-01-18 14:30:22
PID: 12345
Command: ./docker_ops_manager.sh generate --yaml ./examples/nginx-app.yml --trace
===================================

[2025-01-18 14:30:22.123] → ENTER: init_tracing
[2025-01-18 14:30:22.124]   Args: enabled=true
[2025-01-18 14:30:22.125]   Context: Tracing system initialization
[2025-01-18 14:30:22.126] ← EXIT: init_tracing (rc=0)
[2025-01-18 14:30:22.127]   Result: Tracing enabled
[2025-01-18 14:30:22.128]   Duration: 0.005s

=== Session Summary ===
Ended: 2025-01-18 14:30:25.456
Total functions traced: 15
Final depth: 0
======================

=== New Session ===
Started: 2025-01-18 14:35:10.789
PID: 12346
Command: ./docker_ops_manager.sh status --trace
===================

[2025-01-18 14:35:10.790] → ENTER: init_tracing
...
```

## Configuration

### Trace File Rotation
- **Size Limit**: 10MB (configurable)
- **Backup Format**: `docker_ops_trace.log.YYYYMMDD_HHMMSS`
- **Retention**: Same as log files (default: 7 days)

### Environment Variables
```bash
# Trace file location (optional)
DOCKER_OPS_TRACE_FILE="/custom/path/trace.log"

# Log directory (used for trace file if not specified)
DOCKER_OPS_LOG_DIR="~/.config/docker-ops-manager"
```

## Usage

### Enable Tracing
```bash
# Enable tracing for a command
./docker_ops_manager.sh generate --yaml ./examples/nginx-app.yml --trace

# Enable tracing for multiple commands
./docker_ops_manager.sh generate --yaml ./examples/nginx-app.yml --trace
./docker_ops_manager.sh status --trace
./docker_ops_manager.sh cleanup --all --trace
```

### View Trace File
```bash
# View entire trace file
cat ~/.config/docker-ops-manager/logs/docker_ops_trace.log

# View recent traces
tail -50 ~/.config/docker-ops-manager/logs/docker_ops_trace.log

# Search for specific operations
grep "generate_from_yaml" ~/.config/docker-ops-manager/logs/docker_ops_trace.log

# View traces from specific time
grep "2025-01-18 14:30" ~/.config/docker-ops-manager/logs/docker_ops_trace.log
```

### Monitor File Size
```bash
# Check trace file size
ls -lh ~/.config/docker-ops-manager/logs/docker_ops_trace.log

# Check for rotated files
ls -lh ~/.config/docker-ops-manager/logs/docker_ops_trace.log.*
```

## Migration from Old Approach

### Automatic Migration
- Old timestamped trace files are automatically cleaned up
- New single trace file is created automatically
- No manual migration required

### Manual Cleanup (Optional)
```bash
# Remove old timestamped trace files
rm ~/.config/docker-ops-manager/logs/docker_ops_trace_*.log

# Keep only the new single trace file
ls ~/.config/docker-ops-manager/logs/docker_ops_trace.log
```

## Testing

### Test Script
A test script is provided to verify the single trace file approach:

```bash
# Run the test
./test-trace-file.sh

# This will:
# 1. Clean up existing trace files
# 2. Run multiple operations with tracing
# 3. Verify single file is maintained
# 4. Show file statistics and sample entries
```

### Manual Testing
```bash
# Test multiple sessions
./docker_ops_manager.sh generate --yaml ./examples/nginx-app.yml --trace
./docker_ops_manager.sh status --trace
./docker_ops_manager.sh cleanup --all --trace

# Verify single file
ls -la ~/.config/docker-ops-manager/logs/docker_ops_trace.log*
```

## Troubleshooting

### File Not Created
- Check if tracing is enabled (`--trace` flag)
- Verify log directory exists and is writable
- Check permissions on log directory

### File Too Large
- Automatic rotation should handle this
- Manual rotation: `mv docker_ops_trace.log docker_ops_trace.log.backup`
- Check for old rotated files that need cleanup

### No Timestamps
- Ensure system has proper date/time
- Check if `date` command works correctly
- Verify timestamp format in trace entries

### Performance Issues
- Large trace files may impact performance
- Consider reducing trace verbosity
- Use log rotation to manage file size

## Future Enhancements

1. **Compression**: Automatic compression of old trace files
2. **Filtering**: Command-line options to filter trace output
3. **Real-time Monitoring**: Live trace file monitoring
4. **Integration**: Better integration with logging system
5. **Customization**: More configurable trace formats and levels 