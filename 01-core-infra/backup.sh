#!/bin/bash
# backup.sh — dagelijkse compressie-backup van kritieke data-volumes.
# Geroepen via cron (bijv. 03:00 dagelijks). Schrijft naar ./backups/ (git-ignored).
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$HOME/dev"
BACKUP_DIR="$REPO_DIR/backups"
mkdir -p "$BACKUP_DIR"

STAMP=$(date '+%Y-%m-%d')
RETENTION_DAYS=7

# Bron-paden: (label, pad). Alleen backuppen als het bestaat.
SOURCES=(
  "plex-config|$BASE_DIR/01-core-infra/plex/config"
  "portainer-data|$BASE_DIR/01-core-infra/portainer/data"
  "pihole-etc|$BASE_DIR/04-network-pihole/etc-pihole"
)

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

for entry in "${SOURCES[@]}"; do
  label="${entry%%|*}"
  path="${entry#*|}"
  if [ -e "$path" ]; then
    # veiligheidscheck: geen secrets meenemen
    if find "$path" -maxdepth 2 \( -name 'secrets.json' -o -name '.env' \) 2>/dev/null | grep -q .; then
      log "WARN: $label bevat mogelijk secrets — overslaan voor backup"
      continue
    fi
    out="$BACKUP_DIR/${STAMP}-${label}.tar.gz"
    tar -czf "$out" -C "$(dirname "$path")" "$(basename "$path")" 2>/dev/null \
      && log "Backup OK: $out" \
      || log "WARN: backup $label mislukt"
  else
    log "SKIP: $label ($path bestaat niet)"
  fi
done

# --- Nextcloud specific config (excluded from generic loop due to .env check) ---
NC_DIR="$HOME/dev/06-apps-nextcloud"
if [ -f "$NC_DIR/.env" ]; then
    out="$BACKUP_DIR/${STAMP}-nextcloud-env.tar.gz"
    tar -czf "$out" -C "$NC_DIR" ".env" 2>/dev/null \
        && log "Backup OK: $out" \
        || log "WARN: backup nextcloud-env failed"
fi
if [ -f "$NC_DIR/docker-compose.yml" ]; then
    out="$BACKUP_DIR/${STAMP}-nextcloud-compose.tar.gz"
    tar -czf "$out" -C "$NC_DIR" "docker-compose.yml" 2>/dev/null \
        && log "Backup OK: $out" \
        || log "WARN: backup nextcloud-compose failed"
fi

# Rotatie: oudere dan RETENTION_DAYS verwijderen
find "$BACKUP_DIR" -name '*.tar.gz' -mtime +"$RETENTION_DAYS" -delete 2>/dev/null
log "Rotatie: backups ouder dan $RETENTION_DAYS dagen verwijderd"

log "Backup voltooid"