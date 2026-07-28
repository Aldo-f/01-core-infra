#!/usr/bin/env bash
set -euo pipefail

# Robust installer for 01-core-infra
# Works when executed directly, via sudo, or piped from curl
# Usage: curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | sudo bash

# Hardcoded installation location - independent of who runs the script
# This ensures consistency whether run as user 'aldo' or 'root' via sudo
INSTALL_DIR="/home/aldo/dev/01-core-infra"

# Repository configuration
REPO_URL="https://github.com/Aldo-f/01-core-infra.git"
VERSION="main"

# Ensure the target directory exists and is writable
# When run via sudo, we need to ensure /home/aldo has proper permissions
if ! [ -d "$INSTALL_DIR" ]; then
  # Try to create the directory (may fail if /home/aldo doesn't exist or isn't writable by current user)
  mkdir -p "$INSTALL_DIR" 2>/dev/null || true
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

# Execute the deployment script located at $INSTALL_DIR/scripts/deploy.sh
if [ -f "$INSTALL_DIR/scripts/deploy.sh" ]; then
  exec "$INSTALL_DIR/scripts/deploy.sh" "$@"
else
  echo "ERROR: Deployment script not found at $INSTALL_DIR/scripts/deploy.sh"
  echo "Please check if the repository structure is intact"
  exit 1
fi