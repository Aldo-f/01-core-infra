#!/usr/bin/env bash
set -euo pipefail

# podman-deploy.sh — Create a persistent Debian container with 01-core-infra
# Usage: bash scripts/podman-deploy.sh [container-name]
#        bash scripts/podman-deploy.sh 01-core-infra

NAME="${1:-01-core-infra}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "🚀 Creating persistent container '$NAME' from debian:bookworm..."

podman run -d --name "$NAME" \
  --hostname "$NAME" \
  debian:bookworm \
  bash -c '
set -e

echo "=== 01-core-infra Podman Setup ==="

# 1. Install essentials
apt-get update -qq
apt-get install -y -qq curl sudo git ca-certificates > /dev/null

# 2. Create user aldo (mirrors the Pi environment)
if ! id aldo &>/dev/null; then
    useradd -m -s /bin/bash aldo
    echo "aldo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/aldo
    chmod 440 /etc/sudoers.d/aldo
    echo "  ✅ Created user aldo"
fi

# 3. Run the 01-core-infra installer as aldo
echo "  📦 Running installer..."
sudo -u aldo bash -c '\''
    curl -fsSL https://raw.githubusercontent.com/Aldo-f/01-core-infra/main/install.sh | bash 2>&1 | tail -5
'\'' || echo "  ⚠️  Some tasks may have failed (expected inside container)"

# 4. Show result
echo ""
echo "=== Container ready ==="
echo "  💻 Enter:  podman exec -it -u aldo '\''"'$NAME'"'\'' bash"
echo "  🔧 Tools:  opencode, omo, node, npm, tree, git"
echo ""

# Keep alive
tail -f /dev/null
'

echo ""
log "✅ Container '$NAME' created."
echo ""
echo "   Enter it:  podman exec -it -u aldo $NAME bash"
echo "   Logs:      podman logs $NAME"
echo "   Stop:      podman stop $NAME"
echo "   Remove:    podman rm -f $NAME"
echo ""
