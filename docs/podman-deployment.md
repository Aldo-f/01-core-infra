# Podman Deployment Guide for 01-core-infra

This guide explains how to deploy and manage the `01-core-infra` project using Podman on Fedora or any Linux distribution that supports Podman. This setup provides a persistent, isolated environment for your development tools and allows you to manage your Raspberry Pi infrastructure remotely.

## Core Concept

The goal is to run the `01-core-infra` project's installer and tools within a persistent Podman container. This container acts as a portable CLI workstation, pre-configured with all necessary development tools and the `aldo` user. The installer script will then set up the required services on your target Raspberry Pi (or other Linux environment).

## Quickstart: Persistent Container with User Setup & Installer

This command creates a persistent Debian container named `01-core-infra`, adds the `aldo` user with sudo privileges, and automatically runs the `01-core-infra` installation script as that user.

```bash
podman run -d --name 01-core-infra \
  --hostname core-infra \
  debian:bookworm \
  bash -c \
  $'\
set -euo pipefail; \

echo "=== Preparing container environment ==="; \
apt-get update -qq && apt-get install -y -qq curl sudo git ca-certificates && \
echo "  ✅ System packages installed."; 

if ! id aldo &>/dev/null; then 
  useradd -m -s /bin/bash aldo && 
  echo 'aldo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/aldo && 
  chmod 440 /etc/sudoers.d/aldo && 
  echo "  ✅ User aldo created and sudo configured."; 
else 
  echo "  ℹ️ User aldo already exists."; 
fi; 

echo "  📦 Running 01-core-infra installer..."; 
sudo -u aldo bash -c \
  \'curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash\' \
  || echo "  ⚠️ Installer finished with potential errors (check logs)"; 

echo "  ✅ Container setup complete."; 
echo "  💻 Access it with: podman exec -it -u aldo 01-core-infra bash"; 
tail -f /dev/null 
\'
'
```

**Important Notes:**
- The installer script runs inside the container and deploys services to your **actual target machine** (e.g., your Raspberry Pi), not within the container itself.
- The container's `01-core-infra` directory will be isolated. To manage files on your host or Pi, you might need to mount volumes or use `podman exec` to copy files.

## Managing the Container

```bash
# Open a shell as user aldo inside the container
podman exec -it -u aldo 01-core-infra bash

# Run a command directly as aldo
podman exec -it -u aldo 01-core-infra opencode --version

# View container logs
podman logs 01-core-infra

# Stop the container
podman stop 01-core-infra

# Start the container
podman start 01-core-infra

# Remove the container (and its internal filesystem)
podman rm -f 01-core-infra
```

## What Works Inside the Container

All CLI tools intended for the *management* of your infrastructure will work correctly inside the container:

| Tool | Status |
|---|---|
| `opencode` | ✅ Fully functional |
| `omo` | ✅ Fully functional |
| `node` / `npm` | ✅ Fully functional |
| `tree` | ✅ Fully functional |
| `git` | ✅ Full functionality |
| `curl` | ✅ Full functionality |
| `opencode` config (`~/.config/opencode/config.yaml`) | ✅ Auto-configured |

## What Does NOT Work Inside the Container

**Docker services cannot run inside this container** because it doesn't have a Docker daemon. Therefore, any Ansible tasks that attempt to manage Docker services (like `docker network create`, `docker-compose up`) will fail when executed *within* this container. This is by design, as the container is intended to be a CLI client, not a host for the deployed services.

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

The container connects to the Pi via LAN (`192.168.0.5`). The `opencode` config is already pre-configured in the installer to point to this address.

## Updating the Container's Environment

To update the tools and installer *inside* the container (e.g., after changes to `install.sh` or if new tools are added):

```bash
# Re-run the installer script within the container
podman exec -it -u aldo 01-core-infra bash -c "
  curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
"
```

## Troubleshooting

- **Container Exits Immediately**: Ensure the `tail -f /dev/null` command is the last one in the `bash -c` string to keep the container running. If the installer fails, the script may exit. Run `podman logs 01-core-infra` to inspect.
- **Permission Denied for User `aldo`**: Verify the `aldo` user and its sudo configuration within the container:
  ```bash
  podman exec -it --user root 01-core-infra bash -c "visudo -c -f /etc/sudoers.d/aldo"
  ```
- **"Repository already exists" Warning**: The installer is designed to be idempotent. If you need a completely clean state, manually remove the directory first:
  ```bash
  podman exec -it -u aldo 01-core-infra bash -c "
    rm -rf ~/dev/01-core-infra
    curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
  "
  ```

## Podman vs Docker

- Podman is daemonless and user-friendly on Fedora. The provided commands use Podman.
- If you prefer Docker, replace `podman` with `docker` in the commands. Ensure Docker is installed and running on your host.