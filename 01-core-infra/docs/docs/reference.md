---
sidebar_position: 5
---

# Reference

## Ollama

- `ollama signin` is interactive and **does not work** over SSH on a headless Pi.
- Use `~/.config/ollama/api_key` (one key per line, `#` for comments) or the `OLLAMA_API_KEY` environment variable.
- Multiple keys are loaded as `OLLAMA_API_KEY_1`, `OLLAMA_API_KEY_2`, etc.
- Model selection is automatic based on available RAM:

| RAM | Model |
|-----|-------|
| &lt; 12 GB | `qwen3:4b` |
| 12–20 GB | `qwen3:8b` |
| 32 GB+ | `qwen3.6:27b-q4_K_M` |

Override with the `OLLAMA_MODEL` environment variable.

## Docker

- Uses Compose **v2 plugin** (`docker compose`, not `docker-compose`).
- All components are defined as single `docker-compose.yml` files.
- Docker networks (like `traefik_net`) are managed by Ansible.

## Systemd Units

- Templates are located in `templates/systemd/app-*.service`.
- Currently stubs with `ExecStart=/bin/true` — **configure before expecting them to run**.
- Deployed via a passwordless-sudo helper: `/usr/local/bin/app-deploy-systemd`.
- Only the `aldo` user gets the sudoers grant — agents should not modify sudoers files directly.

### Adding a New Systemd Service

1. Create a template in `templates/systemd/app-&lt;name&gt;.service`
2. Add the task to `ansible/roles/systemd/tasks/main.yml`
3. Run the playbook to deploy

## Cron Templates

- Source file: `templates/cron/01-core-infra.cron`
- Uses **placeholders** — never hardcode paths:

| Placeholder | Description |
|-------------|-------------|
| `__HOME__` | User home directory |
| `__USER__` | Username |
| `__CORE_INFRA__` | Path to 01-core-infra directory |

- The pre-commit hook (`.husky/pre-commit`) rejects any hardcoded `__CORE_INFRA__` paths in cron templates.

### Backup Schedule

| Script | What | Frequency | Retention |
|--------|------|-----------|-----------|
| `backup.sh` | tar.gz of plex/config, portainer/data, pihole/etc-pihole | Daily 03:00 | 7 days |

### Healthcheck Schedule

| Script | What | Frequency | Retention |
|--------|------|-----------|-----------|
| `healthcheck.sh` | Docker containers + `app-*.service` units | Every 15 min | 14 days |

Both scripts write to `logs/` (git-ignored) and skip directories containing secrets.

## Mesh Sync Engine

`02-ai-llm-infra-sync` is a TypeScript/Bun application that:
- Harvests credential pools from configured sources
- Deduplicates per-provider
- Distributes credentials back to all services

Run manually:
```bash
cd ~/dev/02-ai-llm-infra-sync
bun install && bun sync
```

The mesh sync runs automatically at the end of each Ansible deployment.

## CI/CD (GitHub Actions)

The repository has a CI pipeline that runs on every push (`.github/workflows/ci.yml`):

- **YAML lint** (`yamllint`)
- **Ansible syntax check** (`--syntax-check`)
- **Ansible lint** (`ansible-lint`)
- **Template placeholder validation** — ensures no hardcoded paths
- **Cron hardcoded path check**
- **Role structure validation** — all roles must have `tasks/main.yml` and `defaults/main.yml`

The documentation is deployed separately via `.github/workflows/deploy-docs.yml`.

## .gitignore

The following are excluded from version control:

- Runtime directories: `portainer/`, `plex/`, `qbittorrent/`, `cockpit/`
- Logs: `logs/`, `*.log`
- Secrets: `secrets.json`, `*.env`, `.env.*` (except `.env.template`)
- Build artifacts: `node_modules/`, `dist/`
- Network components: `/04-network-*/`
