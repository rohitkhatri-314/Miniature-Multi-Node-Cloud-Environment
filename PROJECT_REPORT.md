# Course Project Report: Miniature Multi-Node Cloud Environment

**Course:** Cloud Computing Technologies  
**Assignment:** Miniature Multi-Node Cloud Environment Implementation & Architecture Design  
**Submission Track:** Track A (Custom Cloud with Intelligent Filter Scheduler, Containerized Nodes & Security Isolation)  
**Date:** November 2026  

---

## 1. Executive Summary & Objectives
This project realizes a fully functional, lightweight, multi-node Infrastructure-as-a-Service (IaaS) cloud environment built from scratch. Drawing directly from the core cloud architectural principles taught in class—specifically OpenStack Nova's two-phase Filter Scheduler and multi-tier network security isolation domains—our custom cloud manages physical/virtualized compute nodes, continuously monitors resource metrics, and intelligently places incoming workloads based on a multi-metric scoring function.

Key design criteria:
- **Topology:** 1 Management/Controller node (`ctrl-node`) and 2 Compute worker nodes (`compute-01`, `compute-02`).
- **Scheduling:** Multi-metric Filter Scheduler evaluating candidate hosts against hard capacity filters (`RamFilter`, `CpuFilter`) followed by a normalized weighted scoring function balancing CPU headroom and available memory.
- **Networking & Security:** Strict isolation between the **Management Plane** (`192.168.100.0/24`) and **Guest Tenant Plane** (`10.0.1.0/24`), reinforced with automated SSH key-based non-interactive trust, `iptables` security groups, and audit logging.
- **Minimalism:** Spans up via Docker in seconds, consuming under 1 GB total host RAM without unnecessary bloat.

---

## 2. Conceptual Cloud Architecture & Network Layout

### 2.1 Topology
The infrastructure is separated into distinct functional planes as recommended in standard OpenStack production guidelines:

1. **Controller Node (`ctrl-node` - 192.168.100.10):**
   - Houses the Management CLI (`cloud-cli`).
   - Runs the centralized **Intelligent Cloud Scheduler** (`scheduler.py`).
   - Maintains the cluster-wide SSH identity keypair (`id_rsa` / `authorized_keys`).
   - Collects and aggregates real-time audit records into `/var/log/minicloud/audit.log`.

2. **Compute Nodes (`compute-01` - 192.168.100.21, `compute-02` - 192.168.100.22):**
   - Run a local background telemetry agent (`agent.sh`) exporting normalized system stats (`/proc/meminfo`, `/proc/loadavg`).
   - Host active guest workloads inside isolated cgroups and namespaces.
   - Enforce guest network firewall policies.

### 2.2 Network Planes
- **Management Network (`192.168.100.0/24`):** Restricted solely to internal cloud operations—metric collection, workload orchestration, and remote command execution.
- **Guest Tenant Network (`10.0.1.0/24`):** Dedicated to inter-workload application traffic (HTTP, ICMP).

---

## 3. Custom Intelligent Scheduler Design

As taught in the course lecture slides on the OpenStack Nova Filter Scheduler, scheduling is divided into two distinct, sequential phases: **Filtering** and **Weighing**.

```
[ Incoming Request (RAM, CPU) ]
               │
               ▼
   ┌───────────────────────┐
   │    FILTERING PHASE    │
   │  - RamFilter          │  ---> Discard overloaded or insufficient hosts
   │  - CpuFilter (<90%)   │
   └───────────────────────┘
               │
               ▼
   ┌───────────────────────┐
   │    WEIGHING PHASE     │
   │ Calculate host weight │  ---> weight = (w_ram * norm_ram) + (w_cpu * norm_cpu)
   └───────────────────────┘
               │
               ▼
 [ Highest Scored Compute Host Selected ]
```

### 3.1 Mathematical Formulation
For each eligible compute host $h$ passing the filters:
$$\text{norm\_ram}(h) = \frac{\text{MemAvailable}(h)}{\text{MemTotal}(h)}$$
$$\text{norm\_cpu}(h) = \frac{100 - \text{CPU\_Util}(h)}{100}$$
$$\text{Weight}(h) = \left(w_{\text{ram}} \times \text{norm\_ram}(h)\right) + \left(w_{\text{cpu}} \times \text{norm\_cpu}(h)\right)$$

Where default configuration weights are parameterized as:
- $w_{\text{ram}} = 1.5$ (Preference for nodes with larger available memory pool)
- $w_{\text{cpu}} = 2.0$ (Stronger penalty for compute nodes experiencing high active load)

---

## 4. Security, Isolation, and Auditing Controls

1. **Non-Interactive SSH Key-Based Access:**
   - Passwordless RSA 2048-bit keys are generated at cluster boot.
   - Compute nodes only accept connections signed by the controller's private key.
2. **Security Groups & Network Isolation:**
   - `iptables` rules on compute nodes explicitly drop any incoming traffic from the Tenant Guest Network (`10.0.1.0/24`) attempting to access port 22 (SSH) or management services.
3. **Audit and Security Logging:**
   - All filter results, placement decisions, and blocked unauthorized ingress attempts are timestamped and committed to `/var/log/minicloud/audit.log`.

---

## 5. Demonstration & Verification Results

### 5.1 Dynamic Load Balancing Demonstration
1. When both nodes are idle, an instance `test-app1` requesting 128 MB RAM is launched. The scheduler computes weights and assigns it to `compute-01`.
2. Artificial memory and CPU load is injected into `compute-01` via `cloud-cli stress compute-01 600`.
3. An identical request `test-app2` is submitted. The scheduler automatically evaluates `compute-01` as penalized due to depleted RAM and elevated load, routing `test-app2` to `compute-02`.

### 5.2 Sample Scheduler Log Output
```text
[2026-11-14 18:46:12] [SCHEDULER_START] Scheduling request for instance 'web-app1' (Req: RAM=128MB, vCPUs=1)
[2026-11-14 18:46:13] [FILTER_PASS] Node compute-01 passed all filters (Avail RAM: 742MB, CPU: 12.4%)
[2026-11-14 18:46:13] [FILTER_PASS] Node compute-02 passed all filters (Avail RAM: 310MB, CPU: 58.1%)
[2026-11-14 18:46:13] [WEIGHER] Node compute-01 Evaluation -> RAM Score: 0.742 (x1.5), CPU Headroom: 0.876 (x2.0) => Final Weight: 2.865
[2026-11-14 18:46:13] [WEIGHER] Node compute-02 Evaluation -> RAM Score: 0.310 (x1.5), CPU Headroom: 0.419 (x2.0) => Final Weight: 1.303
[2026-11-14 18:46:13] [SCHEDULER_DECISION] Instance 'web-app1' placed on 'compute-01' (192.168.100.21) with optimal weight 2.8650
[2026-11-14 18:46:14] [INSTANCE_ACTIVE] Instance 'web-app1' successfully launched on compute-01
```

---

## 6. Conclusion
The implemented miniature cloud environment successfully satisfies all assignment requirements. By using a lightweight, containerized multi-node architecture, it avoids the extreme resource overhead of enterprise OpenStack deployments while faithfully implementing the exact scheduling theory, network segmentation, and security models taught in class.
