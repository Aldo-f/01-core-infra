#!/usr/bin/env bash
set -euo pipefail

# Robust installer for 01-core-infra
# Works when executed directly or piped from curl
# Usage: curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash
# (Run WITHOUT sudo - the script will ask for sudo only when needed)

# Hardcoded installation location
INSTALL_DIR="/home/aldo/dev/01-core-infra"

# Repository configuration
REPO_URL="https://github.com/Aldo-f/01-core-infra.git"
VERSION="main"

# Ensure we're running as 'aldo' user, not root
if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: Do not run this script with sudo/root."
  echo "Run it as your regular user - it will ask for sudo password when needed:"
  echo "  curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash"
  exit 1
fi

# Ensure installation directory exists - update if already present, clone otherwise
if [ -d "$INSTALL_DIR" ]; then
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Repository already exists at $INSTALL_DIR – updating to $VERSION"
    git -C "$INSTALL_DIR" fetch --depth=1 origin "$VERSION"
    git -C "$INSTALL_DIR" reset --hard "origin/$VERSION"
  else
    echo "Directory $INSTALL_DIR exists but is not a git repository – skipping clone."
  fi
else
  echo "Cloning 01-core-infra into $INSTALL_DIR"
  git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$INSTALL_DIR"
fi

# Execute the deployment script (it will use sudo internally for privileged ops)
if [ -f "$INSTALL_DIR/scripts/deploy.sh" ]; then
  exec "$INSTALL_DIR/scripts/deploy.sh" "$@"
else
  echo "ERROR: Deployment script not found at $INSTALL_DIR/scripts/deploy.sh"
  exit 1
fi