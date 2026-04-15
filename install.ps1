# ============================================================
#  Arc Local Testnet — One-Click Installer for Windows
#
#  Usage (run in PowerShell as Administrator):
#    irm https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.ps1 | iex
# ============================================================

$Host.UI.RawUI.WindowTitle = "Arc Local Testnet Setup"
$ErrorActionPreference = "Continue"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║      Arc Local Testnet  —  Windows Installer     ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param($num, $msg)
    Write-Host ""
    Write-Host "  [$num] " -ForegroundColor DarkCyan -NoNewline
    Write-Host $msg -ForegroundColor White
}
function Write-OK   { param($msg) Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Info { param($msg) Write-Host "     $msg" -ForegroundColor Gray }
function Write-Warn { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  ✗  $msg" -ForegroundColor Red }
function Write-Sep  { Write-Host "" ; Write-Host "  ────────────────────────────────────────────────" -ForegroundColor DarkGray }

Write-Banner
Write-Host "  First run takes 30–60 minutes to compile." -ForegroundColor Yellow
Write-Host "  Your PC will be under heavy load. This is normal." -ForegroundColor Yellow
Write-Sep

# ── Must run as admin ─────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Err "Administrator privileges required."
    Write-Host ""
    Write-Info "Please re-run this command in PowerShell as Administrator:"
    Write-Info "  Right-click the Start menu → 'Windows PowerShell (Admin)'"
    Write-Info "  Then paste the install command again."
    Read-Host "`n  Press Enter to exit"
    exit 1
}
Write-OK "Running as Administrator"

# ── Step 1: WSL ───────────────────────────────────────────────
Write-Step "1/4" "Checking WSL (Windows Subsystem for Linux)..."

$wslReady = $false
try {
    $null = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) { $wslReady = $true }
} catch {}

if (-not $wslReady) {
    Write-Info "Installing WSL..."
    wsl --install --no-distribution
    Write-Host ""
    Write-Warn "══════════════════════════════════════════════════"
    Write-Warn "  RESTART REQUIRED"
    Write-Warn "  After restarting, open PowerShell as Admin and"
    Write-Warn "  run the install command again to continue."
    Write-Warn "══════════════════════════════════════════════════"
    Read-Host "`n  Press Enter to exit"
    exit 0
}
Write-OK "WSL is ready"

# ── Step 2: Ubuntu ────────────────────────────────────────────
Write-Step "2/4" "Checking Ubuntu..."

$ubuntuReady = $false
try {
    $distros = (wsl --list --quiet 2>&1) -join " "
    if ($distros -match "Ubuntu") { $ubuntuReady = $true }
} catch {}

if (-not $ubuntuReady) {
    Write-Info "Installing Ubuntu inside WSL..."
    wsl --install -d Ubuntu
    Write-Host ""
    Write-Warn "Ubuntu installed. If a window opened asking for a username"
    Write-Warn "and password, complete that first."
    Write-Warn "Then run the install command again to continue."
    Read-Host "`n  Press Enter to exit"
    exit 0
}
Write-OK "Ubuntu is ready"

# ── Step 3: Download and run bash installer inside WSL ─────────
Write-Step "3/4" "Downloading Linux installer..."

$BASH_URL = "https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.sh"
$BASH_SCRIPT = @"
#!/bin/bash
set -e
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; W='\033[0m'; BOLD='\033[1m'
step()  { echo -e "\n\${C}\${BOLD}---- \$* \${W}"; }
ok()    { echo -e "\${G}  v  \$*\${W}"; }
warn()  { echo -e "\${Y}  !  \$*\${W}"; }
fail()  { echo -e "\${R}  x  \$*\${W}"; exit 1; }

DONE_FLAG="\$HOME/.arc_testnet_setup_done"

if [ ! -f "\$DONE_FLAG" ]; then

  step "1/8  Installing system packages..."
  sudo apt-get update -y -qq 2>/dev/null
  sudo apt-get install -y git docker.io make nodejs npm libclang-dev 2>/dev/null
  ok "System packages installed"

  step "2/8  Cloning arc-node..."
  if [ ! -d "\$HOME/arc-node" ]; then
    cd ~; git clone https://github.com/circlefin/arc-node || fail "Clone failed"
  else
    ok "Already cloned"
  fi
  cd ~/arc-node
  git submodule update --init --recursive
  ok "Repository ready"

  step "3/8  Configuring Docker..."
  sudo service docker start 2>/dev/null || true
  sudo usermod -aG docker "\$USER"
  ok "Docker configured"

  step "4/8  Upgrading Node.js to v22..."
  sudo npm install -g n -q 2>/dev/null
  sudo n 22 2>/dev/null
  hash -r 2>/dev/null || true
  ok "Node.js v22 ready"

  step "5/8  Installing Foundry v1.4.4..."
  export FOUNDRY_DIR="\$HOME/.foundry"
  curl -sSfL https://foundry.paradigm.xyz | bash 2>/dev/null || true
  export PATH="\$HOME/.foundry/bin:\$PATH"
  "\$HOME/.foundry/bin/foundryup" -i v1.4.4 2>/dev/null || warn "Foundry may already exist"
  ok "Foundry ready"

  step "6/8  Updating Docker Compose..."
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  sudo curl -sSL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  ok "Docker Compose v2.24.0 ready"

  step "7/8  Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
  source "\$HOME/.cargo/env" 2>/dev/null || true
  ok "Rust ready"

  step "8/8  Installing npm dependencies..."
  cd ~/arc-node && npm install --quiet 2>/dev/null
  ok "npm dependencies ready"

  touch "\$DONE_FLAG"
  echo ""
  echo -e "\${G}\${BOLD}  All dependencies installed!\${W}"

else
  ok "Dependencies already installed -- skipping"
fi

echo ""
echo -e "\${C}================================================\${W}"
echo -e "\${G}\${BOLD}   Arc Local Testnet -- Starting              \${W}"
echo -e "\${C}================================================\${W}"
echo ""
echo -e "  \${Y}First run: 30-60 min (Rust compilation)\${W}"
echo -e "  \${Y}Later runs: ~60 seconds\${W}"
echo ""
echo -e "  Open in your browser when ready:"
echo -e "  \${G}  -> http://localhost       (Block Explorer)\${W}"
echo -e "  \${G}  -> http://localhost:3000  (Grafana)\${W}"
echo ""
echo -e "  Press Ctrl+C to stop the testnet."
echo ""

export PATH="\$HOME/.foundry/bin:\$HOME/.cargo/bin:\$PATH"
source "\$HOME/.cargo/env" 2>/dev/null || true
cd ~/arc-node
sg docker -c "make testnet" 2>/dev/null || sudo make testnet
"@

$tmpScript = "$env:TEMP\arc_install.sh"
[System.IO.File]::WriteAllText($tmpScript, $BASH_SCRIPT, [System.Text.Encoding]::UTF8)
$wslPath = (wsl -d Ubuntu wslpath -u ($tmpScript -replace '\\','\\')) 2>&1
$wslPath = $wslPath.Trim()
Write-OK "Installer ready"

Write-Step "4/4" "Running inside WSL / Ubuntu..."
Write-Host ""
Write-Info "The Linux terminal below is running your setup."
Write-Info "Do NOT close this window."
Write-Host ""

wsl -d Ubuntu bash -c "chmod +x '$wslPath' && bash '$wslPath'"
$exitCode = $LASTEXITCODE

Write-Sep
if ($exitCode -eq 0) {
    Write-OK "Testnet stopped cleanly."
    Write-Info "Run this command again anytime to restart:"
    Write-Info "  irm https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.ps1 | iex"
} else {
    Write-Err "Something went wrong (exit code: $exitCode)."
    Write-Info "Screenshot the error and ask Claude for help."
    Write-Info "Docs: https://github.com/YOUR_USER/arc-testnet-setup"
}

Read-Host "`n  Press Enter to close"
