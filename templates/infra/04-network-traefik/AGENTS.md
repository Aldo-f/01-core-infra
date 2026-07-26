# AGENTS.md — 04-network-traefik

## Overview

Traefik reverse proxy for the home network. Routes external HTTPS traffic to internal Docker services.

## Domain Configuration

| Domain | Service | Notes |
|---|---|---|
| `freellm.aldof.duckdns.org` | FreeLLM API (`http://freellmapi:3001`) | Primary LLM API endpoint |
| `thuis.aldof.duckdns.org` | Thuis v5 app | Home dashboard |

**DuckDNS Token:** `53c4be1e-7eb7-4d46-8c6c-6e9cde44a037`
**DuckDNS Domain:** `aldof.duckdns.org`

## DNS Update (Cron)

Cron job updates DuckDNS IP every 5 minutes:
```
*/5 * * * * curl -s "https://www.duckdns.org/update?token=53c4be1e-7eb7-4d46-8c6c-6e9cde44a037&domains=aldof.duckdns.org" > /dev/null 2>&1
```

## Architecture

```
Internet → :443 (Traefik) → freellmapi:3001 (Docker, traefik_net)
                        → thuis (Docker, traefik_net)
```

- **TLS:** Let's Encrypt via HTTP-01 challenge (email: `aldof@duckdns.org`)
- **Network:** `traefik_net` (Docker bridge, shared with backend services)
- **Provider:** File-based routing only (no Docker auto-discovery)

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Traefik container config |
| `traefik.yml` | Static Traefik config (entrypoints, TLS, providers) |
| `routes.yml` | Dynamic routing rules (HTTP routers + services) |

## Key Config Decisions

### No Docker Provider

Traefik v3.3's Go Docker client hardcodes API version 1.24, which Docker ≥24 rejects (minimum 1.40). Since we have static file-based routing and Docker's internal DNS resolves container names on the shared network, the Docker provider is unnecessary.

**If you need auto-discovery later:** Upgrade to Traefik v3.4+ or use Docker labels with a TCP socket proxy.

### ACME Challenge

HTTP-01 challenge uses the `web` entrypoint (port 80). The `websecure` entrypoint (port 443) serves the actual traffic after certificate issuance.

## Template Note

Per `01-core-infra` workflow, the canonical source is:
```
~/dev/01-core-infra/templates/infra/04-network-traefik/
```

Update template before running `install.sh`.

## Commands

```bash
# Start/restart Traefik
cd ~/dev/04-network-traefik && docker compose up -d

# View logs
docker logs traefik --tail 50

# Force DNS update
curl -s "https://www.duckdns.org/update?token=53c4be1e-7eb7-4d46-8c6c-6e9cde44a037&domains=aldof.duckdns.org"

# Check DNS resolution
getent hosts freellm.aldof.duckdns.org
```

## Troubleshooting

| Symptom | Check |
|---|---|
| `Connection refused` on :443 | Traefik not running: `docker compose up -d` |
| `502 Bad Gateway` | Backend service down: `docker ps` |
| SSL certificate errors | Check `docker logs traefik` for ACME errors |
| Domain doesn't resolve | Run DuckDNS update command or wait for cron |
