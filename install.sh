#!/usr/bin/env bash
set -euo pipefail

# Determine installation directory (defaults to ~/dev/01-core-infra)
INSTALL_DIR="${INSTALL_DIR:-$HOME/dev/01-core-infra}"

# Repository URL and version (defaults to main branch)
REPO_URL="${REPO_URL:-https://github.com/Aldo-f/01-core-infra.git}"
VERSION="${VERSION:-main}"

# Determine where this script lives - works for both direct exec and piped input
if [ -n "${BASH_SOURCE:-}" ]; then
  # BASH_SOURCE available when executed from file
  script_source="${BASH_SOURCE[0]}"
else
  # When script is piped (e.g., curl | bash), BASH_SOURCE is empty
  script_source=""
fi

# Determine script directory
if [ -n "$script_source" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$script_source")" && pwd)"
else
  # For piped input, defer directory resolution until after clone/update
  SCRIPT_DIR=""
fi

# If installation directory exists, update it; otherwise clone it
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

# After clone/update, resolve SCRIPT_DIR to the repo root for deploy.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)" 2>/dev/null || \
  SCRIPT_DIR="$INSTALL_DIR"

# Execute the actual deployment (which runs Ansible)
exec "$SCRIPT_DIR/scripts/deploy.sh" "$@"