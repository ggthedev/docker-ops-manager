# Getopts Argument Parsing Implementation

## Overview

The Docker Ops Manager has been refactored to use `getopts` for robust command line argument parsing. This provides better error handling, support for combined short options, and more maintainable code.

## Implementation Details

### Two-Pass Approach

The argument parsing uses a two-pass approach:

1. **First Pass**: Handle long options (--option) and help/version
2. **Second Pass**: Use `getopts` for short options (-o)

### Short Options String

```bash
local shortopts="hvgirxstcnualCefy:o:d:T"
```

**Format**: `"option:value"` where `:` means the option requires a value

### Option Mappings

#### Operations
- `-g` / `--generate` - Generate containers from YAML
- `-i` / `--install` - Install/update containers
- `-r` / `--reinstall` - Reinstall containers
- `-s` / `--start` - Start containers
- `-x` / `--stop` - Stop containers
- `-t` / `--restart` - Restart containers
- `-c` / `--cleanup` - Cleanup containers
- `-n` / `--nuke` - Nuke Docker system
- `-u` / `--status` - Show container status
- `-l` / `--logs` - Show container logs
- `-a` / `--list` - List Docker resources
- `-C` / `--config` - Show configuration
- `-e` / `--state` - Show state summary
- `--env` - Show environment variables

#### Global Options
- `-h` / `--help` - Show help
- `-v` / `--version` - Show version
- `-f` / `--force` - Force operation
- `-y` / `--yaml` - Specify YAML file (requires value)
- `-o` / `--timeout` - Operation timeout (requires value)
- `-d` / `--log-level` - Set log level (requires value)
- `-T` / `--trace` - Enable tracing

## Features

### Combined Short Options

You can combine multiple short options:

```bash
# Cleanup with force
./docker_mgr.sh -cf container-name

# Generate with multiple options
./docker_mgr.sh -g -y file.yml -o 30 -f
```

### Mixed Short and Long Options

You can mix short and long options:

```bash
# Short operation with long options
./docker_mgr.sh -g --yaml file.yml --timeout 30

# Long operation with short options
./docker_mgr.sh --cleanup -f container-name
```

### Error Handling

- Invalid short options: `Invalid option: -unknown`
- Missing arguments: `Option -unknown requires an argument`
- Invalid long options: `Unknown long option: --invalid`

### Positional Arguments

Positional arguments are handled after option parsing:

```bash
# Operation as positional argument
./docker_mgr.sh list containers

# Container names as positional arguments
./docker_mgr.sh -f cleanup container1 container2
```

## Usage Examples

### Basic Operations
```bash
# Short options
./docker_mgr.sh -h                    # Help
./docker_mgr.sh -v                    # Version
./docker_mgr.sh -a containers         # List containers
./docker_mgr.sh -C                    # Show config
./docker_mgr.sh -e                    # Show state
```

### Container Operations
```bash
# Generate with options
./docker_mgr.sh -g -y docker-compose.yml -o 30 -f

# Cleanup with force
./docker_mgr.sh -cf container-name

# Status with timeout
./docker_mgr.sh -u -o 15 container-name
```

### Mixed Format
```bash
# Short operation, long options
./docker_mgr.sh -g --yaml file.yml --timeout 30

# Long operation, short options
./docker_mgr.sh --cleanup -f container-name

# Mixed global options
./docker_mgr.sh -g --yaml file.yml -o 30 -f
```

## Benefits

1. **Standard Compliance**: Uses POSIX-standard `getopts`
2. **Combined Options**: Support for `-cf` instead of `-c -f`
3. **Better Error Handling**: Clear error messages for invalid options
4. **Maintainable**: Cleaner, more organized code
5. **Flexible**: Supports both short and long options
6. **Robust**: Handles edge cases and missing arguments

## Migration Notes

The implementation maintains backward compatibility:
- All existing long options continue to work
- All existing short options continue to work
- New combined short options are available
- Error messages are improved

## Testing

Comprehensive tests are available in `tests/test_getopts.sh` that verify:
- Basic short options
- Operation short options
- Global short options
- Combined short options
- Long options
- Mixed options
- Error handling
- Positional arguments 