#!/bin/bash
# ============================================================
#  Arc Local Testnet — One-Click Installer (v3)
#  Linux / Ubuntu / VPS
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.sh | bash
# ============================================================

set -e

G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'
R='\033[0;31m'; W='\033[0m'; BOLD='\033[1m'

step() { echo -e "\n${C}${BOLD}──── $* ${W}"; }
ok()   { echo -e "${G}  ✓  $*${W}"; }
warn() { echo -e "${Y}  ⚠  $*${W}"; }
fail() { echo -e "${R}  ✗  $*${W}"; exit 1; }

# ── Helper: run with sudo only if not already root ────────────
s() { if [ "$(id -u)" = "0" ]; then "$@"; else sudo "$@"; fi; }

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
  # No nodejs/npm here — NodeSource nodejs includes npm (apt npm conflicts)
  step "1/8  Installing base packages..."
  s apt-get update -y -qq 2>/dev/null
  s apt-get install -y git make libclang-dev curl 2>/dev/null
  ok "Base packages ready"

  # ── Step 2: Docker ──────────────────────────────────────────────
  step "2/8  Installing Docker..."
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

  # ── Step 3: Node.js 22 via NodeSource ───────────────────────────
  # NodeSource bundles npm — NEVER install npm via apt separately
  step "3/8  Checking Node.js..."
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

  # ── Step 4: Clone arc-node ───────────────────────────────────────
  step "4/8  Cloning arc-node..."
  if [ ! -d "$HOME/arc-node" ]; then
    cd ~
    git clone https://github.com/circlefin/arc-node || fail "Clone failed. Check internet."
  else
    ok "arc-node already cloned — skipping"
  fi
  cd ~/arc-node
  git submodule update --init --recursive
  ok "Repository ready"

  # ── Step 5: Foundry v1.4.4 ───────────────────────────────────────
  step "5/8  Installing Foundry v1.4.4..."
  export FOUNDRY_DIR="$HOME/.foundry"
  export PATH="$HOME/.foundry/bin:$PATH"
  if [ ! -f "$HOME/.foundry/bin/foundryup" ]; then
    curl -sSfL https://foundry.paradigm.xyz | bash 2>/dev/null || true
  fi
  "$HOME/.foundry/bin/foundryup" -i v1.4.4 2>/dev/null || warn "Foundry version issue — continuing"
  ok "Foundry ready"

  # ── Step 6: Docker Compose v2.24.0 ───────────────────────────────
  # Use HOME dir to avoid permission issues, then move with sudo
  step "6/8  Updating Docker Compose..."
  COMPOSE_CURRENT=$(docker compose version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
  if [ "$COMPOSE_CURRENT" = "2.24.0" ]; then
    ok "Docker Compose 2.24.0 already installed — skipping"
  else
    COMPOSE_TMP="$HOME/docker-compose-tmp"
    curl -sSL \
      "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
      -o "$COMPOSE_TMP" || fail "Failed to download Docker Compose"
    s mkdir -p /usr/local/lib/docker/cli-plugins
    s mv "$COMPOSE_TMP" /usr/local/lib/docker/cli-plugins/docker-compose
    s chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  fi
  ok "Docker Compose ready"

  # ── Step 7: Rust ─────────────────────────────────────────────────
  step "7/8  Installing Rust..."
  if command -v rustc &>/dev/null; then
    ok "Rust already installed — skipping"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
  fi
  source "$HOME/.cargo/env" 2>/dev/null || true
  ok "Rust ready"

  # ── Step 8: npm install ──────────────────────────────────────────
  step "8/8  Installing npm dependencies..."
  cd ~/arc-node
  npm install --quiet 2>/dev/null
  ok "npm dependencies ready"

  touch "$DONE_FLAG"
  echo ""
  echo -e "${G}${BOLD}  ✓  All dependencies installed!${W}"

else
  echo -e "${G}  ✓  Already set up — skipping install${W}"
fi

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
echo -e "  ${G}  → Block Explorer:  http://localhost${W}"
echo -e "  ${G}  → Grafana:         http://localhost:3000${W}"
echo -e "  ${G}  → Prometheus:      http://localhost:9090${W}"
echo ""
echo -e "  Press ${BOLD}Ctrl+C${W} to stop."
echo ""

export PATH="$HOME/.foundry/bin:$HOME/.cargo/bin:$PATH"
source "$HOME/.cargo/env" 2>/dev/null || true
cd ~/arc-node
sg docker -c "make testnet" 2>/dev/null || sudo make testnet
