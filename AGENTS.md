# AGENTS.md — 01-core-infra

## One-Command Install

```bash
curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/v0.0.1/install.sh | bash
```

This command clones the repository at the tagged version and runs the bootstrap installer.


## Deployment

```bash
cd ansible && ansible-playbook -i inventories/local.yml playbooks/site.yml
```

Idempotent. Run after any template change.


## Scripts

| Script | Description |
|---|---|
| `install.sh` | Bootstrap installer — clones the repo at a tagged version (validates tag, shallow clone), then execs `scripts/deploy.sh`. |
| `scripts/deploy.sh` | Full deployment logic (phases 0–4) extracted from the original `install.sh`. |

Both scripts live at the repository root.


## Source of Truth

```
~/dev/01-core-infra/
  templates/infra/<component>/   ← EDIT HERE
  ansible/                       ← Deployment automation
  plex/ portainer/ qbittorrent/  ← NEVER TOUCH (generated)
```

## Component Registry

| Component | Template Source | Runtime Target |
|---|---|---|
| 01-core-portainer | `templates/infra/01-core-portainer/` | `~/dev/01-core-infra/portainer/` |
| 01-core-plex | `templates/infra/01-core-plex/` | `~/dev/01-core-infra/plex/` |
| 01-core-qbittorrent | `templates/infra/01-core-qbittorrent/` | `~/dev/01-core-infra/qbittorrent/` |
| 01-core-cockpit | `templates/infra/01-core-cockpit/` | `~/dev/01-core-infra/cockpit/` |
| 04-network-traefik | `templates/infra/04-network-traefik/` | `~/dev/04-network-traefik/` |
| 04-network-pihole | `templates/infra/04-network-pihole/` | `~/dev/04-network-pihole/` |
| 04-network-wireguard | `templates/infra/04-network-wireguard/` | `~/dev/04-network-wireguard/` |
| 02-ai-llm-infra-sync | `templates/infra/02-ai-llm-infra-sync/` | `~/dev/02-ai-llm-infra-sync/` (git repo) |
| 06-apps-thuis-v4 | `templates/infra/06-apps-thuis-v4/infra/` | `~/dev/06-apps-thuis-v4/infra/` (branch v4/main) |
| 06-apps-thuis-v5 | `templates/infra/06-apps-thuis-v5/infra/` | `~/dev/06-apps-thuis-v5/infra/` (branch v5/main) |
| 02-ai-freellmapi | `templates/infra/02-ai-freellmapi/infra/` | `~/dev/02-ai-freellmapi/infra/` (branch upstream) |

**Naming convention determines target:**
- `01-core-*` → inside this repo (`01-core-infra/<name>/`)
- `04-network-*` → sibling repo (`~/dev/04-network-<name>/`)
- `02-*`, `06-*` → own git repos (cloned via manifest, only `infra/` subdir overwritten)

## Repo Manifest

`templates/infra/repos.manifest.jsonc` declares git-repo identity (remote + ref + infraSubdir). Deploy clones/pulls, checkout the ref, and copies only `infra/` — preserving `.git` and app source code.

## Ansible Structure

```
ansible/
  ansible.cfg                          ← roles_path, inventory default
  inventories/local.yml                ← localhost connection
  playbooks/site.yml                   ← main playbook (roles in order)
  roles/
    base/                              ← apt packages, system setup
    tools/                             ← CLI tools (sentinel-based idempotency)
    templates/                         ← deploy infra components
    systemd/                           ← systemd units + sudoers
    cron/                              ← cron jobs (backup + healthcheck)
    mesh_sync/                         ← credential sync engine
  .github/workflows/ci-verification.yml ← CI: yaml lint, syntax check, template integrity
```

**Role execution order** (defined in `site.yml`): base → tools → templates → systemd → cron → mesh_sync

**Tool sentries** (`roles/tools/defaults/main.yml`): each tool has a `command` check — Ansible skips if present. When adding a new tool, add a sentry entry here first.

## Ollama

- `ollama signin` is interactive — **does not work** over SSH on headless Pi.
- Use `~/.config/ollama/api_key` (one key per line, `#` comments) or `OLLAMA_API_KEY` env var.
- Multiple keys loaded as `OLLAMA_API_KEY_1`, `OLLAMA_API_KEY_2`, etc.
- Model selection automatic by RAM (qwen3:4b for 8GB, qwen3:8b for 16GB, qwen3.6 for 32GB+). Override with `OLLAMA_MODEL`.

## Docker

Uses Compose **v2 plugin** (`docker compose`, not `docker-compose`). All components are single `docker-compose.yml` files.

## Systemd Units

- Templates: `templates/systemd/app-*.service`
- Currently stubs (`ExecStart=/bin/true`) — **configure before expecting them to run**.
- Deployed via passwordless-sudo helper (`/usr/local/bin/app-deploy-systemd`).
- Only `aldo` gets the sudoers grant — agents should not modify sudoers files.

## Cron Templates

- Source: `templates/cron/01-core-infra.cron`
- Uses **placeholders** (`__HOME__`, `__USER__`, `__CORE_INFRA__`) — never hardcode paths.
- Pre-commit hook (`.husky/pre-commit`) rejects hardcoded `/home/aldo/dev/01-core-infra` paths.

## Mesh Sync Engine

`02-ai-llm-infra-sync` (TypeScript/Bun). Harvests credential pools, deduplicates per-provider, distributes back. Runs as `bun sync` at deploy end. Manual run: `bun install && bun sync` in `~/dev/02-ai-llm-infra-sync/`.

## Backup & Healthcheck

| Script | What | Frequency | Retention |
|---|---|---|---|
| `backup.sh` | `tar.gz` of plex/config, portainer/data, pihole/etc-pihole | Daily 03:00 | 7 days |
| `healthcheck.sh` | Docker containers + `app-*.service` units | Every 15 min | 14 days |

Both write to `logs/` (git-ignored). Both skip dirs containing secrets.

## CI (GitHub Actions)

`.github/workflows/ci-verification.yml` runs on pushes to `main`/`develop` when Ansible or templates change:
- YAML lint (`yamllint`)
- Ansible syntax check (`--syntax-check`)
- Ansible lint (`ansible-lint`)
- Template placeholder validation
- Cron hardcoded path check
- Role structure validation (all roles have `tasks/main.yml` + `defaults/main.yml`)

## .gitignore

- Runtime dirs (`portainer/`, `plex/`, `qbittorrent/`, `cockpit/`) — generated
- `logs/`, `*.log`
- `secrets.json`, `*.env`, `.env.*` (except `.env.template`)
- `node_modules/`, `dist/`, `/04-network-*/`

## What Not to Do

- **Don't edit runtime dirs** — always edit `templates/infra/<component>/` and deploy.
- **Don't hardcode paths** in cron templates — use `__HOME__`, `__USER__`, `__CORE_INFRA__`.
- **Don't modify `/etc/sudoers.d/`** — managed by Ansible/systemd role.
- **Don't add tools** without adding a sentry in `ansible/roles/tools/defaults/main.yml`.
- **Don't expect `ollama signin`** to work on headless — use API key file.
