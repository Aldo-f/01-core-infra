#!/usr/bin/env bash
set -euo pipefail

# Determine installation directory (defaults to ~/dev/01-core-infra)
INSTALL_DIR="${INSTALL_DIR:-$HOME/dev/01-core-infra}"

# Repository URL and version (defaults to main branch)
REPO_URL="${REPO_URL:-https://github.com/Aldo-f/01-core-infra.git}"
VERSION="${VERSION:-main}"

# Determine where this script lives
if [ -n "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Fallback when script is piped into bash (e.g., via curl)
  SCRIPT_DIR="$(pwd)"
fi

# If we're already inside a git repository, update it instead of cloning
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

# Execute the actual deployment (which runs Ansible)
exec "$SCRIPT_DIR/scripts/deploy.sh" "$@"