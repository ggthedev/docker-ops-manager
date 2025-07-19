# Traefik & Web-App Troubleshooting Notes

## 1. Problem Statement
- Traefik container repeatedly unhealthy; health check timeouts.
- Web-app service returns 504 Gateway Timeout or 404 when accessed via Traefik.
- API service routing works, but web-app does not.

## 2. Troubleshooting Steps & Findings

### Health Check Issues
- Traefik's health check was configured to check endpoints that return 404 (not 200), causing the container to remain unhealthy.
- Health check endpoints tried: `/`, `/api/overview`, `/api/rawdata`, `/api`, all returned 404.
- Solution: Health check should target a valid endpoint that returns 200, or be disabled for Traefik if not needed.

### Web-App Routing Issues
- Web-app container was running and healthy, but Traefik returned 504 Gateway Timeout or 404.
- Traefik logs showed: `Defaulting to first available network ... for container "/web-app".`
- Root cause: Traefik could not reach the web-app on the correct network due to Docker Compose limitations with external networks.
- Manual fix: Start web-app with only the `traefik` network attached using:
  ```sh
  docker run -d --name web-app --network traefik -v /path/to/html:/usr/share/nginx/html nginx:alpine
  ```
- After this, Traefik could reach the container, but still returned 404 for `/`.

### Traefik Dashboard & API
- Dashboard and API endpoints (e.g., `/dashboard/`, `/api/rawdata`) returned 404.
- Traefik config had `api.dashboard: true` and `api.insecure: true`, but dashboard was not accessible.
- Possible cause: Traefik v2.x dashboard path or config mismatch.

## 3. Next Actions
- Inspect Traefik's discovered routers and services to confirm if the web-app router is created and matches the expected rule.
- Double-check web-app container labels for correct router rule and entrypoint.
- Consider disabling or relaxing the health check for Traefik if not strictly needed.
- Review Traefik documentation for dashboard/API exposure in v2.x.

---

**Summary:**
- API service routing works, web-app routing does not (returns 404).
- Traefik is running and can reach containers on the `traefik` network.
- Health check failures are due to invalid endpoint selection.
- Dashboard/API not accessible, likely due to config or version specifics.

---

# Generate vs Install Operations

## Overview
Understanding the key differences between `generate` and `install` operations in Docker Ops Manager.

## Generate Operation

**Purpose**: Creates containers from YAML files for the first time

**What it does**:
1. **Reads YAML files** (docker-compose.yml, custom YAML, etc.)
2. **Extracts container configuration** from the YAML
3. **Creates containers** using Docker commands
4. **Stores metadata** in the state file for future reference

**Usage**:
```bash
./docker-manager.sh generate docker-compose.yml
./docker-manager.sh generate app.yml my-container
```

**Key characteristics**:
- **Source**: YAML files
- **First-time creation**: Creates containers that don't exist yet
- **Configuration**: Uses the YAML file as the source of truth
- **State tracking**: Records the YAML file path and container info in state

## Install Operation

**Purpose**: Recreates containers from previously stored configurations

**What it does**:
1. **Retrieves stored information** from the state file
2. **Finds the original YAML file** that was used to create the container
3. **Recreates the container** using the same YAML configuration
4. **Updates state** with new container information

**Usage**:
```bash
./docker-manager.sh install my-container
./docker-manager.sh install nginx-app web-app
```

**Key characteristics**:
- **Source**: State file (which references the original YAML)
- **Recreation**: Recreates containers that were previously generated
- **Dependency**: Requires the container to have been generated before
- **State lookup**: Uses stored metadata to find the original configuration

## Key Differences Summary

| Aspect | Generate | Install |
|--------|----------|---------|
| **Input** | YAML file | Container name |
| **Purpose** | First-time creation | Recreation from state |
| **Dependency** | None (creates new) | Requires previous generation |
| **State** | Creates state entry | Reads existing state |
| **Use case** | New container setup | Container recovery/rebuild |

## Workflow Example

```bash
# Step 1: Generate container from YAML (first time)
./docker-manager.sh generate docker-compose.yml web-app

# Step 2: Later, if you need to recreate the container
./docker-manager.sh install web-app

# Step 3: Or if you want to update/reinstall
./docker-manager.sh update web-app
```

## With --no-start Flag

Both operations now support the `--no-start` flag:

```bash
# Generate without starting
./docker-manager.sh generate docker-compose.yml --no-start

# Install without starting  
./docker-manager.sh install web-app --no-start
```

## Error Scenarios

**Generate fails when**:
- YAML file doesn't exist
- YAML syntax is invalid
- Container already exists (unless --force is used)

**Install fails when**:
- Container was never generated before
- State file is missing or corrupted
- Original YAML file no longer exists

## Implementation Notes

- **Generate**: Uses `generate_from_yaml()` function that processes YAML files directly
- **Install**: Uses `install_container()` function that calls `generate_from_yaml()` with stored YAML path
- **State Management**: Both operations update the state file with container metadata
- **--no-start Flag**: Both operations respect the flag to create containers without starting them 