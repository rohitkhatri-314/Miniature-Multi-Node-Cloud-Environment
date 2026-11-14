# Miniature Multi-Node Cloud Environment (Track A)

Developed for **Cloud Computing Technologies** Course Assignment.

## Project Structure
```
mini-cloud-project/
├── docker-compose.yml         # Defines 3-node topology & dual networks (mgmt & guest)
├── Dockerfile.node            # Base container image for cloud nodes
├── entrypoint.sh              # Node bootstrap, SSH keys distribution, iptables firewall
├── deploy_cloud.sh            # 1-click cluster deployment script
├── verify_cluster.sh          # End-to-end automated verification test suite
├── architecture_diagram.svg   # High-resolution architectural diagram
├── PROJECT_REPORT.md          # Comprehensive written report ready for submission
├── VIVA_PREP_AND_DEMO_GUIDE.md# 2-minute live demo guide & Viva Q&A cheat sheet
├── controller/
│   ├── cloud-cli              # Nova-style cloud management CLI
│   ├── scheduler.py           # Multi-metric Filter Scheduler (Nova algorithm)
│   └── scheduler.conf         # Configurable weights (w_ram, w_cpu, thresholds)
├── compute/
│   └── agent.sh               # Telemetry metric collector (/proc/meminfo, loadavg)
└── logs/
    └── audit.log              # Central security & placement audit trail
```

## Quick Start (Deploy in 15 seconds)

### 1. Start the Cloud Environment
```bash
chmod +x deploy_cloud.sh verify_cluster.sh
./deploy_cloud.sh
```

### 2. Run Automated Verification Tests
```bash
./verify_cluster.sh
```

### 3. Interactive Management via `cloud-cli`
Enter the controller node:
```bash
docker compose exec -it ctrl-node bash
```
Inside the controller, run:
```bash
# Check status and metrics of all compute nodes
cloud-cli nodes

# Launch an instance (invokes Filter Scheduler)
cloud-cli launch web-01 128

# Simulate load on compute-01 to demonstrate dynamic rerouting
cloud-cli stress compute-01 600

# Launch another instance; observe placement on compute-02
cloud-cli launch web-02 128

# List all instances across nodes
cloud-cli list

# View placement decision audit logs & security logs
cloud-cli audit
```
