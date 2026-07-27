#!/usr/bin/env bash
set -euo pipefail

# 01-core-infra installer — pure-Ansible editie.
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== Initializing Ansible-based deployment ==="

# Zorg dat Ansible en Git aanwezig zijn
if ! command -v ansible-playbook >/dev/null 2>&1; then
    log "Ansible ontbreekt — installeren..."
    sudo apt-get update -qq
    sudo apt-get install -y ansible git
fi

# Uitvoeren playbook
cd "$(dirname "$0")/../ansible"
log "=== Running Ansible playbook ==="
ansible-playbook -i inventories/local.yml playbooks/site.yml

log "=== Deployment completed successfully ==="
