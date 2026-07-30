#!/usr/bin/env bash
set -euo pipefail

# Hardcoded installation directory - works for any user and any invocation method
INSTALL_DIR="/home/aldo/dev/01-core-infra"

# Repository configuration - use https for installer to avoid ssh key issues
REPO_URL="https://github.com/Aldo-f/01-core-infra.git"
VERSION="main"

# Ensure installation directory exists - update if already present, clone otherwise
if [ -d "$INSTALL_DIR" ]; then
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Repository already exists at $INSTALL_DIR – checking for updates..."
    git -C "$INSTALL_DIR" fetch --depth=1 origin "$VERSION"

    # Only force-update if local is NOT ahead of remote (no unpushed commits)
    if git -C "$INSTALL_DIR" merge-base --is-ancestor HEAD "origin/$VERSION"; then
        # Local is behind or equal to remote — safe to fast-forward
        git -C "$INSTALL_DIR" reset --hard "origin/$VERSION"
    else
        echo "⚠  Local repository has unpushed commits — skipping git update."
        echo "   (remote may be behind. Run 'git push origin main' to sync first.)"
    fi
  else
    echo "Directory $INSTALL_DIR exists but is not a git repository – skipping clone."
  fi
else
  git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$INSTALL_DIR"
fi

# Execute the deployment script (always located at $INSTALL_DIR/scripts/deploy.sh)
if [ -f "$INSTALL_DIR/scripts/deploy.sh" ]; then
  exec "$INSTALL_DIR/scripts/deploy.sh" "$@"
else
  echo "ERROR: Deployment script not found at $INSTALL_DIR/scripts/deploy.sh"
  exit 1
fi