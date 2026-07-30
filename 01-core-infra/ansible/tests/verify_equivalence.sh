#!/usr/bin/env bash
# tests/verify_levels.sh - Validate that install.sh equivalents exist post-deployment

set -euo pipefail

# Define expected source paths (relative to repo root)
declare -A EXPECTED=(
  ["install.sh"]="__CORE_INFRA__/install.sh"
  ["backup.sh"]="__CORE_INFRA__/backup.sh"
  ["healthcheck.sh"]="__CORE_INFRA__/healthcheck.sh"
  [".gitignore"]="__CORE_INFRA__/.gitignore"
  ["README.md"]="__CORE_INFRA__/README.md"
  ["01-core-infra/templates/systemd/app-freellmapi.service"]="__CORE_INFRA__/templates/systemd/app-freellmapi.service"
  ["01-core-infra/templates/cron/01-core-infra.cron"]="__CORE_INFRA__/templates/cron/01-core-infra.cron"
)

echo "🔍 Verifying file deployment equivalence..."

for file in "${!EXPECTED[@]}"; do
  expected_path="${EXPECTED[$file]}"
  deployed_path="__CORE_INFRA__/${file}"
  
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