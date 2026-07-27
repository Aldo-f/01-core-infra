#!/bin/bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/dev/01-core-infra}"
REPO_URL="${REPO_URL:-https://github.com/aldo/01-core-infra.git}"
VERSION="${VERSION:-main}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  exec "$SCRIPT_DIR/scripts/deploy.sh" "$@"
fi

if [ -d "$INSTALL_DIR" ]; then
  echo "ERROR: $INSTALL_DIR already exists." >&2
  exit 1
fi

if ! git ls-remote --tags --heads "$REPO_URL" "$VERSION" | grep -q .; then
  echo "ERROR: Version $VERSION not found in remote repository." >&2
  exit 1
fi

git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$INSTALL_DIR"

exec "$INSTALL_DIR/install.sh" "$@"
