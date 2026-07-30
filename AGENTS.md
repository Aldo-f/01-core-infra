# AGENTS.md

## Quickstart
1. **Bootstrap core infrastructure**
   ```bash
   cd dev/01-core-infra
   ./install.sh   # runs the Ansible playbook
   ```
2. **Deploy agents**
   ```bash
   cd hermes-workspace
   pnpm dev   # starts the Hermes UI and background agents
   ```

## Agent Rules
- **No edits to generated runtime directories** – modify only under `templates/infra/` and re‑run Ansible.
- **Never hard‑code absolute paths** – use the `__HOME__` macro or environment variables.
- **Tool sentry pattern** – each required CLI tool is declared in `ansible/roles/tools/defaults/main.yml`; agents should respect these sentries.
- **Safety first** – follow the safety checklist in the top‑level `AGENTS.md` before running any destructive command.

## Architecture Overview
```
/home/aldo/
 dev/
  01-core-infra/      # Editable infra templates, Ansible playbooks
  02-ai-freellm/      # FreeLLM router (Node.js/TypeScript)
  02-ai-hermes-webui/ # Python server + vanilla JS UI, no build step
  02-ai-llm-infra-sync/ # Sync scripts (Bun)
  04-network-traefik/ # Traefik reverse‑proxy configuration
  06-apps-toerekening/ # Example app (Docker compose)
```

## Workflow
1. **Admin** – Deploy the core infra via Ansible (`./install.sh`).
2. **Developers** – Edit files under `templates/infra/` for infra changes; edit source code under the respective project directories.
3. **Agents** – Use the commands listed below; they are idempotent and respect sentries.

## Common Commands (agents run these automatically)
| Project | Build / Test | Docs |
|---------|--------------|------|
| 01‑core‑infra | `./install.sh` → Ansible | `01-core-infra/AGENTS.md` |
| 02‑ai‑freellm | `npm install && npm run dev && npm test` | `02-ai-freellm/CONTRIBUTING.md` |
| 02‑ai‑hermes‑webui | `python3 bootstrap.py && ./ctl.sh start` | `02-ai-hermes-webui/ARCHITECTURE.md` |
| 04‑network‑traefik | `docker-compose up -d` | `04-network-traefik/docker-compose.yml` |
| 06‑apps‑toerekening | `docker compose up -d` | `06-apps-toerekening/docker-compose.yml` |

## Pitfalls & Quick Fixes
- **Missing CLI tools** – run `./install.sh` to install sentries (`docker`, `nvm`, `bun`, `ollama`, …).
- **Port conflicts** – ensure no other process is listening on `8787` before starting the UI (`lsof -i :8787`).
- **Environment variables** – create a proper `.env` at the repo root; avoid `HERMES_WEBUI_PRESERVE_ENV=1` during local dev.
- **Docker permissions** – add your user to the `docker` group to avoid root‑owned files.
- **Ansible sudo** – configure password‑less sudo or run the playbook as root.

For a deeper dive into each subsystem, see the linked documentation files.

## For AI coding agents

- **Quick run/test commands (one-liners):**
   - `cd 01-core-infra && ./install.sh` — bootstrap infra and sentries.
   - `cd 02-ai-hermes-webui && python3 bootstrap.py && ./ctl.sh start` — start Hermes WebUI.
   - `cd 02-ai-freellm && npm install && npm run dev` — start FreeLLM router (dev).
   - `cd 02-ai-llm-infra-sync && bun install && bun run src/index.ts` — run infra-sync CLI.

- **Preflight checks:** verify required env files (`.env`), check port availability (e.g. `8787`), confirm Docker group membership, and consult `01-core-infra/install.sh` before performing system-level changes.

- **Agent surfaces & skills:** project-specific agent guidance and skills live in project AGENTS.md files: `01-core-infra/AGENTS.md`, `02-ai-hermes-webui/AGENTS.md`, and `02-ai-llm-infra-sync/AGENTS.md`. Hermes-specific architecture and skill locations are documented in `02-ai-hermes-webui/ARCHITECTURE.md`.

- **Where to look first:** `ansible/`, `01-core-infra/templates/`, `02-ai-hermes-webui/bootstrap.py`, `02-ai-hermes-webui/ctl.sh`, and project `package.json` / `pyproject.toml` files for exact scripts.

