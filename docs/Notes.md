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