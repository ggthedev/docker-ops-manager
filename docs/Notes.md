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

---

# Animation Display Issue Fix

## Problem Statement
During container generation, extraneous characters (specifically "i") were appearing in the output after progress animations. The issue manifested as:

```
...ℹ Waiting for container 'nginx-app-container' to be ready (timeout: 60s)
```

Where the dots (`...`) from the animation were not being properly cleared before the next message was printed, causing visual artifacts.

## Root Cause Analysis
The issue was caused by race conditions in the animation system:

1. **Line Clearing Logic**: The `printf "\r%*s\r"` commands were using dynamic width calculations that weren't working correctly
2. **Timing Issues**: There was insufficient delay between stopping animations and printing the next message
3. **Animation State**: The signal-based animation system wasn't properly clearing the terminal line before new content was displayed

## Solution Approach

### 1. Fixed Line Clearing Logic
**Problem**: Dynamic width calculations in `printf "\r%*s\r" $((dots_count + 1)) ""` were unreliable
**Solution**: Changed to fixed width of 80 characters: `printf "\r%*s\r" 80 ""`

**Files Modified**:
- `lib/utils.sh`: Updated all animation functions to use consistent line clearing

### 2. Added Explicit Line Clearing
**Problem**: Race conditions between animation stopping and next message printing
**Solution**: Added explicit line clearing before showing waiting messages

**Files Modified**:
- `lib/container_ops.sh`: Added `printf "\r%*s\r" 80 ""` before `print_info` calls

### 3. Added Timing Delays
**Problem**: Insufficient time for animations to fully clear
**Solution**: Added small delays (`sleep 0.1`) after stopping animations

**Files Modified**:
- `lib/container_ops.sh`: Added delays after `stop_signal_animation` calls
- `lib/utils.sh`: Enhanced `stop_signal_animation` with additional line clearing

### 4. Enhanced Animation Cleanup
**Problem**: Animation processes weren't properly cleaning up terminal state
**Solution**: Added explicit line clearing in animation cleanup functions

## Implementation Details

### Key Changes Made

1. **Consistent Line Clearing**:
   ```bash
   # Before (problematic)
   printf "\r%*s\r" $((dots_count + 1)) ""
   
   # After (fixed)
   printf "\r%*s\r" 80 ""
   ```

2. **Explicit Pre-Message Clearing**:
   ```bash
   # Ensure any previous animation is fully cleared
   printf "\r%*s\r" 80 ""
   print_info "Waiting for container '$container_name' to be ready..."
   ```

3. **Animation Stop Delays**:
   ```bash
   stop_signal_animation
   # Small delay to ensure animation is fully cleared
   sleep 0.1
   ```

4. **Enhanced Cleanup**:
   ```bash
   # Ensure line is cleared after animation stops
   printf "\r%*s\r" 80 ""
   ```

## Testing Results

**Before Fix**:
```
...ℹ Waiting for container 'nginx-app-container' to be ready (timeout: 60s)
```

**After Fix**:
```
ℹ Waiting for container 'nginx-app-container' to be ready (timeout: 60s)
```

## Lessons Learned

1. **Terminal Animation Timing**: Even small race conditions can cause visual artifacts
2. **Line Clearing Consistency**: Using fixed widths is more reliable than dynamic calculations
3. **Animation State Management**: Proper cleanup is essential for multi-step processes
4. **User Experience**: Clean output is crucial for professional tool appearance

## Future Considerations

- Consider implementing a more robust animation system with better state management
- Add animation debugging capabilities for troubleshooting similar issues
- Consider using a dedicated terminal library for complex animations
- Implement animation queuing to prevent overlapping animations 