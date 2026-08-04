# AGENTS.md — 01-core-infra

Ansible-managed home-lab infrastructure for a Raspberry Pi 5. Every component is named `<NN>-<domain>-<name>`; the prefix decides both its domain and its deploy target.

## Quickstart

```bash
# bootstrap: clones/updates the repo at INSTALL_DIR, then runs scripts/deploy.sh
curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
```

The playbook is idempotent — re-run after any template change:

```bash
cd ansible && ansible-playbook -i inventories/local.yml playbooks/site.yml
```

**The active playbook is `ansible/playbooks/site.yml`.** Note `ansible/site.yml` also exists — it is a leftover bootstrap-only playbook (clones hermes-webui); don't treat it as the main one.

| Script | What it does |
|------- | ------------ |
| `install.sh` | Hardcodes `INSTALL_DIR=/home/aldo/dev/01-core-infra`, `VERSION=main`. If already a git repo, `fetch --depth=1` and `reset --hard` to `origin/main` **only if local is not ahead** (skips update on unpushed commits), then `exec scripts/deploy.sh`. |
| `scripts/deploy.sh` | Ensures `ansible` + `git` exist, then runs the playbook from `ansible/`. |

## Agent Rules

- **Don't edit runtime dirs** (`portainer/`, `cockpit/`, generated) — edit `templates/infra/<component>/` and deploy.
- **Don't hardcode paths** in cron/systemd templates — use `__HOME__`, `__USER__`, `__CORE_INFRA__` placeholders.
- **Don't modify `/etc/sudoers.d/`** — only `aldo` gets the grant (for the `app-deploy-systemd` helper). Agents must not touch sudoers.
- **Don't add tools** without adding a sentry entry in `ansible/roles/tools/defaults/main.yml` (the `tools_sentries:` dict maps each tool to its `command` check — Ansible skips if the binary is already present).
- **Don't expect `ollama signin`** to work headless — use `~/.config/ollama/api_key` (one key per line) or `OLLAMA_API_KEY`.
- **Secrets live in Ansible Vault** — see [Vault](#vault--secrets).

## Group Taxonomy

The prefix determines both domain and deploy target.

| # | Group | Deploy target | Status |
|---|-------|---------------|--------|
| 01 | core | inside this repo: `01-core-infra/<name>/` | active |
| 02 | ai | own git repos (cloned via `repos.manifest.jsonc`; only `infra/` overwritten) or embedded | active |
| 03 | monitoring | reserved | planned |
| 04 | network | `~/dev/04-network-<name>/` | active |
| 05 | media | in-repo templates → `templates/infra/05-*-*` | active |
| 06 | apps | own git repos (via manifest) or role-deployed | active |
| 07 | security | `~/dev/07-security-<name>/` | active |
| 08 | storage | reserved | planned |

### Components per group

- **01-core** (ansible-copy, in-repo): `01-core-portainer`, `01-core-cockpit` → `~/dev/01-core-infra/{portainer,cockpit}/`.
- **02-ai**: `02-ai-freellmapi` (manifest, branch `upstream`), `02-ai-llm-infra-sync` (manifest, branch `main`), `02-ai-mem0` (embedded, no container — config template `mem0.json.j2` → `~/.hermes/mem0.json`, Qdrant at `~/.hermes/mem0_qdrant`), `02-ai-script-google` (template, deploy target `templates/apps/scripts-google/`).
- **04-network** (ansible-copy, sibling): `traefik`, `pihole`, `wireguard` → `~/dev/04-network-<name>/`.
- **05-media** (now in-repo templates): `05-media-plex`, `05-media-qbittorrent`, `05-media-nextcloud` — each a `docker-compose.yml` under `templates/infra/`.
- **06-apps**: `06-apps-thuis-v4`/`v5` (manifest, branches `v4/main`·`v5/main`), `06-apps-neo4ty-brutalist-home` (role-deployed, static site), `06-apps-scripts-google` (manifest). `templates/apps/toerekening/` exists but is **not** infra-managed.
- **07-security**: `07-security-vaultwarden` → `~/dev/07-security-vaultwarden/`.

**03 / 08 reserved** — create `templates/infra/<nn>-<domain>-<name>/` when adding the first component.

## Architecture

```
…/01-core-infra/
  ansible/playbooks/site.yml        ← main playbook (roles, in order)
  ansible/roles/                    ← base, tools, templates, containers,
                                       systemd, cron, llamacpp,
                                       neo-brutalist-home, hermes-skills,
                                       freelapi-*, mesh_sync, containers
  templates/infra/<component>/      ← EDIT HERE (source of truth for 01/02/05/07 + wires)
  templates/systemd/, templates/cron/, templates/apps/
  vaults/                           ← Ansible Vault secrets (master.key NEVER committed)
  portainer/ cockpit/               ← generated runtime — never edit
```

### Ansible playbook

`ansible/playbooks/site.yml` runs **roles in this order** (from `ansible/roles/`):

`base → tools → templates → systemd → llamacpp → neo-brutalist-home → cron → hermes-skills → mesh_sync → containers`

- `site.yml` also declares `tools_sentries` (list of tool names) and runs a pre-task symlinking `~/.bun/bin/bun` → `/usr/local/bin/bun`.
- `ansible/roles/containers/` is the **container deployment** role: it reads `container_services` from its `defaults/main.yml`, copies each `templates/infra/<name>/docker-compose.yml` to its runtime dir, and runs `docker compose up -d --remove-orphans`. It also syncs the Traefik `routes.yml`. **Currently the `container_services` default list only wires 01-core and 07-security — 05-media compose files are not yet in that list.**(i.e., they have compose templates but aren't auto-deployed).
- `ansible/roles/templates/` currently only deploys `templates/infra/hermes/auth.json.j2` → Hermes home.
- `ansible/roles/mesh_sync/` runs the credential-sync engine (back) at deploy end.
- `ansible.cfg`: default `inventories/local.yml`, `roles_path` set, and `vault_password_file = vaults/master.key`.

## Secrets & Vault

- Encrypted secrets use **Ansible Vault**; the vault password file is `vaults/master.key` (declared in `ansible.cfg`).
- **Never commit `vaults/master.key`** — it's git-ignored; read it once via `openssl rand -base64 32` and keep perms `600`.
- To decrypt/encrypt: `ansible-vault decrypt|encrypt --vault-password-file vaults/master.key vaults/<file>.yml`.
- Encrypted vault vars are loaded with `no_log: true` (see `roles/freellmapi/tasks/main.yml` for the pattern).

## Workflow / gotchas

- **Tool sentries**: every CI tool is declared in `roles/tools/defaults/main.yml`. Adding a tool requires adding its sentry (its `command` check) there **first**.
- **Path placeholders**: cron and systemd templates must use `__HOME__`, `__USER__`, `__CORE_INFRA__`. A `.husky/pre-commit` hook + CI reject hardcoded `/home/.../dev/01-core-infra` and missing placeholders.
- **Docker**: Compose **v2 plugin** only (`docker compose`, never `docker-compose`). Components are single `docker-compose.yml` files.
- **`__CORE_INFRA__/`** (the git-ignored top-level dir with its own `.git`) is a stale runtime copy — don't edit it.

## Reference

### Ollama (headless Pi)
- `ollama signin` is interactive — does **not** work over SSH on a headless Pi.
- Use `~/.config/ollama/api_key` (one per line, `#` comments) or `OLLAMA_API_KEY`; multiple keys become `OLLAMA_API_KEY_N`.
- Model auto-selected by RAM (qwen3:4b 8GB, qwen3:8b 16GB, …); override with `OLLAMA_MODEL`.

### Systemd units
- Templates: `templates/systemd/*.service`; deployed via the passwordless-sudo helper `app-deploy-systemd`. Most are the legacy `ExecStart=/bin/true` stubs — configure before expecting them to run.

### Backup & Healthcheck (git-ignored `logs/`)
| Script | What | Frequency | Retention |
|---|---|---|---|
| `backup.sh` | tar.gz of plex/config, portainer/data, etc. | Daily 03:00 | 7 days |
| `healthcheck.sh` | Docker containers + `app-*.service` units | Every 15 min | 14 days |

Both skip directories containing secrets.

### CI (`ansible/.github/workflows/ci-verification.yml`)
- yamllint on `ansible/` YAML; `ansible-playbook --syntax-check`
- cron-template placeholder check; file-permission check;
- role-structure check (`tasks/main.yml` + `defaults/main.yml` per role) and `tools_sentries` presence.

### .gitignore (high-signal entries)
- `vaults/master.key`, `*.env`, `.env.*`, `auth.json` — secrets
- runtime dirs + `.ansible/`, `.test-venv/`, `docs/theme/`
- `__CORE_INFRA__/`, `precommit.log`