#!/usr/bin/env python3
"""
Intelligent Cloud Scheduler (OpenStack Nova Filter Scheduler emulation)
Course: Cloud Computing Technologies

Architecture & Workflow:
1. Candidate Discovery: Query all registered compute nodes over management plane.
2. Filtering Phase:
   - RamFilter: Checks if host has sufficient available RAM.
   - CpuFilter: Checks if host CPU utilization is not saturated (< 90%).
3. Weighing Phase:
   Calculates composite host weight:
     weight = (w_ram * normalized_ram) + (w_cpu * normalized_cpu_headroom)
4. Decision & Dispatch:
   Selects host with highest composite weight and logs complete decision matrix.
"""

import sys
import json
import subprocess
import datetime
import os

AUDIT_LOG = "/var/log/minicloud/audit.log"
CONFIG_FILE = "/opt/controller/scheduler.conf"

def log_audit(event_type, message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted_msg = f"[{timestamp}] [{event_type}] {message}"
    print(formatted_msg)
    try:
        os.makedirs(os.path.dirname(AUDIT_LOG), exist_ok=True)
        with open(AUDIT_LOG, "a") as f:
            f.write(formatted_msg + "\n")
    except Exception as e:
        pass

def load_config():
    # Defaults based on Course Slide 37:
    # ram_weight_multiplier = 1.0, cpu_weight_multiplier = 2.0
    config = {
        "compute_nodes": ["192.168.100.21", "192.168.100.22"],
        "node_names": {"192.168.100.21": "compute-01", "192.168.100.22": "compute-02"},
        "ram_weight_multiplier": 1.5,
        "cpu_weight_multiplier": 2.0,
        "max_cpu_threshold": 90.0
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                loaded = json.load(f)
                config.update(loaded)
        except Exception:
            pass
    return config

def fetch_node_metrics(node_ip):
    # Retrieve cached metrics from remote compute node via SSH
    cmd = [
        "ssh", "-o", "ConnectTimeout=2", "-o", "BatchMode=yes",
        f"root@{node_ip}", "cat /opt/minicloud/metrics.json 2>/dev/null || echo '{}'"
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout.strip())
    except Exception as e:
        log_audit("WARNING", f"Failed to poll metrics from {node_ip}: {str(e)}")
    return None

def schedule_instance(instance_name, req_ram_mb, req_cpu_cores=1):
    config = load_config()
    log_audit("SCHEDULER_START", f"Scheduling request for instance '{instance_name}' (Req: RAM={req_ram_mb}MB, vCPUs={req_cpu_cores})")

    candidates = []
    # 1. Fetch Metrics from Nodes
    for ip in config["compute_nodes"]:
        node_name = config["node_names"].get(ip, ip)
        metrics = fetch_node_metrics(ip)
        if not metrics:
            log_audit("FILTER_FAIL", f"Node {node_name} ({ip}) unreachable or metrics unavailable.")
            continue
        candidates.append((ip, node_name, metrics))

    if not candidates:
        log_audit("SCHEDULER_ERROR", "No active compute nodes available in the cluster.")
        return None

    # 2. Filtering Phase (Course Slide 35 - RetryFilter, RamFilter, ComputeFilter)
    filtered_nodes = []
    for ip, node_name, m in candidates:
        avail_ram = m.get("mem_available_mb", 0)
        cpu_util = m.get("cpu_util_pct", 100.0)

        # RamFilter check
        if avail_ram < req_ram_mb:
            log_audit("FILTER_REJECT", f"Node {node_name} rejected by RamFilter (Avail: {avail_ram}MB < Req: {req_ram_mb}MB)")
            continue

        # CpuFilter check
        if cpu_util > config["max_cpu_threshold"]:
            log_audit("FILTER_REJECT", f"Node {node_name} rejected by CpuFilter (CPU Util: {cpu_util}% > Max: {config['max_cpu_threshold']}%)")
            continue

        log_audit("FILTER_PASS", f"Node {node_name} passed all filters (Avail RAM: {avail_ram}MB, CPU: {cpu_util}%)")
        filtered_nodes.append((ip, node_name, m))

    if not filtered_nodes:
        log_audit("SCHEDULER_ERROR", "All nodes were filtered out. Resource exhaustion!")
        return None

    # 3. Weighing Phase (Course Slide 37 - Weight calculation)
    # Formula: weight = (ram_weight * normalized_ram) + (cpu_weight * normalized_cpu_headroom)
    # Higher score = Better candidate
    w_ram = config["ram_weight_multiplier"]
    w_cpu = config["cpu_weight_multiplier"]

    scored_nodes = []
    for ip, node_name, m in filtered_nodes:
        avail_ram = m.get("mem_available_mb", 1)
        tot_ram = m.get("mem_total_mb", 1)
        cpu_util = m.get("cpu_util_pct", 0.0)

        # Normalized RAM metric [0.0 - 1.0] (more free RAM is better)
        norm_ram = min(max(avail_ram / tot_ram, 0.0), 1.0)
        # Normalized CPU headroom [0.0 - 1.0] (lower CPU utilization is better)
        norm_cpu = min(max((100.0 - cpu_util) / 100.0, 0.0), 1.0)

        total_weight = (w_ram * norm_ram) + (w_cpu * norm_cpu)

        log_audit("WEIGHER", f"Node {node_name} Evaluation -> RAM Score: {norm_ram:.3f} (x{w_ram}), CPU Headroom: {norm_cpu:.3f} (x{w_cpu}) => Final Weight: {total_weight:.4f}")
        scored_nodes.append((total_weight, ip, node_name))

    # Sort descending by total_weight
    scored_nodes.sort(key=lambda x: x[0], reverse=True)
    best_weight, best_ip, best_node = scored_nodes[0]

    log_audit("SCHEDULER_DECISION", f"Instance '{instance_name}' placed on '{best_node}' ({best_ip}) with optimal weight {best_weight:.4f}")
    return {"node_name": best_node, "node_ip": best_ip, "weight": best_weight}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: scheduler.py <instance_name> <ram_mb> [cpu_cores]")
        sys.exit(1)

    name = sys.argv[1]
    ram = int(sys.argv[2])
    cpus = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    
    result = schedule_instance(name, ram, cpus)
    if result:
        print(json.dumps(result))
        sys.exit(0)
    else:
        sys.exit(1)
