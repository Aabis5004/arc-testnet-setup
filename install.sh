#!/bin/bash
# ============================================================
#  Arc Local Testnet — One-Click Installer
#  Linux / Ubuntu / VPS
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.sh | bash
# ============================================================

set -e

# ── Colors ────────────────────────────────────────────────────
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'
R='\033[0;31m'; B='\033[1;34m'; W='\033[0m'; BOLD='\033[1m'

step()    { echo -e "\n${C}${BOLD}──── $* ${W}"; }
ok()      { echo -e "${G}  ✓  $*${W}"; }
warn()    { echo -e "${Y}  ⚠  $*${W}"; }
fail()    { echo -e "${R}  ✗  $*${W}"; exit 1; }
info()    { echo -e "     ${W}$*"; }

# ── Banner ────────────────────────────────────────────────────
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

# ── OS check ─────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  fail "macOS is not supported. Use Linux or Windows (WSL)."
fi

# ── Skip setup if already done ────────────────────────────────
DONE_FLAG="$HOME/.arc_testnet_setup_done"

if [ ! -f "$DONE_FLAG" ]; then

  step "1/8  Checking system packages..."
  if command -v apt-get &>/dev/null; then
    apt-get update -y -qq 2>/dev/null || sudo apt-get update -y -qq
    apt-get install -y git docker.io make nodejs npm libclang-dev 2>/dev/null \
      || sudo apt-get install -y git docker.io make nodejs npm libclang-dev
    ok "System packages installed"
  else
    fail "This script requires apt (Ubuntu/Debian). For other distros, install manually."
  fi

  step "2/8  Cloning arc-node repository..."
  if [ ! -d "$HOME/arc-node" ]; then
    cd ~
    git clone https://github.com/circlefin/arc-node || fail "Clone failed. Check your internet connection."
  else
    ok "arc-node already cloned — skipping"
  fi
  cd ~/arc-node
  git submodule update --init --recursive
  ok "Repository ready"

  step "3/8  Configuring Docker..."
  service docker start 2>/dev/null || sudo service docker start 2>/dev/null || true
  usermod -aG docker "$USER" 2>/dev/null || sudo usermod -aG docker "$USER" 2>/dev/null || true
  ok "Docker configured"

  step "4/8  Upgrading Node.js to v22..."
  npm install -g n -q 2>/dev/null || sudo npm install -g n -q
  n 22 2>/dev/null || sudo n 22
  hash -r 2>/dev/null || true
  ok "Node.js v22 ready"

  step "5/8  Installing Foundry v1.4.4..."
  export FOUNDRY_DIR="$HOME/.foundry"
  curl -sSfL https://foundry.paradigm.xyz | bash 2>/dev/null || true
  export PATH="$HOME/.foundry/bin:$PATH"
  "$HOME/.foundry/bin/foundryup" -i v1.4.4 2>/dev/null \
    || foundryup -i v1.4.4 2>/dev/null \
    || warn "Foundry install issue — may already be present"
  ok "Foundry ready"

  step "6/8  Updating Docker Compose to v2.24.0..."
  mkdir -p /usr/local/lib/docker/cli-plugins 2>/dev/null \
    || sudo mkdir -p /usr/local/lib/docker/cli-plugins
  curl -sSL \
    "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null \
    || sudo curl -sSL \
    "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null \
    || sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  ok "Docker Compose v2.24.0 ready"

  step "7/8  Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
  source "$HOME/.cargo/env" 2>/dev/null || true
  ok "Rust ready"

  step "8/8  Installing npm dependencies..."
  cd ~/arc-node
  npm install --quiet 2>/dev/null
  ok "npm dependencies ready"

  touch "$DONE_FLAG"
  echo ""
  echo -e "${G}${BOLD}  ✓  All dependencies installed!${W}"

else
  echo -e "${G}  ✓  Dependencies already installed — skipping setup${W}"
fi

# ── Launch ────────────────────────────────────────────────────
echo ""
echo -e "${C}══════════════════════════════════════════════════${W}"
echo -e "${G}${BOLD}        Arc Local Testnet — Starting              ${W}"
echo -e "${C}══════════════════════════════════════════════════${W}"
echo ""
echo -e "  ${Y}First run compiles Rust code (30–60 min).${W}"
echo -e "  ${Y}Subsequent runs start in ~60 seconds.${W}"
echo ""
echo -e "  When ready, open in your browser:"
echo -e "  ${G}  → Block Explorer:  http://localhost${W}"
echo -e "  ${G}  → Grafana:         http://localhost:3000${W}"
echo -e "  ${G}  → Prometheus:      http://localhost:9090${W}"
echo ""
echo -e "  Press ${BOLD}Ctrl+C${W} to stop the testnet."
echo ""

export PATH="$HOME/.foundry/bin:$HOME/.cargo/bin:$PATH"
source "$HOME/.cargo/env" 2>/dev/null || true

cd ~/arc-node
sg docker -c "make testnet" 2>/dev/null || sudo make testnet
