# Docker Ops Manager

A comprehensive, modular Docker operations management tool designed for ease of use, maintainability, and extensibility.

**Based on Docker Ops Manager by Gaurav Gupta (https://github.com/gauravgupta/docker-ops-manager)**  
**Licensed under MIT License with Attribution Requirement**  
**Copyright (c) 2024 Gaurav Gupta**

## Features

- **Modular Design**: Clean separation of concerns with dedicated modules for each operation
- **Multi-Container Support**: Handle multiple containers and YAML files in a single command
- **YAML Support**: Generate containers from docker-compose.yml, docker-stack.yml, or custom YAML files
- **State Management**: Track container history, operations, and configuration
- **Comprehensive Logging**: Detailed logging with rotation and multiple log levels
- **Container Lifecycle**: Full support for install, start, stop, restart, and cleanup operations
- **Enhanced Cleanup**: Multiple cleanup options including state-managed, system-wide, and nuke operations
- **Resource Listing**: List containers, images, projects, volumes, and networks with various formats
- **Configuration Management**: Environment-driven configuration with sensible defaults
- **Error Handling**: Robust error handling and validation throughout
- **Tracing Support**: Detailed method tracing for debugging complex operations

## Architecture

The Docker Ops Manager follows a modular design pattern with the following structure:

```
docker-ops-manager/
├── docker_mgr.sh          # Main entry point
├── lib/                           # Core library modules
│   ├── config.sh                  # Configuration management
│   ├── logging.sh                 # Logging system
│   ├── state.sh                   # State management
│   ├── yaml_parser.sh             # YAML file processing
│   ├── container_ops.sh           # Container operations
│   ├── tracing.sh                 # Method tracing for debugging
│   └── utils.sh                   # Utility functions
├── operations/                    # Operation modules
│   ├── generate.sh                # Generate from YAML
│   ├── install.sh                 # Install/reinstall containers
│   ├── cleanup.sh                 # Cleanup operations
│   ├── start.sh                   # Start/run containers
│   ├── stop.sh                    # Stop containers
│   ├── status.sh                  # Status operations
│   ├── logs.sh                    # Log viewing
│   └── list.sh                    # Resource listing
└── config/                        # Configuration files
    └── default.conf               # Default configuration
```

## Installation

1. Clone or download the project
2. Make the main script executable:
   ```bash
   chmod +x docker_mgr.sh
   ```
3. Ensure you have the required dependencies:
   - Docker
   - jq (for JSON processing)
   - yq (optional, for better YAML parsing)

## Usage

### Basic Syntax

```bash
./docker_mgr.sh [OPERATION] [OPTIONS] [CONTAINER_NAME] [CONTAINER2...]
```

### Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `generate <yaml_file> [yaml_file2...] [container_name]` | Generate containers from YAML | `./docker_mgr.sh generate docker-compose.yml my-app` |
| `install [container_name] [container2...]` | Install/update containers | `./docker_mgr.sh install my-app` |
| `reinstall [container_name] [container2...]` | Reinstall containers | `./docker_mgr.sh reinstall my-app` |
| `start\|run [container_name] [container2...]` | Start containers | `./docker_mgr.sh start my-app` |
| `stop [container_name] [container2...]` | Stop containers | `./docker_mgr.sh stop my-app` |
| `restart [container_name] [container2...]` | Restart containers | `./docker_mgr.sh restart my-app` |
| `cleanup [container_name] [container2...] [--all]` | Remove specific containers or all state-managed containers | `./docker_mgr.sh cleanup --all` |
| `cleanup all` | Remove ALL containers, images, volumes, networks (DANGER) | `./docker_mgr.sh cleanup all` |
| `nuke` | Interactive nuke with confirmation prompt | `./docker_mgr.sh nuke` |
| `status [container_name] [container2...]` | Show container status | `./docker_mgr.sh status my-app` |
| `logs [container_name] [container2...]` | Show container logs | `./docker_mgr.sh logs my-app` |
| `list [resource_type]` | List Docker resources | `./docker_mgr.sh list containers` |
| `config` | Show configuration | `./docker_mgr.sh config` |
| `state` | Show state summary | `./docker_mgr.sh state` |
| `env` | Show environment variables and directory locations | `./docker_mgr.sh env` |
| `help` | Show help | `./docker_mgr.sh help` |

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--yaml <file>` | Specify YAML file | `--yaml docker-compose.yml` |
| `--force` | Force operation | `--force` |
| `--timeout <seconds>` | Operation timeout | `--timeout 120` |
| `--log-level <level>` | Set log level | `--log-level DEBUG` |
| `--trace` | Enable detailed method tracing for debugging | `--trace` |

### Examples

#### Generate containers from YAML
```bash
# Generate from single YAML file
./docker_mgr.sh generate docker-compose.yml

# Generate from multiple YAML files
./docker_mgr.sh generate app1.yml app2.yml app3.yml

# Generate specific container from YAML
./docker_mgr.sh generate docker-compose.yml web-server

# Generate with custom options
./docker_mgr.sh generate docker-compose.yml --force --timeout 300
```

#### Multi-container operations
```bash
# Start multiple containers
./docker_mgr.sh start nginx-app web-app db-app

# Stop multiple containers
./docker_mgr.sh stop nginx-app web-app

# Install multiple containers
./docker_mgr.sh install nginx-app web-app db-app

# Show status of multiple containers
./docker_mgr.sh status nginx-app web-app db-app

# Show logs of multiple containers
./docker_mgr.sh logs nginx-app web-app
```

#### Start/Stop containers
```bash
# Start last container
./docker_mgr.sh start

# Start specific container
./docker_mgr.sh start my-app

# Stop container
./docker_mgr.sh stop my-app

# Restart container
./docker_mgr.sh restart my-app
```

#### Container management
```bash
# Install container
./docker_mgr.sh install my-app

# Reinstall container
./docker_mgr.sh reinstall my-app

# Show container status
./docker_mgr.sh status my-app

# Show container logs
./docker_mgr.sh logs my-app
```

#### Enhanced cleanup operations
```bash
# Cleanup specific container
./docker_mgr.sh cleanup my-app

# Cleanup multiple containers
./docker_mgr.sh cleanup nginx-app web-app db-app

# Cleanup all state-managed containers only
./docker_mgr.sh cleanup --all

# Cleanup ALL containers, images, volumes, networks (DANGER)
./docker_mgr.sh cleanup all

# Interactive nuke with confirmation prompt
./docker_mgr.sh nuke

# Force nuke without confirmation
./docker_mgr.sh nuke --force
```

#### Resource listing
```bash
# List all resources
./docker_mgr.sh list

# List specific resource types
./docker_mgr.sh list containers
./docker_mgr.sh list images
./docker_mgr.sh list projects
./docker_mgr.sh list volumes
./docker_mgr.sh list networks

# List with different formats
./docker_mgr.sh list containers --format json
./docker_mgr.sh list images --format custom
```

#### Information and debugging
```bash
# List all managed containers
./docker_mgr.sh list

# Show configuration
./docker_mgr.sh config

# Show state information
./docker_mgr.sh state

# Show environment information
./docker_mgr.sh env

# Show help
./docker_mgr.sh help

# Enable tracing for debugging
./docker_mgr.sh --trace start my-app
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_OPS_CONFIG_DIR` | Configuration directory | `~/.config/docker-ops-manager` |
| `DOCKER_OPS_LOG_DIR` | Log directory | `~/.config/docker-ops-manager/logs` |
| `DOCKER_OPS_LOG_LEVEL` | Log level (DEBUG, INFO, WARN, ERROR) | `INFO` |
| `DOCKER_OPS_STATE_FILE` | State file path | `~/.config/docker-ops-manager/state.json` |
| `DOCKER_OPS_CONFIG_FILE` | Config file path | `~/.config/docker-ops-manager/config.json` |
| `DOCKER_OPS_MAX_CONTAINER_HISTORY` | Max container history | `10` |
| `DOCKER_OPS_PROJECT_NAME_PATTERN` | Project name pattern for auto-generation | `{name}-{date}` |

### Configuration File

The configuration file is automatically created at `~/.config/docker-ops-manager/config.json`:

```json
{
    "log_level": "INFO",
    "log_rotation_days": 7,
    "max_container_history": 10,
    "docker_compose_timeout": 300,
    "container_start_timeout": 60,
    "container_stop_timeout": 30,
    "project_name_pattern": "{name}-{date}"
}
```

## State Management

The Docker Ops Manager maintains state information in `~/.config/docker-ops-manager/state.json`:

```json
{
    "config": {
        "log_level": "INFO",
        "log_rotation_days": 7,
        "max_container_history": 10
    },
    "state": {
        "last_container": "my-app",
        "last_operation": "start",
        "last_yaml_file": "/path/to/docker-compose.yml",
        "container_history": ["my-app", "web-server", "db"],
        "operations": {
            "my-app": {
                "last_operation": "start",
                "last_operation_time": "2024-01-15T10:30:00Z",
                "yaml_source": "/path/to/docker-compose.yml",
                "container_id": "abc123",
                "status": "running"
            }
        }
    }
}
```

## Logging

Logs are stored in `~/.config/docker-ops-manager/logs/` with the following format:

```
[2024-01-15 10:30:15] [INFO] [GENERATE] [my-app] - Generating container from /path/to/docker-compose.yml
[2024-01-15 10:30:20] [INFO] [GENERATE] [my-app] - Container created successfully
[2024-01-15 10:30:21] [INFO] [START] [my-app] - Starting container my-app
[2024-01-15 10:30:25] [INFO] [START] [my-app] - Container started successfully
```

### Log Levels

- **DEBUG**: Detailed debugging information
- **INFO**: General information about operations
- **WARN**: Warning messages
- **ERROR**: Error messages

### Tracing

Enable detailed method tracing for debugging complex operations:

```bash
./docker_mgr.sh --trace start my-app
```

Tracing provides detailed information about function calls, parameters, and execution flow.

## YAML Support

The Docker Ops Manager supports various YAML file types:

### Docker Compose
```yaml
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
```

### Docker Stack
```yaml
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
networks:
  default:
    driver: overlay
```

### Custom YAML
```yaml
containers:
  my-app:
    image: my-app:latest
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=production
```

## Multi-Container Operations

The Docker Ops Manager supports operations on multiple containers simultaneously:

### Multiple Container Support
- **Generate**: Process multiple YAML files in sequence
- **Start/Stop**: Start or stop multiple containers
- **Install/Reinstall**: Install or reinstall multiple containers
- **Status/Logs**: Show status or logs for multiple containers
- **Cleanup**: Remove multiple containers

### Multiple YAML File Support
- Process multiple YAML files in a single command
- Automatic container name extraction from each YAML file
- Summary reporting for batch operations

## Enhanced Cleanup Operations

### Cleanup Options
1. **Specific Container**: `cleanup container-name`
2. **Multiple Containers**: `cleanup container1 container2 container3`
3. **State-Managed Only**: `cleanup --all` (removes only containers tracked in state)
4. **System-Wide**: `cleanup all` (removes ALL containers, images, volumes, networks)
5. **Interactive Nuke**: `nuke` (confirmation prompt before removing everything)

### Cleanup Features
- **Retry Logic**: Multiple attempts for container removal
- **Verification**: Ensures complete cleanup
- **State Synchronization**: Updates state file after cleanup
- **Force Options**: Bypass confirmation prompts
- **Comprehensive Reporting**: Detailed cleanup summaries

## Resource Listing

### Available Resource Types
- **containers**: Docker containers (running and stopped)
- **images**: Docker images
- **projects**: Docker Compose projects
- **volumes**: Docker volumes
- **networks**: Docker networks
- **all**: All resource types

### Output Formats
- **table**: Formatted table output (default)
- **json**: JSON format for programmatic use
- **custom**: Custom formatted output

## Environment Information

The `env` command provides comprehensive information about the Docker Ops Manager environment:

### What it shows:
- **Directory Locations**: Configuration, logs, state file, config file, and temp directory paths
- **Environment Variables**: All Docker Ops Manager environment variables with their current values
- **Current Values**: Resolved values including defaults for unset variables
- **Directory Status**: Whether directories exist (✓) or don't exist (✗)
- **File Status**: Whether key files exist (✓) or don't exist (✗)

### Example output:
```bash
./docker_mgr.sh env
```

This command is useful for:
- Debugging configuration issues
- Understanding where files are stored
- Verifying environment variable settings
- Checking if required directories and files exist

## Error Handling

The Docker Ops Manager includes comprehensive error handling:

- **Validation**: Input validation for all operations
- **Dependency Checks**: Verification of required tools (Docker, jq)
- **Graceful Degradation**: Fallback mechanisms when optional tools are missing
- **Detailed Error Messages**: Clear error messages with suggestions
- **Logging**: All errors are logged with context
- **Retry Logic**: Automatic retry for transient failures
- **State Recovery**: Automatic state synchronization after errors

## Extensibility

The modular design makes it easy to extend the Docker Ops Manager:

### Adding New Operations

1. Create a new operation module in `operations/`
2. Add the operation to the main script's operation handlers
3. Update the help text and validation

### Adding New Features

1. Extend the appropriate library module in `lib/`
2. Update the main script to use the new functionality
3. Add configuration options if needed

## Troubleshooting

### Common Issues

1. **Docker not running**: Ensure Docker daemon is running
2. **Permission denied**: Check Docker group membership
3. **jq not found**: Install jq for JSON processing
4. **YAML parsing errors**: Validate YAML syntax
5. **Port conflicts**: Use different ports or stop conflicting containers
6. **State inconsistencies**: Use `cleanup --all` to reset state

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
./docker_mgr.sh --log-level DEBUG [operation]
```

### Tracing Mode

Enable detailed method tracing for complex debugging:

```bash
./docker_mgr.sh --trace [operation]
```

### State Recovery

If the state file becomes corrupted:

```bash
# Backup current state
cp ~/.config/docker-ops-manager/state.json ~/.config/docker-ops-manager/state.json.backup

# Remove state file to reset
rm ~/.config/docker-ops-manager/state.json
```

## Contributing

1. Follow the existing code structure and patterns
2. Add appropriate logging and error handling
3. Update documentation for new features
4. Test thoroughly before submitting

## License

This project is open source and available under the **MIT License with Attribution Requirement**.

### License Terms

This software is licensed under the MIT License with an additional attribution requirement. You are free to:

- Use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software
- Use the Software for commercial purposes

**However, you must prominently display the following attribution in all distributions, modifications, or derivative works:**

```
Based on Docker Ops Manager by Gaurav Gupta (https://github.com/ggthedev/docker-ops-manager)
```

### Attribution Requirements

The attribution must be included in:
- All source code files that are modified or derived from this Software
- Documentation files
- User interfaces or command-line help text
- README files or project descriptions
- Any other materials that describe or present the Software

### Commercial Use

If you use this Software in a commercial product or service, you must:
- Include the attribution requirement in your product documentation
- Provide a link to the original project in your product's about section
- Notify users of the original authorship in any relevant user interfaces

For the complete license text, see the [LICENSE](LICENSE) file.

### Contact

For questions about this license or attribution requirements, please contact:
Gaurav Gupta - gauravgupta@example.com

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs for error details
3. Enable debug mode for more information
4. Create an issue with detailed information

## - Gaurav Gupta
## - Cursor AI
