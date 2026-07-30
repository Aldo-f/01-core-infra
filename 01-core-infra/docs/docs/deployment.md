---
sidebar_position: 3
---

# Deployment

## Bootstrap Installation

The quickest way to get started is using the bootstrap installer:

```bash
curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/v0.0.1/install.sh | bash
```

This will:
1. Validate the version tag exists on the remote repository
2. Clone the repository with a shallow clone (`--depth 1`)
3. Execute `scripts/deploy.sh` to run the full deployment

### Installer Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_DIR` | `$HOME/dev/01-core-infra` | Where to clone the repository |
| `REPO_URL` | `https://github.com/Aldo-f/01-core-infra.git` | Repository to clone |
| `VERSION` | `main` | Git ref to checkout |

## Ansible Deployment

After the initial clone, or after making template changes, run:

```bash
cd ansible && ansible-playbook -i inventories/local.yml playbooks/site.yml
```

The playbook is **idempotent** — running it multiple times produces the same result. It will:
- Detect system RAM and select the appropriate Ollama model
- Install Docker and Docker Compose
- Install CLI tools (NVM, Node.js, Tailscale, Ollama, etc.)
- Create Docker networks (e.g., `traefik_net`)
- Deploy infrastructure components from templates
- Set up systemd units
- Configure cron jobs for backup and healthcheck
- Run mesh sync for credential distribution

### Playbook Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `container_test` | `false` | Set to `true` when testing in Docker (skips daemon-dependent tasks) |
| `ollama_model` | Auto-detected | Model based on RAM: 4B (&lt;12GB), 8B (&lt;20GB), 27B (32GB+) |

## Component Types and Deployment Methods

| Type | Deployment Method | Description |
|------|-------------------|-------------|
| **pure-infra** | `ansible-copy` | Templates copied directly by Ansible |
| **network** | `ansible-copy` | Network components deployed to sibling repos |
| **git-repo** | `repo_manifest` | Separate git repos, only `infra/` subdir overwritten |

## Healthcheck

```bash
./healthcheck.sh
```

Checks Docker container status and `app-*.service` systemd units every 15 minutes. Results are logged to `logs/` (git-ignored). Log retention: 14 days.

## Backup

```bash
./backup.sh
```

Creates `tar.gz` archives of:
- `plex/config/`
- `portainer/data/`
- `pihole/etc-pihole/`

Backups run daily at 03:00. Retention: 7 days. Backup logs are in `logs/` (git-ignored).

Both backup and healthcheck scripts skip directories containing secrets.
