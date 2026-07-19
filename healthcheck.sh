#!/bin/bash
# healthcheck.sh — snelle status van docker-containers + systemd units.
# Geroepen via cron (bijv. elk kwartier). Exit 0 = alles up, 1 = iets down.
set -uo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG_DIR="$REPO_DIR/logs"; mkdir -p "$LOG_DIR"
OUT="$LOG_DIR/health-$(date '+%Y%m%d-%H%M').log"
: > "$OUT"

problems=0

echo "=== Docker containers ===" | tee -a "$OUT"
if command -v docker >/dev/null 2>&1; then
  while read -r name status; do
    if [[ "$status" != "Up"* ]]; then
      echo "DOWN: $name ($status)" | tee -a "$OUT"
      problems=$((problems+1))
    else
      echo "OK:   $name ($status)" | tee -a "$OUT"
    fi
  done < <(docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null)
else
  echo "docker niet beschikbaar" | tee -a "$OUT"
fi

echo "=== Systemd (app-*) ===" | tee -a "$OUT"
for svc in /etc/systemd/system/app-*.service; do
  [ -e "$svc" ] || continue
  unit=$(basename "$svc")
  if systemctl is-active --quiet "$unit" 2>/dev/null; then
    echo "OK:   $unit" | tee -a "$OUT"
  else
    echo "DOWN: $unit" | tee -a "$OUT"
    problems=$((problems+1))
  fi
done

# Log-rotatie: health-logs ouder dan 14 dagen wissen
find "$LOG_DIR" -name 'health-*.log' -mtime +14 -delete 2>/dev/null

if [ "$problems" -gt 0 ]; then
  echo "HEALTHCHECK: $problems probleem(en) gevonden" | tee -a "$OUT"
  exit 1
fi
echo "HEALTHCHECK: alle services up" | tee -a "$OUT"
exit 0
