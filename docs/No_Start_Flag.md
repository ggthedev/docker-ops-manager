# --no-start Flag Documentation

## Overview

The `--no-start` flag is a new feature in Docker Ops Manager that allows you to create containers without automatically starting them. This is useful for scenarios where you want to:

- Create containers in a stopped state for later manual startup
- Prepare containers for batch operations
- Create containers without consuming resources immediately
- Set up containers for testing or development environments

## Usage

### Basic Syntax

```bash
# Generate container without starting it
./docker-manager.sh generate <yaml_file> --no-start

# Install container without starting it
./docker-manager.sh install <container_name> --no-start
```

### Examples

```bash
# Create a web application container without starting it
./docker-manager.sh generate docker-compose.yml web-app --no-start

# Install a previously generated container without starting it
./docker-manager.sh install web-app --no-start

# Create multiple containers without starting them
./docker-manager.sh generate docker-compose.yml --no-start
```

## Behavior

### With --no-start flag

When the `--no-start` flag is used:

1. **Container Creation**: The container is created using the appropriate Docker command
   - For Docker Compose: Uses `docker-compose create` instead of `docker-compose up -d`
   - For Custom YAML: Uses `docker create` instead of `docker run -d`

2. **Container Status**: The container is created but remains in "Created" state (not running)

3. **State Management**: The container is recorded in the state file with status "created"

4. **Success Message**: Displays "Container 'name' created successfully (not started)"

5. **No Health Checks**: No readiness checks are performed since the container is not running

### Without --no-start flag (Default Behavior)

When the `--no-start` flag is not used:

1. **Container Creation**: The container is created and started immediately
   - For Docker Compose: Uses `docker-compose up -d`
   - For Custom YAML: Uses `docker run -d`

2. **Container Status**: The container is created and started, running in the background

3. **State Management**: The container is recorded in the state file with status "running"

4. **Success Message**: Displays "Container 'name' generated and started successfully"

5. **Health Checks**: Readiness checks are performed to ensure the container is healthy

## Supported Operations

The `--no-start` flag is currently supported for:

- **generate**: Create containers from YAML files
- **install**: Install containers from stored configurations

### Not Supported

The `--no-start` flag is not applicable to:

- **start/run**: These operations are specifically for starting containers
- **stop**: These operations are for stopping running containers
- **restart**: These operations require containers to be running
- **status**: These operations check container status
- **logs**: These operations require containers to be running
- **cleanup**: These operations remove containers

## Implementation Details

### Docker Compose Support

For Docker Compose YAML files, the implementation:

1. Creates a temporary compose file with the specific service
2. Uses `docker-compose create` instead of `docker-compose up -d`
3. Cleans up the temporary file after creation
4. Updates state with "created" status

### Custom YAML Support

For custom YAML files, the implementation:

1. Generates a `docker create` command instead of `docker run -d`
2. Maintains all port mappings, environment variables, and volume mounts
3. Creates the container without starting it
4. Updates state with "created" status

### State Management

The state file tracks the container status:

```json
{
  "container_name": {
    "status": "created",
    "last_operation": "GENERATE",
    "yaml_source": "/path/to/yaml/file",
    "container_id": "abc123..."
  }
}
```

## Use Cases

### Development Workflow

```bash
# Create containers for development without starting them
./docker-manager.sh generate dev-compose.yml --no-start

# Start containers when ready to work
./docker-manager.sh start

# Stop containers when done
./docker-manager.sh stop
```

### Batch Operations

```bash
# Create multiple containers without starting them
for yaml in *.yml; do
  ./docker-manager.sh generate "$yaml" --no-start
done

# Start all containers at once
./docker-manager.sh start
```

### Testing Scenarios

```bash
# Create test containers without starting them
./docker-manager.sh generate test-compose.yml --no-start

# Start containers for testing
./docker-manager.sh start

# Run tests
# ...

# Stop containers after testing
./docker-manager.sh stop
```

## Future Enhancements

### Planned Features

1. **Health Check Command**: A dedicated command for running health checks on stopped containers
2. **Batch Health Checks**: Health check all containers at once
3. **Conditional Starting**: Start containers only if they pass health checks
4. **Startup Dependencies**: Handle container startup order and dependencies

### Example Future Commands

```bash
# Health check a specific container
./docker-manager.sh health-check <container_name>

# Health check all containers
./docker-manager.sh health-check --all

# Start containers only if they pass health checks
./docker-manager.sh start --health-check
```

## Troubleshooting

### Common Issues

1. **Container Already Running**: If a container is already running, the `--no-start` flag won't affect it
2. **Port Conflicts**: Port conflicts are still checked during container creation
3. **Resource Constraints**: Resource limits are still enforced during creation

### Error Messages

- **"Container created successfully (not started)"**: Normal success message when using `--no-start`
- **"Container generated and started successfully"**: Normal success message when not using `--no-start`

### Debugging

To debug issues with the `--no-start` flag:

```bash
# Enable debug logging
./docker-manager.sh generate <yaml_file> --no-start --log-level DEBUG

# Check container status
docker ps -a | grep <container_name>

# Check container logs (if started manually)
./docker-manager.sh logs <container_name>
```

## Migration Guide

### From Previous Versions

If you're upgrading from a previous version:

1. **No Breaking Changes**: The `--no-start` flag is additive and doesn't change existing behavior
2. **Default Behavior**: Existing scripts continue to work as before
3. **Optional Feature**: The flag is optional and only used when explicitly specified

### Script Updates

Update your scripts to use the new flag where appropriate:

```bash
# Old behavior (still works)
./docker-manager.sh generate docker-compose.yml

# New behavior with --no-start
./docker-manager.sh generate docker-compose.yml --no-start
```

## Conclusion

The `--no-start` flag provides greater control over container lifecycle management, allowing users to separate container creation from container startup. This feature is particularly useful for development workflows, testing scenarios, and batch operations where you want to prepare containers without immediately consuming resources. 