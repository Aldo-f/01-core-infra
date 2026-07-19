#!/bin/bash
set -euo pipefail

# ============================================================================
# 01-core-infra installer — de ENIGE manier om de ~/dev boom te (re)construeren.
# Alles wat hier staat, komt uit templates/infra/<component>/ (de Source of Truth).
# Na een `./install.sh` staat de hele ~/dev boom weer correct.
# ============================================================================

# --- Omgevingsvariabelen ---
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$HOME/dev"
CORE_INFRA="$BASE_DIR/01-core-infra"
TEMPLATES="$REPO_DIR/templates"
INFRA="$TEMPLATES/infra"

# --- Logging (naar logs/, niet in repo-root) ---
mkdir -p "$REPO_DIR/logs"
LOG_FILE="$REPO_DIR/logs/install-$(date '+%Y%m%d-%H%M%S').log"
: > "$LOG_FILE"
function log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "STARTING DEPLOYMENT (REPO_DIR=$REPO_DIR)"

# --- Phase 0: zorg dat ~/dev/install.sh proxy bestaat (self-heal) ---
ROOT_PROXY="$BASE_DIR/install.sh"
if [ ! -f "$ROOT_PROXY" ]; then
  cat > "$ROOT_PROXY" <<'PROXY'
#!/bin/bash
# Proxy script in ~/dev/ — stuurt door naar de repository install script.
exec "$(dirname "$0")/01-core-infra/install.sh" "$@"
PROXY
  chmod +x "$ROOT_PROXY"
  log "Aangemaakt: $ROOT_PROXY (proxy naar 01-core-infra/install.sh)"
fi

# --- Git profiel ---
git config --global user.email "aldo.fieuw@gmail.com"
git config --global user.name "Aldo"

# --- JSONC parser (stript // comments en /* */ blokken, dan json) ---
parse_manifest() {
  python3 - "$1" <<'PY'
import sys, re, json
raw = open(sys.argv[1], 'r').read()
# block comments
raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
# line comments (niet binnen strings — simpel, voldoende voor ons manifest)
raw = re.sub(r'(?<!:)//[^\n]*', '', raw)
print(json.dumps(json.loads(raw)))
PY
}

# --- Runtime-doel bepalen uit component-naam (prefix → pad) ---
runtime_target() {
  local name="$1"
  case "$name" in
    01-core-*) echo "$CORE_INFRA/${name#01-core-}" ;;
    04-network-*) echo "$BASE_DIR/$name" ;;
    *) echo "$BASE_DIR/$name" ;;   # 02-*, 06-* zijn eigen repo's
  esac
}

# --- Pure-infra component: volledige 1:1 kopie van template-map ---
deploy_pure() {
  local name="$1"
  local src="$INFRA/$name"
  local dst
  dst=$(runtime_target "$name")
  mkdir -p "$dst"
  cp -rf "$src/." "$dst/"
  log "Deployed pure-infra $name -> $dst"
}

# --- Manifest-repo: clone/pull + checkout + infra naar infraSubdir ---
deploy_repo() {
  local name="$1" remote="$2" ref="$3" subdir="$4"
  local dst="$BASE_DIR/$name"
  if [ ! -d "$dst/.git" ]; then
    if [ ! -d "$dst" ]; then
      log "Cloning $name <- $remote"
      git clone -q "$remote" "$dst" || { log "ERROR: clone $name mislukt (bestaat de repo op GitHub?)"; return 1; }
    else
      log "WARN: $dst bestaat zonder .git — overslaan (geen repo-identiteit)"
      return 1
    fi
  else
    log "Pulling $name"
    git -C "$dst" pull -q 2>/dev/null || log "WARN: pull $name mislukt (offline?)"
  fi
  # checkout van de gewenste ref
  git -C "$dst" checkout -q "$ref" 2>/dev/null || log "WARN: checkout $ref voor $name mislukt"
  # infra-bestanden kopieren naar infraSubdir (raakt .git niet)
  local target="$dst/$subdir"
  mkdir -p "$target"
  cp -rf "$INFRA/$name/." "$target/"
  log "Deployed repo $name (ref=$ref) -> $target"
}

# ============================================================================
# 1. PURE-INFRA COMPONENTEN (volledig uit template)
# ============================================================================
log "=== Phase 1: pure-infra componenten ==="
for d in "$INFRA"/*/; do
  name=$(basename "$d")
  # skip als het een manifest-repo is (staat in repos.manifest.jsonc)
  case "$name" in
    02-ai-llm-infra-sync|06-apps-thuis-v4|06-apps-thuis-v5|02-ai-freellmapi) continue ;;
  esac
  deploy_pure "$name"
done

# ============================================================================
# 2. MANIFEST-REPO'S (git clone/pull + checkout + infra subdir)
# ============================================================================
log "=== Phase 2: manifest-repo's ==="
MANIFEST="$INFRA/repos.manifest.jsonc"
if [ -f "$MANIFEST" ]; then
  # lees elke repo-entry via python3 (json array)
  entry_count=$(parse_manifest "$MANIFEST" | python3 -c "import sys,json;print(len(json.load(sys.stdin)['repos']))")
  for i in $(seq 0 $((entry_count - 1))); do
    read -r name remote ref subdir < <(parse_manifest "$MANIFEST" | python3 -c "
import sys,json
r=json.load(sys.stdin)['repos'][$i]
print(r['name'], r['remote'], r['checkout']['ref'], r.get('infraSubdir','.'))
")
    deploy_repo "$name" "$remote" "$ref" "$subdir"
  done
else
  log "WARN: geen repos.manifest.jsonc — repo's overgeslagen"
fi

# ============================================================================
# 3. SYSTEMD UNITS (app- prefix) — via passwordless-sudo helper
# ============================================================================
log "=== Phase 3: systemd units ==="
if ls "$TEMPLATES"/systemd/app-*.service >/dev/null 2>&1; then
  # deploy de privileged helper + sudoers (eénmalig, vraagt sudo bij eerste keer)
  sudo install -m 0755 "$TEMPLATES/systemd/app-deploy-systemd" /usr/local/bin/app-deploy-systemd
  if [ -f "$TEMPLATES/systemd/01-core-infra-deploy.sudoers" ]; then
    sudo install -m 0440 "$TEMPLATES/systemd/01-core-infra-deploy.sudoers" /etc/sudoers.d/01-core-infra-deploy
    log "sudoers geïnstalleerd (/etc/sudoers.d/01-core-infra-deploy)"
  fi
  # de wrapper draait zonder wachtwoord (NOPASSWD in sudoers)
  sudo /usr/local/bin/app-deploy-systemd
  log "Systemd units deployed"
else
  log "Geen systemd templates"
fi

# --- Cron jobs (backup + healthcheck) via passwordless-sudo helper ---
if [ -f "$TEMPLATES/cron/01-core-infra.cron" ]; then
  sudo install -m 0755 "$TEMPLATES/systemd/app-install-cron" /usr/local/bin/app-install-cron
  sudo /usr/local/bin/app-install-cron
  log "Cron jobs geïnstalleerd (/etc/cron.d/01-core-infra)"
fi

# ============================================================================
# 4. MESH SYNC ENGINE (bun sync)
# ============================================================================
log "=== Phase 4: mesh sync ==="
SYNC_DIR="$BASE_DIR/02-ai-llm-infra-sync"
if [ -d "$SYNC_DIR" ]; then
  ( cd "$SYNC_DIR" && bun install >/dev/null 2>&1; bun sync ) || log "WARN: bun sync mislukt"
  log "Mesh sync uitgevoerd"
else
  log "WARN: sync dir $SYNC_DIR niet aanwezig — werd hij gecloned?"
fi

# ============================================================================
# KLAAR
# ============================================================================
log "Deployment completed successfully"
log "Log: $LOG_FILE"
echo "--- Deployment voltooid (zie $LOG_FILE) ---"
