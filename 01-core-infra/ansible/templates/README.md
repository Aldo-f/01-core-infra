# an-freellmapi Documentation

## Overview
This Ansible-managed infrastructure automates deployment of a Raspberry Pi-based development environment with:
- Preconfigured CLI tools (Git, Ollama, Bun, etc.)
- Dockerised AI services
- Systemd services with passwordless sudo
- Automated cron jobs
- Security-focused configuration

## Workflow
1. **Edit** templates under `templates/infra/<component>/` (source of truth)
2. Run `./install.sh` to rebuild entire `~/dev` tree
3. **Never modify runtime directories** (`plex/`, `portainer/`, etc. directly)

## Component Structure
`templates/infra/<component>/` defines each service component. Examples:
- `01-core-portainer/` → `~/dev/01-core-infra/portainer/
- `02-ai-freellmapi/` → `~/dev/02-ai-freellmapi/
- `04-network-traefik/` → `~/dev/04-network-traefik/

## Critical Notes
- **PATH Management**: Curl-installed tools require explicit PATH configuration in `install.sh`
- **Ollama API Key**: Use `~/.config/ollama/api_key` format (not interactive `ollama signin`)
- **Idempotent Updates**: Run `./install.sh` after template edits
- **Git Configuration**: Global user set to `Aldo <aldo.fieuw@gmail.com>`

## Key Directories
- `templates/` → YAML/shell templates
- `playbooks/` → Ansible deployment logic
- `logs/` → Service logs (git-ignored)

## Security
- Passwordless sudo only for user `aldo`
- Secrets stored in encrypted files (not in repository)
- No browser-facing services deployed by default

## Maintenance
- Schedule nightly rebuilds with `anf-rebuild` cron job
- Monitor logs in `~/dev/01-core-infra/logs/`