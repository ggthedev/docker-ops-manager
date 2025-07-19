# Container Readiness Timeout Logic

## Overview

Docker Ops Manager supports a robust, configurable readiness timeout for containers. This ensures containers are only considered 'ready' when they are healthy (if a healthcheck is defined) or running (if not). The timeout is determined by a clear hierarchy, allowing for per-container, CLI, environment, or default values.

---

## Timeout Hierarchy

Timeout for readiness is determined in the following order:

1. **Per-container override** (YAML: `x-docker-ops.readiness_timeout`)
2. **CLI flag** (`--timeout`)
3. **Config file or environment variable** (`DOCKER_OPS_READINESS_TIMEOUT`)
4. **Hardcoded default** (60 seconds)

---

## How It Works

- If a container defines a healthcheck, readiness waits for the health status to become `healthy`.
- If no healthcheck is defined, readiness waits for the container to be in the `running` state.
- The timeout is checked every second until the container is ready or the timeout is reached.
- **Health Check Handling**: The system gracefully handles containers without health checks by detecting template parsing errors and treating them as containers without health checks.

---

## YAML Example (Per-Container Timeout)

```yaml
services:
  db:
    image: postgres:13-alpine
    container_name: simple-db
    x-docker-ops:
      readiness_timeout: 90  # seconds
```

---

## CLI Example (Override Timeout)

```sh
./docker_ops_manager.sh generate --timeout 120 examples/simple-app.yml db
```

---

## Environment Variable Example

```sh
export DOCKER_OPS_READINESS_TIMEOUT=120
./docker_ops_manager.sh generate examples/simple-app.yml db
```

---

## Implementation Summary

- The `wait_for_container_ready` function in `lib/container_ops.sh` implements this logic.
- It uses a helper (`get_container_readiness_timeout`) to extract per-container values from YAML.
- **Health Check Detection**: The system tests if a container has health checks before attempting to read the health status, preventing template parsing errors.
- All logic is exhaustively documented in the code for future maintainers and knowledge base generation.

---

## Design Rationale

- **Flexibility:** Supports a wide range of container startup times.
- **Transparency:** All config options are documented and discoverable.
- **Robustness:** Handles containers with and without health checks gracefully.
- **Animation Integration:** Uses signal-based animation control for smooth user experience during wait operations. 