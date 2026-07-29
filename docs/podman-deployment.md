# Podman Deployment Guide

Run the entire 01-core-infra development environment **inside a persistent Podman container** on Fedora (or any Linux with Podman). The container acts as a portable CLI workstation with all tools installed — ideal for connecting to remote services running on your Raspberry Pi.

## Quickstart

Create a persistent Debian container with user `aldo` and all tools pre-installed:

```bash
podman run -d --name 01-core-infra \
  --hostname core-infra \
  debian:bookworm \
  bash -c "
    set -e
    apt-get update && apt-get install -y curl sudo git ca-certificates

    # Create user aldo (matching the Pi environment)
    useradd -m -s /bin/bash aldo
    echo 'aldo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/aldo
    chmod 440 /etc/sudoers.d/aldo

    # Run installer as aldo
    sudo -u aldo bash -c '
      curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
    '

    # Keep container alive
    tail -f /dev/null
  "
```

## Usage

```bash
# Open a shell as user aldo inside the container
podman exec -it -u aldo 01-core-infra bash

# Or run a command directly
podman exec -it -u aldo 01-core-infra opencode --version
podman exec -it -u aldo 01-core-infra omo --version

# Check logs
podman logs 01-core-infra

# Stop and start
podman stop 01-core-infra
podman start 01-core-infra
```

## What Works Inside the Container

All CLI tools install and work correctly:

| Tool | Status |
|------|--------|
| `opencode` | ✅ Full functionality |
| `omo` | ✅ Full functionality |
| `node` / `npm` | ✅ Full functionality |
| `tree` | ✅ Full functionality |
| `git` | ✅ Full functionality |
| `curl` | ✅ Full functionality |
| `opencode` config (`~/.config/opencode/config.yaml`) | ✅ Auto-configured |

## What Does NOT Work Inside the Container

Docker services cannot run inside a container (no Docker daemon available). These Ansible tasks will fail gracefully:

| Task | Why |
|------|-----|
| `docker.io` / `docker-compose` install | Daemon cannot start |
| `docker network create traefik_net` | No daemon |
| `docker-compose up -d` (toerekening) | No daemon |
| `docker-compose up -d` (freellmapi) | No daemon |

**This is expected.** The container is a **CLI workstation** — you use it to run `opencode`, `omo`, `npm`, etc. while connecting to services running on your Raspberry Pi (`192.168.0.5`).

## Architecture Overview

```
┌─────────────────────┐       ┌──────────────────────┐
│  Fedora (Podman)    │       │  Raspberry Pi        │
│                     │       │                      │
│  ┌───────────────┐  │       │  ┌────────────────┐  │
│  │ 01-core-infra │  │       │  │ freellmapi     │  │
│  │ container     │──┼───────┼─▶│ :3001          │  │
│  │               │  │       │  ├────────────────┤  │
│  │ opencode      │  │       │  │ toerekening    │  │
│  │ omo           │  │       │  │ :3002          │  │
│  │ npm/node      │  │       │  └────────────────┘  │
│  │ git/curl      │  │       │                      │
│  └───────────────┘  │       └──────────────────────┘
└─────────────────────┘
```

The container connects to the Pi via LAN (`192.168.0.5`). The opencode config is already pre-configured with the `freellm` provider pointing at `http://192.168.0.5:3001/v1`.

## Updating the Container

```bash
# Pull latest installer and re-run inside the container
podman exec -it -u aldo 01-core-infra bash -c "
  curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
"
```

## Troubleshooting

### Container exits immediately
If the container exits, check if `tail -f /dev/null` is the last command. If the installer fails, the entire shell script exits and the container stops. Run without `-d` first to see errors:

```bash
podman run -it --name 01-core-infra debian:bookworm bash
# Then run the commands manually
```

### Permission denied for user aldo
Ensure `/etc/sudoers.d/aldo` was created correctly:

```bash
podman exec -it --user root 01-core-infra bash -c "visudo -c -f /etc/sudoers.d/aldo"
```

### "Repository already exists" warning
The installer detects existing repos and skips re-cloning. If you need a fresh install:

```bash
podman exec -it -u aldo 01-core-infra bash -c "
  rm -rf ~/dev/01-core-infra
  curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
"
```

## Podman vs Docker

| Feature | Podman | Docker |
|---------|--------|--------|
| Daemonless | ✅ Yes | ❌ Requires daemon |
| Rootless | ✅ Default | ❌ Needs config |
| `docker-compose` | Use `podman-compose` | Native |
| Command alias | `alias docker=podman` | — |

On Fedora, Podman is the default container runtime. The instructions above work identically with Docker if you replace `podman` with `docker`.

## Advanced: Custom Container with Docker Socket

If you *do* want Docker services inside the container (e.g., for testing), bind-mount the host's Docker socket:

```bash
podman run -d --name 01-core-infra \
  --hostname core-infra \
  -v /var/run/docker.sock:/var/run/docker.sock \
  debian:bookworm \
  bash -c "
    apt-get update && apt-get install -y curl sudo git docker.io
    useradd -m -s /bin/bash aldo
    echo 'aldo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/aldo
    usermod -aG docker aldo
    sudo -u aldo bash -c '
      curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
    '
    tail -f /dev/null
  "
```

> ⚠️ This gives the container root-equivalent access to the host's Docker daemon. Use with caution.
