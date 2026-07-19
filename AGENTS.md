--
# AGENTS.md
# Infrastructure Orchestrator Brain

## EXECUTIVE SUMMARY
Single Source of Truth: `01-core-infra/templates/`. **One way of working** — edit ONLY
in `templates/`, then run `./install.sh`. Runtime dirs are 1:1 reconstructions and are
NEVER edited directly. A single `./install.sh` from `01-core-infra/` restores the entire
`~/dev` tree (pure-infra components + git repos via the manifest).

Structure: `templates/infra/<component>/` holds the full source for each component.
`templates/infra/repos.manifest.jsonc` records git-repo identity (remote + checkout ref +
infra subdir) so app-repos keep their `.git` and are never destroyed.

## WORKFLOW (THE ONLY WAY)
1. Edit a file under `templates/infra/<component>/`.
2. Run `./install.sh` (from `01-core-infra/`). It `cp -rf`s pure-infra components to their
   runtime target, and for manifest repos does `git clone/pull` + `git checkout <ref>` then
   copies infra into `<repo>/<infraSubdir>/`.
3. Never touch runtime dirs (`01-core-infra/plex`, `04-network-*`, cloned repos) directly.

## REGISTRY
| Component            | Template Source                          | Runtime Target                     | Type        |
|----------------------|------------------------------------------|------------------------------------|-------------|
| 01-core-portainer    | `templates/infra/01-core-portainer/`     | `~/dev/01-core-infra/portainer`    | pure-infra  |
| 01-core-plex         | `templates/infra/01-core-plex/`          | `~/dev/01-core-infra/plex`         | pure-infra  |
| 01-core-qbittorrent  | `templates/infra/01-core-qbittorrent/`   | `~/dev/01-core-infra/qbittorrent`  | pure-infra  |
| 01-core-cockpit      | `templates/infra/01-core-cockpit/`       | `~/dev/01-core-infra/cockpit`      | pure-infra  |
| 04-network-traefik   | `templates/infra/04-network-traefik/`    | `~/dev/04-network-traefik`         | pure-infra  |
| 04-network-pihole    | `templates/infra/04-network-pihole/`     | `~/dev/04-network-pihole`          | pure-infra  |
| 04-network-wireguard | `templates/infra/04-network-wireguard/`  | `~/dev/04-network-wireguard`       | pure-infra  |
| 02-ai-llm-infra-sync | `templates/infra/02-ai-llm-infra-sync/`  | `~/dev/02-ai-llm-infra-sync`       | git repo (private) |
| 06-apps-thuis-v4     | `templates/infra/06-apps-thuis-v4/infra/`| `~/dev/06-apps-thuis-v4/infra`     | git repo (branch v4/main) |
| 06-apps-thuis-v5     | `templates/infra/06-apps-thuis-v5/infra/`| `~/dev/06-apps-thuis-v5/infra`     | git repo (branch v5/main) |
| 02-ai-freellmapi     | `templates/infra/02-ai-freellmapi/infra/`| `~/dev/02-ai-freellmapi/infra`     | git repo (branch upstream) |

## REPO MANIFEST (repos.manifest.jsonc)
Declarative repo identity consumed by `install.sh`:
- `02-ai-llm-infra-sync` → `git@github.com:Aldo-f/02-ai-llm-infra-sync.git` @ main (private)
- `06-apps-thuis-v4` → `git@github.com:Aldo-f/thuis.git` @ v4/main
- `06-apps-thuis-v5` → `git@github.com:Aldo-f/thuis.git` @ v5/main
- `02-ai-freellmapi` → `git@github.com:Aldo-f/freellmapi.git` @ upstream
App-repos: only `<repo>/infra/` is overwritten; `.git` and source stay intact.

## MESH SYNC ENGINE
`02-ai-llm-infra-sync` (TypeScript/Bun). Harvests `credential_pool` from
`~/.hermes/auth.json`, `~/.config/opencode/auth.json`, `02-ai-omniroute/config.yaml`,
`02-ai-freellm-api/.env`; unifies per-provider via Set dedup; distributes back preserving
live metadata (no key logging, per-file try/catch, missing files skipped). Runs as `bun sync`
at the end of `install.sh`.

## HEALTH & MAINTENANCE
- **backup.sh**: daily `tar.gz` of `plex/config`, `portainer/data`, `pihole/etc-pihole` →
  `backups/` (git-ignored). Retention 7 days. Skips dirs containing secrets. Suggested cron:
  `0 3 * * * ~/dev/01-core-infra/backup.sh`.
- **healthcheck.sh**: checks `docker ps` status + `app-*.service` units; exit 1 if any down.
  Rotates own logs (14d). Suggested cron: `*/15 * * * * ~/dev/01-core-infra/healthcheck.sh`.
- **install.sh logs**: written to `logs/install-<ts>.log` (git-ignored), not repo-root.
- **Pi disk hygiene**: backups + logs are git-ignored and rotated; runtime dirs are git-ignored.

## STATE LOG
- Workflow consolidated to ONE method: edit `templates/infra/<component>/`, run `install.sh`.
- Stray `<service>.yml` copies removed; runtime dirs hold only what install.sh writes.
- `templates/docker/` → `templates/infra/<component>/docker-compose.yml`.
- `repos.manifest.jsonc` added for git-repo identity (clone/checkout/infra-subdir).
- `02-ai-llm-infra-sync` is now a real private GitHub repo (`git@github.com:Aldo-f/02-ai-llm-infra-sync.git`,
  branch main). Local commit + push done, `install.sh` clones/checks it out via the manifest.
- `06-apps-thuis-v4` (v4/main), `06-apps-thuis-v5` (v5/main), `02-ai-freellmapi` (upstream)
  are cloned + checked out via `repos.manifest.jsonc`; only their `infra/` subdir is overwritten.
- `backup.sh` + `healthcheck.sh` added.
- `gh` + `jq` installed (apt) as deploy tooling.
- systemd units use `app-` prefix.

## TODO/BACKLOG
1. [x] Create `02-ai-llm-infra-sync` repo on GitHub (private) + push — done
2. [ ] Validate Tomato firmware compatibility with Pi 5
3. [ ] Reconfigure WireGuard peers for new network IPs
4. [ ] Update Pi-hole blocklists quarterly
5. [x] Build & verify Mesh Sync Engine — done
6. [x] Wire up `06-apps-thuis-v4/v5` + `02-ai-freellmapi` via manifest clone — done
7. [ ] Grant passwordless sudo for deploy commands so `install.sh` runs unattended
