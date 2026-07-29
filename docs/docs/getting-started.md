---
sidebar_position: 1
---

# Getting Started

Welcome to the 01-core-infra documentation. This guide will help you set up and configure your infrastructure.

## Quick Installation

The fastest way to deploy is with the bootstrap installer:

```bash
curl -o- https://raw.githubusercontent.com/Aldo-f/01-core-infra/v0.0.1/install.sh | bash
```

This will clone the repository and run the full deployment.

## Manual Setup

If you already have the repository cloned:

```bash
cd ~/dev/01-core-infra/ansible
ansible-playbook -i inventories/local.yml playbooks/site.yml
```

## What Gets Deployed

The Ansible playbook will set up:

- **Docker** with Compose v2 plugin
- **CLI tools** — NVM, Node.js, Tailscale, Ollama, and more
- **Infrastructure components** — Portainer, Plex, qBittorrent, Cockpit
- **Network services** — Traefik, Pi-hole, WireGuard
- **Applications** — Thuis apps v4/v5, FreeLLM API
- **Systemd units** — service management
- **Cron jobs** — automated backup and healthcheck
- **Mesh sync** — credential distribution

## Next Steps

- **[Architecture](/docs/architecture)** — Understand the directory layout and design
- **[Deployment](/docs/deployment)** — Detailed deployment and configuration guide
- **[Components](/docs/components)** — Full component registry
- **[Reference](/docs/reference)** — Ollama, Docker, systemd, cron, and CI/CD
