# 01-core-infra

Ansible-managed home-lab infrastructure for the Raspberry Pi 5. Components are organized in **numbered groups** — every component is named `<NN>-<domain>-<name>` and the prefix decides both its domain and its deploy target.

One-command install:

```bash
curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
```

## Groups

| # | Group | Purpose | Deploy target | Status |
|---|-------|---------|---------------|--------|
| 01 | core | Core infrastructure (container mgmt, server admin) | inside this repo: `01-core-infra/<name>/` | active |
| 02 | ai | AI services & LLM tooling | own git repos (via `repos.manifest.jsonc`) | active |
| 03 | monitoring | Observability: healthchecks, uptime-kuma, grafana, prometheus | TBD | planned |
| 04 | network | Reverse proxy, DNS, VPN | sibling repos: `~/dev/04-network-<name>/` | active |
| 05 | media | Media stack (plex, qbittorrent, *arr) | sibling repos: `~/dev/05-media-<name>/` | active |
| 06 | apps | User-facing applications | own git repos (via `repos.manifest.jsonc`) | active |
| 07 | security | Identity & security: authelia, vaultwarden, crowdsec | TBD | planned |
| 08 | storage | Storage & backup: samba, nfs, syncthing, restic | TBD | planned |

## Components

**01-core** — pure-infra, ansible-copy → `01-core-infra/<name>/`
- `01-core-portainer` — container management UI
- `01-core-cockpit` — server admin UI

**02-ai** — own git repos (only `infra/` overwritten by Ansible) or embedded
- `02-ai-freellmapi` — FreeLLM API router (repo `aldo-f/freellmapi`, branch `upstream`)
- `02-ai-llm-infra-sync` — credential sync engine (repo `aldo-f/02-ai-llm-infra-sync`)
- `02-ai-mem0` — self-hosted memory backend for Hermes (**embedded**, no container): config template `mem0.json.j2` → `~/.hermes/mem0.json`, runs in the Hermes venv with local Qdrant at `~/.hermes/mem0_qdrant`; pre-init via `scripts/setup-mem0.sh`
- Dev repos (not infra-managed): `02-ai-freellm`, `02-ai-hermes-webui`

**04-network** — pure-infra, ansible-copy → `~/dev/04-network-<name>/`
- `04-network-traefik` — reverse proxy / edge router
- `04-network-pihole` — DNS + ad blocking
- `04-network-wireguard` — VPN

**05-media** — pure-infra, ansible-copy → `~/dev/05-media-<name>/`
- `05-media-plex` — media server
- `05-media-qbittorrent` — torrent client

**06-apps** — own git repos (via `repos.manifest.jsonc`) or dev-managed compose apps
- `06-apps-thuis-v4` / `06-apps-thuis-v5` — home app (repo `aldo-f/thuis`, branches `v4/main`, `v5/main`)
- `06-apps-nextcloud` — Nextcloud instance
- `06-apps-toerekening` — Toerekening app

**03-monitoring, 07-security, 08-storage** — reserved; create `templates/infra/<nn>-<domain>-<name>/` when adding the first component.

For full documentation (agent rules, Ansible structure, component registry, CI), see [AGENTS.md](AGENTS.md).
