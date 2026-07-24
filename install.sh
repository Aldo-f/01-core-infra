#!/bin/bash
set -euo pipefail

# ============================================================================
# 01-core-infra installer — the ONLY way to (re)build the ~/dev tree.
# Everything here comes from templates/infra/<component>/ (the Source of Truth).
# After running `./install.sh`, the whole ~/dev tree is correct again.
# ============================================================================

# --- Environment variables ---
REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$HOME/dev"
CORE_INFRA="$BASE_DIR/01-core-infra"
TEMPLATES="$REPO_DIR/templates"
INFRA="$TEMPLATES/infra"

# --- PATH fix: this script runs via `bash install.sh` (non-interactive), which
# never sources ~/.bashrc or fish config. Curl-installed tools (bun, fvm, lms)
# only update those rc files, so without this, every run of the script fails
# to detect them and reinstalls them again. Exporting their known install
# locations here makes detection work regardless of shell/session. ---
export PATH="$HOME/.bun/bin:$HOME/fvm/bin:$HOME/.lmstudio/bin:$PATH"

# --- Logging (into logs/, not the repo root) ---
mkdir -p "$REPO_DIR/logs"
LOG_FILE="$REPO_DIR/logs/install-$(date '+%Y%m%d-%H%M%S').log"
: > "$LOG_FILE"
function log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "STARTING DEPLOYMENT (REPO_DIR=$REPO_DIR)"

# --- Phase 0: ensure ~/dev/install.sh proxy exists (self-heal) ---
ROOT_PROXY="$BASE_DIR/install.sh"
if [ ! -f "$ROOT_PROXY" ]; then
  cat > "$ROOT_PROXY" <<'PROXY'
#!/bin/bash
# Proxy script in ~/dev/ — forwards to the repository install script.
exec "$(dirname "$0")/01-core-infra/install.sh" "$@"
PROXY
  chmod +x "$ROOT_PROXY"
  log "Created: $ROOT_PROXY (proxy to 01-core-infra/install.sh)"
fi

# ============================================================================
# Phase 0a: Base CLI tooling (only installs what's missing)
# ============================================================================
# --- Generic idempotent installer: 1 check, 1 install function, consistent logging ---
ensure_tool() {
  local label="$1" check_cmd="$2" install_fn="$3"
  if eval "$check_cmd" >/dev/null 2>&1; then
    log "$label already present — skipping"
  else
    log "$label missing — installing"
    "$install_fn"
    if eval "$check_cmd" >/dev/null 2>&1; then
      log "$label installed successfully"
    else
      log "WARN: $label installation appears to have failed — check manually"
    fi
  fi
}

install_git()      { sudo apt-get update -qq && sudo apt-get install -y git; }
install_node()     { curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; }
install_pnpm()     { sudo npm install -g pnpm; }
install_bun()      { curl -fsSL https://bun.sh/install | bash; }
install_fvm()      { curl -fsSL https://fvm.app/install.sh | bash; }
install_ollama()   { curl -fsSL https://ollama.com/install.sh | sh; }
install_lmstudio() { curl -fsSL https://lmstudio.ai/install.sh | bash; }  # installs llmster, LM Studio's headless daemon, managed via the `lms` CLI
install_fish()     { sudo apt-get update -qq && sudo apt-get install -y fish; }

log "=== Phase 0a: base CLI tooling ==="
ensure_tool "git"         "command -v git"    install_git
ensure_tool "Node.js/npm" "command -v npm"    install_node
ensure_tool "pnpm"        "command -v pnpm"   install_pnpm
ensure_tool "bun"         "command -v bun"    install_bun
ensure_tool "fvm"         "command -v fvm"    install_fvm
ensure_tool "ollama"      "command -v ollama" install_ollama
ensure_tool "LM Studio"   "command -v lms"    install_lmstudio
ensure_tool "fish"        "command -v fish"   install_fish

# --- fish as the default login shell (separate from ensure_tool: this isn't a plain "present yes/no" check) ---
fish_is_default_shell() {
  local fish_path
  fish_path=$(command -v fish) || return 1
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$fish_path" ]
}

set_fish_as_default_shell() {
  local fish_path
  fish_path=$(command -v fish)
  # chsh refuses a shell that isn't listed in /etc/shells
  grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$fish_path" "$USER"
}

if fish_is_default_shell; then
  log "fish is already the default shell — skipping"
else
  set_fish_as_default_shell
  if fish_is_default_shell; then
    log "fish set as default shell (takes effect after next login)"
  else
    log "WARN: setting fish as default shell failed — check manually"
  fi
fi

# --- Ollama cloud authentication via API key (headless-friendly, no browser/TTY needed) ---
# 'ollama signin' is an interactive device-code flow and doesn't work over SSH on a
# headless Pi5. OLLAMA_API_KEY is picked up automatically by the ollama CLI once it's
# set — create the key yourself at https://ollama.com/settings/keys (never commit it).
OLLAMA_API_KEY_FILE="$HOME/.config/ollama/api_key"

ensure_ollama_api_key() {
  if [ -n "${OLLAMA_API_KEY:-}" ]; then
    return 0
  fi
  if [ -f "$OLLAMA_API_KEY_FILE" ]; then
    OLLAMA_API_KEY=$(cat "$OLLAMA_API_KEY_FILE")
    export OLLAMA_API_KEY
    [ -n "$OLLAMA_API_KEY" ] && return 0
  fi
  return 1
}

log "=== Ollama cloud authentication ==="
if ensure_ollama_api_key; then
  log "OLLAMA_API_KEY found — cloud authentication active"
else
  log "WARN: no OLLAMA_API_KEY found. Create a key at https://ollama.com/settings/keys," \
      "put it in $OLLAMA_API_KEY_FILE (chmod 600), or export OLLAMA_API_KEY in your fish config" \
      "(e.g. 'set -Ux OLLAMA_API_KEY ...'). Without a key, only local models will work."
fi

# --- Ollama model pull: pick a model based on available RAM ---
# All qwen3.6 tags are 17GB+ (smallest: 27b-q4_K_M), so none of them fit any
# Pi5 RAM configuration. Below the ~24GB mark we fall back to the smaller
# qwen3 family, which does have 4b/8b variants.
RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
log "Detected RAM: ${RAM_MB}MB"

select_ollama_model() {
  if   [ "$RAM_MB" -lt 6000  ]; then echo ""                          # not enough RAM for a usable local model
  elif [ "$RAM_MB" -lt 12000 ]; then echo "qwen3:4b"                  # e.g. Pi5 8GB
  elif [ "$RAM_MB" -lt 20000 ]; then echo "qwen3:8b"                  # e.g. Pi5 16GB
  elif [ "$RAM_MB" -lt 28000 ]; then echo "qwen3.6:27b-q4_K_M"        # smallest qwen3.6 tag (17GB)
  else                                echo "qwen3.6:35b-a3b-q4_K_M"   # 32GB+: MoE variant, faster on CPU
  fi
}

OLLAMA_MODEL=$(select_ollama_model)
if [ -z "$OLLAMA_MODEL" ]; then
  log "WARN: less than 6GB RAM detected — no local Ollama model pulled"
elif ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
  log "Ollama model $OLLAMA_MODEL already present locally — skipping"
else
  log "Ollama model $OLLAMA_MODEL selected for ${RAM_MB}MB RAM — pulling (may take a while)"
  ollama pull "$OLLAMA_MODEL" || log "WARN: ollama pull $OLLAMA_MODEL failed — check manually"
fi

# ============================================================================
# Phase 0b: Docker + Docker Compose (only installs if missing)
# ============================================================================
# --- Detects whether Docker Engine + the Compose v2 plugin are present ---
docker_stack_present() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

# --- Installs Docker Engine + Compose plugin via the official convenience script ---
install_docker_stack() {
  log "Docker and/or Docker Compose missing — starting installation"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  log "Docker installed (restart shell/session for group membership without sudo)"
}

log "=== Phase 0b: Docker check ==="
if docker_stack_present; then
  log "Docker + Docker Compose already present — skipping"
else
  install_docker_stack
  if docker_stack_present; then
    log "Docker + Docker Compose installed successfully"
  else
    log "WARN: Docker installation appears to have failed — check manually"
  fi
fi

# --- Git profile ---
git config --global user.email "aldo.fieuw@gmail.com"
git config --global user.name "Aldo"

# --- JSONC parser (strips // comments and /* */ blocks, then parses JSON) ---
parse_manifest() {
  python3 - "$1" <<'PY'
import sys, re, json
raw = open(sys.argv[1], 'r').read()
# block comments
raw = re.sub(r'/\*.*?\*/', '', raw, flags=re.S)
# line comments (not inside strings — simple, good enough for our manifest)
raw = re.sub(r'(?<!:)//[^\n]*', '', raw)
print(json.dumps(json.loads(raw)))
PY
}

# --- Determine the runtime destination from a component name (prefix -> path) ---
runtime_target() {
  local name="$1"
  case "$name" in
    01-core-*) echo "$CORE_INFRA/${name#01-core-}" ;;
    04-network-*) echo "$BASE_DIR/$name" ;;
    *) echo "$BASE_DIR/$name" ;;   # 02-*, 06-* are their own repos
  esac
}

# --- Pure-infra component: full 1:1 copy of the template folder ---
deploy_pure() {
  local name="$1"
  local src="$INFRA/$name"
  local dst
  dst=$(runtime_target "$name")
  mkdir -p "$dst"
  cp -rf "$src/." "$dst/"
  log "Deployed pure-infra $name -> $dst"
}

# --- Manifest repo: clone/pull + checkout + infra copied into infraSubdir ---
deploy_repo() {
  local name="$1" remote="$2" ref="$3" subdir="$4"
  local dst="$BASE_DIR/$name"
  if [ ! -d "$dst/.git" ]; then
    if [ ! -d "$dst" ]; then
      log "Cloning $name <- $remote"
      git clone -q "$remote" "$dst" || { log "ERROR: clone $name failed (does the repo exist on GitHub?)"; return 1; }
    else
      log "WARN: $dst exists without .git — skipping (no repo identity)"
      return 1
    fi
  else
    log "Pulling $name"
    git -C "$dst" pull -q 2>/dev/null || log "WARN: pull $name failed (offline?)"
  fi
  # checkout the desired ref
  git -C "$dst" checkout -q "$ref" 2>/dev/null || log "WARN: checkout $ref for $name failed"
  # copy infra files into infraSubdir (doesn't touch .git)
  local target="$dst/$subdir"
  local src="$INFRA/$name"
  # Avoid double nesting (e.g. .../infra/infra/docker-compose.yml): if the
  # template folder itself already has a subfolder matching infraSubdir,
  # copy from that subfolder instead of nesting the whole template folder in it.
  if [ "$subdir" != "." ] && [ -d "$src/$subdir" ]; then
    src="$src/$subdir"
  fi
  mkdir -p "$target"
  cp -rf "$src/." "$target/"
  log "Deployed repo $name (ref=$ref) -> $target"
}

# ============================================================================
# 1. PURE-INFRA COMPONENTS (fully from template)
# ============================================================================
log "=== Phase 1: pure-infra components ==="
for d in "$INFRA"/*/; do
  name=$(basename "$d")
  # skip if it's a manifest repo (listed in repos.manifest.jsonc)
  case "$name" in
    02-ai-llm-infra-sync|06-apps-thuis-v4|06-apps-thuis-v5|02-ai-freellmapi) continue ;;
  esac
  deploy_pure "$name"
done

# ============================================================================
# 2. MANIFEST REPOS (git clone/pull + checkout + infra subdir)
# ============================================================================
log "=== Phase 2: manifest repos ==="
MANIFEST="$INFRA/repos.manifest.jsonc"
if [ -f "$MANIFEST" ]; then
  # read each repo entry via python3 (json array)
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
  log "WARN: no repos.manifest.jsonc — repos skipped"
fi

# --- Make sure local scripts are executable (a fresh clone has no +x) ---
chmod +x "$REPO_DIR/install.sh" "$REPO_DIR/backup.sh" "$REPO_DIR/healthcheck.sh" 2>/dev/null || true
log "Scripts made executable"

# ============================================================================
# 3. SYSTEMD UNITS (app- prefix) — via passwordless-sudo helper
# ============================================================================
log "=== Phase 3: systemd units ==="
if ls "$TEMPLATES"/systemd/app-*.service >/dev/null 2>&1; then
  # deploy the privileged helper + sudoers (one-time, asks for sudo the first time)
  sudo install -m 0755 "$TEMPLATES/systemd/app-deploy-systemd" /usr/local/bin/app-deploy-systemd
  if [ -f "$TEMPLATES/systemd/01-core-infra-deploy.sudoers" ]; then
    sudo install -m 0440 "$TEMPLATES/systemd/01-core-infra-deploy.sudoers" /etc/sudoers.d/01-core-infra-deploy
    log "sudoers installed (/etc/sudoers.d/01-core-infra-deploy)"
  fi
  # the wrapper runs without a password (NOPASSWD in sudoers)
  sudo /usr/local/bin/app-deploy-systemd
  log "Systemd units deployed"
else
  log "No systemd templates"
fi

# --- Cron jobs (backup + healthcheck) via passwordless-sudo helper ---
if [ -f "$TEMPLATES/cron/01-core-infra.cron" ]; then
  sudo install -m 0755 "$TEMPLATES/systemd/app-install-cron" /usr/local/bin/app-install-cron
  sudo /usr/local/bin/app-install-cron
  log "Cron jobs installed (/etc/cron.d/01-core-infra)"
fi

# ============================================================================
# 4. MESH SYNC ENGINE (bun sync)
# ============================================================================
log "=== Phase 4: mesh sync ==="
SYNC_DIR="$BASE_DIR/02-ai-llm-infra-sync"
if [ -d "$SYNC_DIR" ]; then
  ( cd "$SYNC_DIR" && bun install >/dev/null 2>&1; bun sync ) || log "WARN: bun sync failed"
  log "Mesh sync executed"
else
  log "WARN: sync dir $SYNC_DIR not present — was it cloned?"
fi

# ============================================================================
# DONE
# ============================================================================
log "Deployment completed successfully"
log "Log: $LOG_FILE"
echo "--- Deployment complete (see $LOG_FILE) ---"