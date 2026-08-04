---
sidebar_position: 4
---

# Component Registry

All infrastructure components managed by this repository, their types, template sources, and runtime targets.

## Core Infrastructure (01-core-*)

Deployed inside this repository via `ansible-copy`.

| Component | Template Source | Runtime Target |
|-----------|----------------|----------------|
| Portainer | `templates/infra/01-core-portainer/` | `~/dev/01-core-infra/portainer/` |
| Cockpit | `templates/infra/01-core-cockpit/` | `~/dev/01-core-infra/cockpit/` |

## Network Components (04-network-*)

Deployed to sibling repos via `ansible-copy`.

| Component | Template Source | Runtime Target |
|-----------|----------------|----------------|
| Traefik | `templates/infra/04-network-traefik/` | `~/dev/04-network-traefik/` |
| Pi-hole | `templates/infra/04-network-pihole/` | `~/dev/04-network-pihole/` |
| WireGuard | `templates/infra/04-network-wireguard/` | `~/dev/04-network-wireguard/` |

## Media Components (05-media-*)

Deployed to sibling repos via `ansible-copy`.

| Component | Template Source | Runtime Target |
|-----------|----------------|----------------|
| Plex | `templates/infra/05-media-plex/` | `~/dev/05-media-plex/` |
| qBittorrent | `templates/infra/05-media-qbittorrent/` | `~/dev/05-media-qbittorrent/` |

## Git-Repo Components (02-*, 06-*)

Separate git repositories managed via the repo manifest. Only the `infra/` subdirectory is overwritten on deploy.

| Component | Repository | Branch | infraSubdir |
|-----------|-----------|--------|-------------|
| LLM Infra Sync | `~/dev/02-ai-llm-infra-sync/` | `main` | `infra/` |
| Thuis App v4 | `~/dev/06-apps-thuis-v4/` | `v4/main` | `infra/` |
| Thuis App v5 | `~/dev/06-apps-thuis-v5/` | `v5/main` | `infra/` |
| FreeLLM API | `~/dev/02-ai-freellmapi/` | `upstream` | `infra/` |

## Deployment Registry

| Component | Type | Deploy Method |
|-----------|------|---------------|
| 01-core-portainer | pure-infra | ansible-copy |
| 01-core-cockpit | pure-infra | ansible-copy |
| 04-network-traefik | network | ansible-copy |
| 04-network-pihole | network | ansible-copy |
| 04-network-wireguard | network | ansible-copy |
| 05-media-plex | media | ansible-copy |
| 05-media-qbittorrent | media | ansible-copy |
| 02-ai-llm-infra-sync | git-repo | repo_manifest |
| 02-ai-mem0 | embedded | manual copy + `scripts/setup-mem0.sh` |
| 06-apps-thuis-v4 | git-repo | repo_manifest |
| 06-apps-thuis-v5 | git-repo | repo_manifest |
| 02-ai-freellmapi | git-repo | repo_manifest |
