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
│   └── agent.sh               # Telemetry metric collector (RAM, CPU %)
└── logs/
    └── audit.log              # Central security & placement audit trail
```

---

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
cloud-cli stress compute-01 1500

# Launch another instance; observe placement on compute-02
cloud-cli launch web-02 128

# List all instances across nodes
cloud-cli list

# View placement decision audit logs & security logs
cloud-cli audit

# Remove stress when done
cloud-cli unstress compute-01
```

---

## Verification & Viva Checks

### 1. How to Check SSH RSA Key Pair & Passwordless Access

#### A. Inspect generated 2048-bit RSA keys on `ctrl-node`:
Inside `ctrl-node` (or `docker compose exec ctrl-node bash`):
```bash
ls -la /root/.ssh/
# Confirm 2048-bit key fingerprints
ssh-keygen -l -f /root/.ssh/id_rsa.pub
```

#### B. Verify key distribution on compute nodes:
```bash
docker compose exec compute-01 cat /root/.ssh/authorized_keys
docker compose exec compute-02 cat /root/.ssh/authorized_keys
```

#### C. Test passwordless SSH access:
Inside `ctrl-node`:
```bash
ssh root@192.168.100.21 "hostname && echo 'Passwordless SSH to compute-01 is WORKING!'"
ssh root@192.168.100.22 "hostname && echo 'Passwordless SSH to compute-02 is WORKING!'"
```

---

### 2. How to Check Firewall Rules & Security Groups (`iptables`)

#### A. Inspect active iptables rules on `compute-01`:
```bash
docker compose exec compute-01 iptables -L INPUT -n -v
```
**Key rules to observe:**
- **Management Plane Allowed:** Subnet `192.168.100.0/24` has full access for internal orchestration and telemetry.
- **Guest Traffic Restricted:** Subnet `10.0.1.0/24` allows ICMP (ping) and HTTP (ports 80, 8080).
- **Security Group Isolation (DROP & LOG):** Guest traffic targeting SSH (port 22) is dropped and logged with prefix `[MINICLOUD-SEC-ALERT]`.

#### B. Test unauthorized access drop:
Try connecting to SSH (`port 22`) from the guest network:
```bash
docker compose exec compute-02 curl -m 2 10.0.1.21:22
```
*Expected Output:*
```text
curl: (28) Connection timed out after 2000 milliseconds
```
The packet is immediately blocked by the firewall.

---

### 3. Understanding the Stress Mechanism

When running `cloud-cli stress compute-01 1500`:
- **Memory Stress:** Depletes free RAM on `compute-01` from 4,096 MB down to 2,596 MB.
- **CPU Stress:** Injects an artificial +45% CPU utilization load.
- **Scheduler Adaptation:** The Filter Scheduler computes a lower composite score for `compute-01` ($2.045$) vs. `compute-02` ($3.500$), automatically routing subsequent workload launches to `compute-02`.
- Run `cloud-cli unstress compute-01` to return the node back to baseline.
