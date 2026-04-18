#!/bin/bash
# ============================================================
#  Arc Local Testnet — One-Click Installer (v9 — battle tested & community verified)
#  Linux / Ubuntu / VPS
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.sh | bash
#
#  All fixes from real community testing:
#  v2: nodejs/npm apt conflict — NodeSource nodejs includes npm
#  v3: Docker Compose permission — download to HOME then sudo mv
#  v4: Foundry PATH lost in subshells — write to all profile files
#  v5: PATH not passed into sg docker subshell — inject explicitly
#  v6: yarn GPG blocks apt-get update — remove before update
#  v6: hardhat bus error — pre-compile to cache solc binary first
#  v6: blockscout.yaml missing from v0.6.0 tag — fetch from main
#  v7: backend.env + frontend.env missing — fetch from main
#  v8: Apache2 stealing port 80 — stop and disable it
#  v8: db.env missing — fetch from main
#  v8: fetch ALL config-blockscout files at once from GitHub API
# ============================================================

set -e

G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'
R='\033[0;31m'; W='\033[0m'; BOLD='\033[1m'

step() { echo -e "\n${C}${BOLD}──── $* ${W}"; }
ok()   { echo -e "${G}  ✓  $*${W}"; }
warn() { echo -e "${Y}  ⚠  $*${W}"; }
fail() { echo -e "${R}  ✗  $*${W}"; exit 1; }

# Run with sudo only if not already root
s() { if [ "$(id -u)" = "0" ]; then "$@"; else sudo "$@"; fi; }

MAIN="https://raw.githubusercontent.com/circlefin/arc-node/main"
DEPLOY="$HOME/arc-node/deployments"

clear
echo -e "${C}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║        Arc Local Testnet  —  Installer           ║"
echo "  ║        github.com/YOUR_USER/arc-testnet-setup    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${W}"
echo -e "  ${Y}First run takes 30–60 minutes to compile.${W}"
echo -e "  ${Y}Your machine will be under heavy load. This is normal.${W}"
echo ""

DONE_FLAG="$HOME/.arc_testnet_setup_done"

if [ ! -f "$DONE_FLAG" ]; then

  # ── Step 1: Base packages ───────────────────────────────────────
  # Remove broken yarn repo — blocks apt-get update with GPG error
  # No nodejs/npm here — NodeSource nodejs already includes npm
  step "1/9  Installing base packages..."
  s rm -f /etc/apt/sources.list.d/yarn.list \
          /etc/apt/sources.list.d/dl_yarnpkg_com_debian.list 2>/dev/null || true
  s apt-get update -y -qq 2>/dev/null
  s apt-get install -y git make libclang-dev curl 2>/dev/null
  ok "Base packages ready"

  # ── Step 2: Docker ──────────────────────────────────────────────
  step "2/9  Installing Docker..."
  if command -v docker &>/dev/null; then
    ok "Docker already installed — skipping"
  else
    s apt-get remove -y containerd 2>/dev/null || true
    s apt-get install -y docker.io 2>/dev/null || \
      curl -fsSL https://get.docker.com | s sh
  fi
  s service docker start 2>/dev/null || true
  s usermod -aG docker "$USER" 2>/dev/null || true
  ok "Docker ready"

  # ── Step 3: Stop Apache2 — it steals port 80 ────────────────────
  # Apache2 is installed by default on some Ubuntu setups and blocks
  # the block explorer from binding to port 80
  step "3/9  Checking for port 80 conflicts..."
  if s service apache2 status &>/dev/null; then
    s service apache2 stop 2>/dev/null || true
    s systemctl disable apache2 2>/dev/null || true
    ok "Apache2 stopped and disabled (was blocking port 80)"
  else
    ok "No Apache2 conflict — port 80 is free"
  fi

  # ── Step 4: Node.js 22 via NodeSource ───────────────────────────
  # NodeSource bundles npm — NEVER install npm via apt separately
  step "4/9  Checking Node.js..."
  NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo "0")
  if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
    ok "Node.js $(node --version) already installed — skipping"
  else
    s apt-get remove -y nodejs npm 2>/dev/null || true
    s apt-get autoremove -y 2>/dev/null || true
    curl -fsSL https://deb.nodesource.com/setup_22.x | s bash - 2>/dev/null
    s apt-get install -y nodejs 2>/dev/null
    ok "Node.js $(node --version) ready"
  fi
  command -v npm &>/dev/null || fail "npm not found after Node.js install"
  ok "npm $(npm --version) ready"

  # ── Step 5: Clone arc-node ───────────────────────────────────────
  step "5/9  Cloning arc-node..."
  if [ ! -d "$HOME/arc-node" ]; then
    cd ~
    git clone https://github.com/circlefin/arc-node || fail "Clone failed. Check internet."
  else
    ok "arc-node already cloned — skipping"
  fi
  cd ~/arc-node
  git submodule update --init --recursive
  ok "Repository ready"

  # ── Step 6: Fetch ALL missing deployment files ───────────────────
  # These files exist on main branch but NOT on the v0.6.0 tag.
  # Without them docker compose fails with exit codes 14/15.
  # Fetching all known missing files at once — no more whack-a-mole.
  step "6/9  Fetching missing deployment config files..."

  fetch() {
    local path="$1"
    local dest="$DEPLOY/$2"
    mkdir -p "$(dirname "$dest")"
    if [ ! -f "$dest" ] || head -1 "$dest" 2>/dev/null | grep -q "404\|Not Found"; then
      curl -sSL "$MAIN/deployments/$path" -o "$dest" \
        && echo "     fetched: $2" \
        || warn "Could not fetch: $2"
    fi
  }

  # blockscout docker compose — missing from v0.6.0 tag
  fetch "blockscout.yaml" "blockscout.yaml"

  # blockscout env files — missing from v0.6.0 tag
  fetch "monitoring/config-blockscout/backend.env" \
        "monitoring/config-blockscout/backend.env"
  fetch "monitoring/config-blockscout/db.env" \
        "monitoring/config-blockscout/db.env"
  fetch "monitoring/config-blockscout/frontend/frontend.env" \
        "monitoring/config-blockscout/frontend/frontend.env"

  ok "Deployment config files ready"

  # ── Step 7: Foundry v1.4.4 ───────────────────────────────────────
  step "7/9  Installing Foundry v1.4.4..."
  export FOUNDRY_DIR="$HOME/.foundry"
  export PATH="$HOME/.foundry/bin:$PATH"
  if [ ! -f "$HOME/.foundry/bin/foundryup" ]; then
    curl -sSfL https://foundry.paradigm.xyz | bash 2>/dev/null || true
    export PATH="$HOME/.foundry/bin:$PATH"
  fi
  "$HOME/.foundry/bin/foundryup" -i v1.4.4 2>/dev/null || warn "Foundry version issue — continuing"
  # Write to all profile files — sg docker subshell does not load .bashrc
  for PROFILE in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc"; do
    grep -q ".foundry/bin" "$PROFILE" 2>/dev/null || \
      echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> "$PROFILE" 2>/dev/null || true
  done
  ok "Foundry ready"

  # ── Step 8: Docker Compose v2.24.0 ───────────────────────────────
  # Download to HOME first (no sudo needed), then sudo mv into place
  step "8/9  Updating Docker Compose..."
  COMPOSE_CURRENT=$(docker compose version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
  if [ "$COMPOSE_CURRENT" = "2.24.0" ]; then
    ok "Docker Compose 2.24.0 already installed — skipping"
  else
    curl -sSL \
      "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
      -o "$HOME/dc-tmp" || fail "Failed to download Docker Compose"
    s mkdir -p /usr/local/lib/docker/cli-plugins
    s mv "$HOME/dc-tmp" /usr/local/lib/docker/cli-plugins/docker-compose
    s chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  fi
  ok "Docker Compose ready"

  # ── Step 9: Rust + npm + pre-compile ─────────────────────────────
  # Pre-compiling downloads and caches the solc binary.
  # Skipping this causes a bus error on first make testnet run.
  step "9/9  Installing Rust, npm dependencies, pre-compiling..."

  if ! command -v rustc &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
  else
    ok "Rust already installed — skipping"
  fi
  source "$HOME/.cargo/env" 2>/dev/null || true
  ok "Rust ready"

  cd ~/arc-node
  npm install --quiet 2>/dev/null
  ok "npm dependencies ready"

  export PATH="$HOME/.foundry/bin:$PATH"
  echo "     Pre-compiling contracts (downloads solc — takes ~1 min)..."
  npx hardhat --config hardhat.config.ts compile 2>/dev/null \
    && ok "Contracts pre-compiled" \
    || warn "Pre-compile had warnings — continuing"

  touch "$DONE_FLAG"
  echo ""
  echo -e "${G}${BOLD}  ✓  All dependencies installed!${W}"

else
  echo -e "${G}  ✓  Already set up — skipping install${W}"
fi

# ── Always run on every start ─────────────────────────────────
# Stop Apache2 — steals port 80 from block explorer
s service apache2 stop 2>/dev/null || true

# Fix data directory permissions — Docker runs as different UID
# blockscout: needs 777 for dets/queue_storage (eacces error)
# prometheus: needs ./data/prometheus to exist and be writable  
# grafana: runs as user 501, needs to own ./data/grafana
mkdir -p "$HOME/arc-node/.quake/localdev/blockscout/dets" \
         "$HOME/arc-node/.quake/localdev/blockscout/logs" \
         "$HOME/arc-node/.quake/localdev/blockscout/db" \
         "$HOME/arc-node/.quake/monitoring/data/prometheus" \
         "$HOME/arc-node/.quake/monitoring/data/grafana" 2>/dev/null || true
s chmod -R 777 "$HOME/arc-node/.quake/localdev/blockscout/" \
               "$HOME/arc-node/.quake/monitoring/data/" 2>/dev/null || true

# ── Show WSL IP for browser access ───────────────────────────
WSL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

# ── Launch testnet ────────────────────────────────────────────
echo ""
echo -e "${C}══════════════════════════════════════════════════${W}"
echo -e "${G}${BOLD}        Arc Local Testnet — Starting              ${W}"
echo -e "${C}══════════════════════════════════════════════════${W}"
echo ""
echo -e "  ${Y}First run: 30–60 min (compiling Rust code)${W}"
echo -e "  ${Y}Later runs: ~60 seconds${W}"
echo ""
echo -e "  Open in your browser when ready:"
echo -e "  ${G}  → Block Explorer:  http://$WSL_IP${W}"
echo -e "  ${G}  → Grafana:         http://$WSL_IP:3000${W}"
echo -e "  ${G}  → Prometheus:      http://$WSL_IP:9090${W}"
echo ""
echo -e "  ${Y}Note: Use the IP above, not localhost (WSL2 requirement)${W}"
echo ""
echo -e "  Press ${BOLD}Ctrl+C${W} to stop."
echo ""

# Inject full PATH into sg docker subshell
# sg opens a new shell that does NOT load .bashrc
FULL_PATH="$HOME/.foundry/bin:$HOME/.cargo/bin:$PATH"
source "$HOME/.cargo/env" 2>/dev/null || true

cd ~/arc-node

if sg docker true 2>/dev/null; then
  sg docker -c "export PATH=\"$FULL_PATH\" && cd $HOME/arc-node && make testnet"
else
  export PATH="$FULL_PATH"
  sudo -E make testnet
fi
