#!/usr/bin/env bash
set -euo pipefail

# Hardcoded installation directory - works for any user
INSTALL_DIR="/home/aldo/dev/01-core-infra"

# Repository configuration
REPO_URL="https://github.com/Aldo-f/01-core-infra.git"
VERSION="main"

# Determine where this script is located
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # When script is piped into bash, use current directory as fallback
  SCRIPT_DIR="$(pwd)"
fi

# If the installation directory already exists, update it; otherwise clone
if [ -d "$INSTALL_DIR" ]; then
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Repository already exists at $INSTALL_DIR – updating to $VERSION"
    git -C "$INSTALL_DIR" fetch --depth=1 origin "$VERSION"
    git -C "$INSTALL_DIR" reset --hard "origin/$VERSION"
  else
    echo "Directory $INSTALL_DIR exists but is not a git repository – skipping clone."
  fi
else
  git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$INSTALL_DIR"
fi

# Execute the deployment script
exec "$SCRIPT_DIR/scripts/deploy.sh" "$@"