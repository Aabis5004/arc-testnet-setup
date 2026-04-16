[README (1).md](https://github.com/user-attachments/files/26740403/README.1.md)
# Arc Local Testnet — One-Click Setup

Run a complete Arc Local Testnet on any machine with a single command.
Includes 5 validators, a full node, and a live block explorer — all on your own machine.

> **Arc** is an open, EVM-compatible Layer-1 blockchain in testnet phase.  
> A local testnet is isolated from the internet — perfect for learning and the [bug bounty program](https://hackerone.com/circle-bbp) ($150–$5,000+).

---

## Quick Start

Pick your platform and run **one command**. That's it.

### 🐧 Linux / Ubuntu / VPS

```bash
curl -sSL https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.sh | bash
```
or 

rm ~/.arc_testnet_setup_done
curl -sSL https://raw.githubusercontent.com/aabis5004/arc-testnet-setup/main/install.sh | bash

### 🪟 Windows (PowerShell as Administrator)

```powershell
irm https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.ps1 | iex
```

> **Windows users:** Right-click the Start menu → *Windows PowerShell (Admin)* → paste the command above.

---

## What happens

| Step | What it does |
|------|-------------|
| Checks dependencies | Installs Docker, Node.js 22, Rust, Foundry v1.4.4 |
| Clones arc-node | Downloads source from `github.com/circlefin/arc-node` |
| Compiles | Builds Arc from Rust source — **first run takes 30–60 min** |
| Launches | Starts 5 validators + full node + block explorer via Docker |

**Second and later runs start in about 60 seconds** — compilation is skipped.

---

## Once it's running

Open these in your browser:

| URL | What it shows |
|-----|--------------|
| `http://localhost` | Block explorer — live blocks and transactions |
| `http://localhost:3000` | Grafana — node metrics |
| `http://localhost:9090` | Prometheus — raw metrics |

### Send test transactions

```bash
cd ~/arc-node && make testnet-load RATE=10 TIME=30
```

Sends 10 transactions per second for 30 seconds. Watch them appear in the explorer in real time.

### Stop the testnet

```bash
cd ~/arc-node && make testnet-down
```

### Full reset (wipe all data)

```bash
cd ~/arc-node && make testnet-down && make testnet-clean
```

---

## System requirements

| | Minimum |
|-|---------|
| RAM | 8 GB (16 GB recommended) |
| CPU | 4 cores |
| Storage | 30 GB free (SSD preferred) |
| OS | Ubuntu 20.04+, Windows 10/11, any VPS Linux |

> ⚠️ VPS: Use at least **CPX32 on Hetzner** (8 GB RAM). Servers with 4 GB RAM will crash during compilation.

---

## VPS tips

**Keep the testnet running after SSH disconnect** — use tmux:

```bash
# Install tmux
sudo apt install -y tmux

# Start a persistent session
tmux new -s arc

# Inside the session, run the installer:
curl -sSL https://raw.githubusercontent.com/YOUR_USER/arc-testnet-setup/main/install.sh | bash

# Detach (keep running): Ctrl+B then D
# Reconnect later:
tmux attach -t arc
```

**Access block explorer remotely:** Open `http://YOUR_SERVER_IP` in your browser.  
Make sure port 80 is open in your firewall settings.

---

## Common errors

<details>
<summary><code>permission denied while trying to connect to Docker</code></summary>

```bash
sudo usermod -aG docker $USER
# Then close and reopen your terminal
```
</details>

<details>
<summary><code>unknown shorthand flag: 'f' in -f</code></summary>

Docker Compose is outdated. Re-run the installer — it updates Compose automatically.
</details>

<details>
<summary><code>Pool overlaps with other one on this address space</code></summary>

```bash
docker network prune -f
```
</details>

<details>
<summary><code>Conflict. The container name is already in use</code></summary>

```bash
cd ~/arc-node && make testnet-down && make testnet-clean && make testnet
```
</details>

<details>
<summary>Block explorer shows "No data"</summary>

```bash
chmod -R 777 ~/arc-node/.quake/localdev/blockscout/
docker restart backend
```

Then refresh the page.
</details>

---

## Useful links

- [Arc Network](https://www.arc.network/)
- [Arc Documentation](https://docs.arc.network/)
- [arc-node source code](https://github.com/circlefin/arc-node)
- [Bug Bounty (HackerOne)](https://hackerone.com/circle-bbp) — $150 to $5,000+
- [Testnet Block Explorer](https://testnet.arcscan.app/)
- [Testnet Faucet](https://faucet.circle.com/)

---

## Files in this repo

| File | Purpose |
|------|---------|
| `install.sh` | One-click installer for Linux / Ubuntu / VPS |
| `install.ps1` | One-click installer for Windows (via WSL) |
| `stop.sh` | Stop the running testnet |

---

*This is a community guide. Arc is currently in testnet phase.*  
*If you get stuck, screenshot the error and ask [Claude](https://claude.ai) for help.*
