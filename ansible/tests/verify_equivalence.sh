#!/usr/bin/env bash
# tests/verify_levels.sh - Validate that install.sh equivalents exist post-deployment

set -euo pipefail

# Define expected source paths (relative to repo root)
declare -A EXPECTED=(
  ["install.sh"]="/home/aldo/dev/01-core-infra/install.sh"
  ["backup.sh"]="/home/aldo/dev/01-core-infra/backup.sh"
  ["healthcheck.sh"]="/home/aldo/dev/01-core-infra/healthcheck.sh"
  [".gitignore"]="/home/aldo/dev/01-core-infra/.gitignore"
  ["README.md"]="/home/aldo/dev/01-core-infra/README.md"
  ["01-core-infra/templates/systemd/app-freellmapi.service"]="/home/aldo/dev/01-core-infra/templates/systemd/app-freellmapi.service"
  ["01-core-infra/templates/cron/01-core-infra.cron"]="/home/aldo/dev/01-core-infra/templates/cron/01-core-infra.cron"
)

echo "🔍 Verifying file deployment equivalence..."

for file in "${!EXPECTED[@]}"; do
  expected_path="${EXPECTED[$file]}"
  deployed_path="/home/aldo/dev/01-core-infra/${file}"
  
  if [[ -f "$deployed_path" ]]; then
    echo "✅ Found $file"
    
    # Additional validation: non-empty file
    if [[ ! -s "$deployed_path" ]]; then
      echo "⚠️  $file is empty" >$2
      exit 1
    fi
    
    # Verify same size (basic equivalence)
    src_hash=$(sha256sum "$expected_path" | cut -d' ' -f1)
    dst_hash=$(sha256sum "$deployed_path" | cut -d' ' -f1)
    
    if [[ "$src_hash" != "$dst_hash" ]]; then
      echo "⚠️  $file differs from source"
      exit 1
    fi
  else
    echo "❌ MISSING $file"
    exit 1
  fi
done

echo "🎉 All critical files successfully deployed and validated"
exit 0