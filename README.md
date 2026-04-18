[README (2).md](https://github.com/user-attachments/files/26855038/README.2.md)
# Arc Local Testnet — One-Click Setup

Run a complete Arc Local Testnet on any machine with a single command.
Includes 5 validators, a full node, a block explorer, Grafana, and Prometheus — all on your own machine.

Arc is an open, EVM-compatible Layer-1 blockchain in testnet phase. A local testnet is isolated from the internet — perfect for learning and the [bug bounty program](https://hackerone.com/circle-bbp) ($150–$5,000+).

---

## Quick Start

### Linux / Ubuntu / VPS

First run (installs everything and launches):
```bash
curl -sSL https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.sh | bash
```

To re-run setup from scratch:
```bash
rm -f ~/.arc_testnet_setup_done
curl -sSL https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.sh | bash
```

### Windows (PowerShell as Administrator)

```powershell
irm https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.ps1 | iex
```

Right-click the Start menu, select "Windows PowerShell (Admin)", then paste the command above.

---

## What happens

| Step | What it does |
|------|-------------|
| Checks dependencies | Installs Docker, Node.js 22, Rust, Foundry v1.4.4 |
| Fetches missing files | Downloads config files missing from the v0.6.0 tag |
| Fixes permissions | Creates data directories and sets correct permissions |
| Clones arc-node | Downloads source from `github.com/circlefin/arc-node` |
| Pre-compiles | Compiles Solidity contracts and caches the solc binary |
| Compiles | Builds Arc from Rust source — first run takes 30-60 min |
| Launches | Starts 5 validators + full node + block explorer + monitoring |

Second and later runs start in about 60 seconds — compilation is skipped.

---

## Once it's running

Open these in your browser:

| URL | What it shows |
|-----|--------------|
| `http://localhost` | Block explorer — live blocks and transactions |
| `http://localhost:3000` | Grafana — node metrics and dashboards |
| `http://localhost:9090` | Prometheus — raw metrics |

Windows users: if `localhost` does not work, use your WSL IP instead. Run `hostname -I` in Ubuntu to find it, then open `http://<that IP>` in your Windows browser.

---

## Managing the testnet

Stop the testnet:
```bash
cd ~/arc-node && make testnet-down
```

Full reset (wipes all data):
```bash
cd ~/arc-node && make testnet-down && make testnet-clean
```

Send test transactions (10 tx/sec for 30 seconds):
```bash
cd ~/arc-node && make testnet-load RATE=10 TIME=30
```

---

## Checking logs

```bash
# Consensus layer (validator)
docker logs validator1_cl --tail 50

# Execution layer (validator)
docker logs validator1_el --tail 50

# Block explorer backend
docker logs backend --tail 50

# Grafana
docker logs grafana --tail 20

# Prometheus
docker logs prometheus --tail 20

# Follow logs live (Ctrl+C to stop)
docker logs validator1_cl -f
```

---

## System requirements

| | Minimum |
|-|---------|
| RAM | 8 GB (16 GB recommended) |
| CPU | 4 cores |
| Storage | 30 GB free (SSD preferred) |
| OS | Ubuntu 20.04+, Windows 10/11, any VPS Linux |

VPS recommendation: use at least CPX32 on Hetzner (8 GB RAM, around 14 EUR/month). Servers with 4 GB RAM crash during compilation.

---

## VPS tips

Keep the testnet running after SSH disconnect using tmux:

```bash
# Install tmux
sudo apt install -y tmux

# Start a persistent session
tmux new -s arc

# Run the installer inside the session
curl -sSL https://raw.githubusercontent.com/Aabis5004/arc-testnet-setup/main/install.sh | bash

# Detach and keep running: press Ctrl+B then D
# Reconnect later:
tmux attach -t arc
```

Access the block explorer remotely by opening `http://YOUR_SERVER_IP` in your browser. Make sure port 80 is open in your firewall or security group settings.

---

## Common errors

**permission denied while trying to connect to Docker**
```bash
sudo usermod -aG docker $USER
# Close and reopen your terminal
```

**unknown shorthand flag: 'f' in -f**

Docker Compose is outdated. Re-run the installer — it updates Compose automatically.

**Pool overlaps with other one on this address space**
```bash
docker network prune -f
```

**Conflict. The container name is already in use**
```bash
cd ~/arc-node && make testnet-down && make testnet-clean && make testnet
```

**Block explorer shows "No data"**
```bash
sudo chmod -R 777 ~/arc-node/.quake/localdev/blockscout/
docker restart backend
```

Then refresh the page.

**Grafana or Prometheus not starting**
```bash
sudo mkdir -p ~/arc-node/.quake/monitoring/data/prometheus
sudo mkdir -p ~/arc-node/.quake/monitoring/data/grafana
sudo chmod -R 777 ~/arc-node/.quake/monitoring/data/
docker restart prometheus grafana
```

**localhost not working on Windows**

Find your WSL IP and use that instead:
```bash
hostname -I | awk '{print $1}'
```

Then open `http://<that IP>` in your Windows browser.

---

## Files in this repo

| File | Purpose |
|------|---------|
| `install.sh` | One-click installer for Linux / Ubuntu / VPS |
| `install.ps1` | One-click installer for Windows (via WSL) |
| `stop.sh` | Stop the running testnet |

---

## Useful links

- [Arc Network](https://www.arc.network/)
- [Arc Documentation](https://docs.arc.network/)
- [arc-node source code](https://github.com/circlefin/arc-node)
- [Bug Bounty (HackerOne)](https://hackerone.com/circle-bbp) — $150 to $5,000+
- [Testnet Block Explorer](https://testnet.arcscan.app/)
- [Testnet Faucet](https://faucet.circle.com/)

---

*This is a community guide based on real testing. Arc is currently in testnet phase.*
*If you get stuck, screenshot the error and ask [Claude](https://claude.ai) for help.*
