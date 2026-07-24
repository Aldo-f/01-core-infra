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

# ============================================================================
# Phase 0a: Basis CLI-tooling (installeer enkel wat ontbreekt)
# ============================================================================
# --- Generieke idempotente installer: 1 check, 1 install-functie, altijd zelfde logging ---
ensure_tool() {
  local label="$1" check_cmd="$2" install_fn="$3"
  if eval "$check_cmd" >/dev/null 2>&1; then
    log "$label al aanwezig — overslaan"
  else
    log "$label ontbreekt — installeren"
    "$install_fn"
    if eval "$check_cmd" >/dev/null 2>&1; then
      log "$label succesvol geïnstalleerd"
    else
      log "WARN: $label installatie lijkt mislukt — controleer handmatig"
    fi
  fi
}

install_git()  { sudo apt-get update -qq && sudo apt-get install -y git; }
install_node() { curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs; }
install_pnpm() { sudo npm install -g pnpm; }
install_bun()     { curl -fsSL https://bun.sh/install | bash; }
install_fvm()     { curl -fsSL https://fvm.app/install.sh | bash; }
install_ollama()  { curl -fsSL https://ollama.com/install.sh | sh; }
install_lmstudio(){ curl -fsSL https://lmstudio.ai/install.sh | bash; }
install_fish()    { sudo apt-get update -qq && sudo apt-get install -y fish; }

log "=== Phase 0a: basis CLI-tooling ==="
ensure_tool "git"        "command -v git"  install_git
ensure_tool "Node.js/npm" "command -v npm" install_node
ensure_tool "pnpm"       "command -v pnpm" install_pnpm
ensure_tool "bun"        "command -v bun"  install_bun
ensure_tool "fvm"        "command -v fvm"  install_fvm
ensure_tool "ollama"     "command -v ollama" install_ollama
ensure_tool "LM Studio"  "command -v lms"  install_lmstudio
ensure_tool "fish"       "command -v fish" install_fish

# --- fish als standaard login-shell (los van ensure_tool: dit is geen "aanwezig ja/nee" check) ---
fish_is_default_shell() {
  local fish_path
  fish_path=$(command -v fish) || return 1
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$fish_path" ]
}

set_fish_as_default_shell() {
  local fish_path
  fish_path=$(command -v fish)
  # chsh weigert een shell die niet in /etc/shells staat
  grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$fish_path" "$USER"
}

if fish_is_default_shell; then
  log "fish is al de standaard shell — overslaan"
else
  set_fish_as_default_shell
  if fish_is_default_shell; then
    log "fish ingesteld als standaard shell (pas actief na volgende login)"
  else
    log "WARN: fish als standaard shell instellen is mislukt — controleer handmatig"
  fi
fi

# --- Ollama cloud-authenticatie via API key (headless-vriendelijk, geen browser/TTY nodig) ---
# 'ollama signin' is een interactieve device-code flow en werkt niet over SSH op een
# headless Pi5. OLLAMA_API_KEY wordt automatisch door de ollama-CLI gebruikt zodra hij
# gezet is — key zelf aanmaken op https://ollama.com/settings/keys (nooit in git zetten).
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

log "=== Ollama cloud-authenticatie ==="
if ensure_ollama_api_key; then
  log "OLLAMA_API_KEY gevonden — cloud-authenticatie actief"
else
  log "WARN: geen OLLAMA_API_KEY gevonden. Maak een key aan op https://ollama.com/settings/keys," \
      "zet 'm in $OLLAMA_API_KEY_FILE (chmod 600) of exporteer OLLAMA_API_KEY in je fish-config" \
      "(bv. 'set -Ux OLLAMA_API_KEY ...'). Zonder key blijven alleen lokale modellen bruikbaar."
fi

# --- Ollama model pull: kies model op basis van beschikbaar RAM ---
# Qwen3.6-tags zijn allemaal 17GB+ (kleinste: 27b-q4_K_M), dus die passen op
# geen enkele Pi5-RAM-configuratie. Onder de ~24GB-grens vallen we terug op
# de kleinere qwen3-familie, die wel 4b/8b-varianten heeft.
RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
log "Gedetecteerd RAM: ${RAM_MB}MB"

select_ollama_model() {
  if   [ "$RAM_MB" -lt 6000  ]; then echo ""                          # te weinig RAM voor een bruikbaar lokaal model
  elif [ "$RAM_MB" -lt 12000 ]; then echo "qwen3:4b"                  # bv. Pi5 8GB
  elif [ "$RAM_MB" -lt 20000 ]; then echo "qwen3:8b"                  # bv. Pi5 16GB
  elif [ "$RAM_MB" -lt 28000 ]; then echo "qwen3.6:27b-q4_K_M"        # kleinste qwen3.6-tag (17GB)
  else                                echo "qwen3.6:35b-a3b-q4_K_M"   # 32GB+: MoE-variant, sneller op CPU
  fi
}

OLLAMA_MODEL=$(select_ollama_model)
if [ -z "$OLLAMA_MODEL" ]; then
  log "WARN: te weinig RAM (<6GB) gedetecteerd — geen lokaal Ollama-model gepulled"
elif ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
  log "Ollama model $OLLAMA_MODEL al lokaal aanwezig — overslaan"
else
  log "Ollama model $OLLAMA_MODEL gekozen voor ${RAM_MB}MB RAM — pullen (kan even duren)"
  ollama pull "$OLLAMA_MODEL" || log "WARN: ollama pull $OLLAMA_MODEL mislukt — controleer handmatig"
fi

# LET OP: npm/bun/fvm installers schrijven PATH-exports naar ~/.bashrc.
# Dit systeem gebruikt fish shell — voeg de paden ook manueel toe aan
# ~/.config/fish/config.fish (bv. via `fish_add_path ~/.bun/bin ~/fvm/default/bin`).

# ============================================================================
# Phase 0b: Docker + Docker Compose (installeer enkel als ze ontbreken)
# ============================================================================
# --- Detecteert of Docker Engine + de Compose v2 plugin aanwezig zijn ---
docker_stack_present() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

# --- Installeert Docker Engine + Compose plugin via de officiële convenience script ---
install_docker_stack() {
  log "Docker en/of Docker Compose ontbreken — installatie starten"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  log "Docker geïnstalleerd (herstart shell/sessie voor group membership zonder sudo)"
}

log "=== Phase 0b: Docker check ==="
if docker_stack_present; then
  log "Docker + Docker Compose al aanwezig — overslaan"
else
  install_docker_stack
  if docker_stack_present; then
    log "Docker + Docker Compose succesvol geïnstalleerd"
  else
    log "WARN: Docker installatie lijkt mislukt — controleer handmatig"
  fi
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
  local src="$INFRA/$name"
  # Voorkom dubbele nesting (bv. .../infra/infra/docker-compose.yml): als de
  # template-map zelf al een submap heeft die overeenkomt met infraSubdir,
  # kopieer dan die submap i.p.v. de hele template-map erin te nesten.
  if [ "$subdir" != "." ] && [ -d "$src/$subdir" ]; then
    src="$src/$subdir"
  fi
  mkdir -p "$target"
  cp -rf "$src/." "$target/"
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

# --- Zorg dat lokale scripts executable zijn (verse clone heeft geen +x) ---
chmod +x "$REPO_DIR/install.sh" "$REPO_DIR/backup.sh" "$REPO_DIR/healthcheck.sh" 2>/dev/null || true
log "Scripts executable gemaakt"

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