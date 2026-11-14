# Mini-Cloud Project: Viva & Lab Demo Guide (19th Nov)

This guide is specifically designed for your group's in-lab presentation and viva examination.

---

## 1. Quick In-Lab Demo Sequence (Takes 2 Minutes)

Open your terminal in the project folder (`mini-cloud-project`):

### Step 1: Start the Entire Cloud
```bash
./deploy_cloud.sh
```
*Wait ~10 seconds. The output will show nodes coming online.*

### Step 2: Show Current Cluster Nodes & Live Telemetry
```bash
docker compose exec ctrl-node cloud-cli nodes
```
*Show the examiner: Node status, IP addresses, Free RAM, CPU utilization, and running instance counts.*

### Step 3: Launch Instance 1 (Baseline Scheduling)
```bash
docker compose exec ctrl-node cloud-cli launch web-01 128
```
*Show the examiner the output: The Filter Scheduler evaluates both nodes, scores them, and assigns `web-01` to `compute-01`.*

### Step 4: Inject Load & Demonstrate Intelligent Adaptation
```bash
# Stress compute-01 with 600MB memory load
docker compose exec ctrl-node cloud-cli stress compute-01 600

# Launch another instance requiring 128MB
docker compose exec ctrl-node cloud-cli launch web-02 128
```
*Show the examiner: Because `compute-01` has low free RAM and high load, the scheduler automatically scores `compute-02` higher and routes `web-02` there!*

### Step 5: Show Instance Distribution Across Nodes
```bash
docker compose exec ctrl-node cloud-cli list
```

### Step 6: Show Audit Log & Security Isolation Rules
```bash
# Show real-time scheduling decisions and audit logs
docker compose exec ctrl-node cloud-cli audit

# Show iptables security groups on compute-01
docker compose exec compute-01 iptables -L INPUT -n -v
```

---

## 2. Likely Viva Questions & Ready Answers

### Q1: Why did you choose Track A instead of Track B (Kolla-Ansible)?
**Answer:**  
> "As discussed in the course slides (Slide 8–9), a multi-node OpenStack deployment via Kolla-Ansible requires a minimum of 16 GB to 32 GB RAM across nodes and has heavy resource and storage overhead. Track A allowed us to implement the fundamental IaaS cloud mechanisms from scratch—specifically the exact two-phase Filter Scheduler algorithm taught in lectures, complete with SSH trust, network bridges, and iptables isolation, running reliably with minimal memory overhead."

### Q2: How does your custom scheduler work? Which metrics does it use?
**Answer:**  
> "Our scheduler emulates OpenStack Nova's Filter Scheduler (Slide 35–37). It works in two phases:
> 1. **Filtering Phase**: It applies a `RamFilter` (ensuring host free RAM $\ge$ requested RAM) and a `CpuFilter` (ensuring CPU utilization is $< 90\%$). Nodes failing these checks are eliminated.
> 2. **Weighing Phase**: For all surviving hosts, it calculates a normalized composite weight based on two metrics: **Free RAM percentage** and **CPU headroom percentage**, scaled by configurable multipliers:
> $$\text{weight} = (w_{\text{ram}} \times \text{norm\_ram}) + (w_{\text{cpu}} \times \text{norm\_cpu})$$
> The node with the highest composite score is selected to host the workload."

### Q3: How did you implement network layout and security isolation?
**Answer:**  
> "Following the network security best practices in the course slides (Slides 62–63), we separated the architecture into two distinct subnets:
> 1. **Management Network (`192.168.100.0/24`)**: For node telemetry, SSH key exchange, and scheduler RPC/dispatch.
> 2. **Guest Tenant Network (`10.0.1.0/24`)**: For inter-workload application traffic.
> We implemented security group isolation via `iptables` rules that drop all packets originating from the guest subnet trying to access port 22 (SSH) or management services on the nodes, logging unauthorized access attempts to `/var/log/minicloud/audit.log`."

### Q4: How is inter-node authentication managed?
**Answer:**  
> "We configured non-interactive, passwordless RSA key-based SSH authentication between the controller node and compute nodes. The controller automatically generates the keypair on initial bootstrap and distributes the public key to all compute nodes' `authorized_keys`."
