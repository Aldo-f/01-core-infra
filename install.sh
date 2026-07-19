#!/bin/bash
set -e
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$HOME/dev"
CORE_INFRA="$BASE_DIR/01-core-infra"
TARGET_DIR="$BASE_DIR/02-ai-llm-infra-sync"

echo "--- Deploying infra vanuit $REPO_DIR naar $CORE_INFRA ---"
mkdir -p "$CORE_INFRA/portainer" "$CORE_INFRA/plex/config" "$CORE_INFRA/plex/transcode" \
         "$CORE_INFRA/qbittorrent/config" "$CORE_INFRA/qbittorrent/downloads" \
         "$CORE_INFRA/cockpit" "$BASE_DIR/04-network-traefik" "$BASE_DIR/04-network-pihole" \
         "$BASE_DIR/04-network-wireguard/config" "$TARGET_DIR"

cp -f "$REPO_DIR/templates/docker/portainer.yml" "$CORE_INFRA/portainer/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/plex.yml" "$CORE_INFRA/plex/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/qbittorrent.yml" "$CORE_INFRA/qbittorrent/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/cockpit.yml" "$CORE_INFRA/cockpit/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/traefik.yml" "$BASE_DIR/04-network-traefik/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/pihole.yml" "$BASE_DIR/04-network-pihole/docker-compose.yml"
cp -f "$REPO_DIR/templates/docker/wireguard.yml" "$BASE_DIR/04-network-wireguard/docker-compose.yml"
cp -f "$REPO_DIR/templates/sync/sync-configs.ts" "$TARGET_DIR/sync-configs.ts"

sudo cp -f "$REPO_DIR/templates/systemd/"* /etc/systemd/system/
sudo systemctl daemon-reload
echo "--- Deployment succesvol ---"
