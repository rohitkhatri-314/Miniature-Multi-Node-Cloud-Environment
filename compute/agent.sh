#!/usr/bin/env bash
# Telemetry Agent running on Compute Nodes
# Exposes local metrics (Free RAM, CPU Load, Active Instances)

mkdir -p /var/log/minicloud /opt/minicloud/instances

# Helper script to export metrics on request or continuously update stats cache
while true; do
    # Total & Available Memory in MB
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
    
    # 1-minute load average normalized by vCPU count
    NPROC=$(nproc)
    LOAD_1M=$(awk '{print $1}' /proc/loadavg)
    CPU_PCT=$(python3 -c "print(round(($LOAD_1M / $NPROC) * 100, 2))" 2>/dev/null || echo "0.0")

    # Count of running workloads on this node
    ACTIVE_INSTANCES=$(ls -1 /opt/minicloud/instances 2>/dev/null | wc -l)

    cat <<EOF > /opt/minicloud/metrics.json
{
  "node": "$(hostname)",
  "mem_total_mb": $MEM_TOTAL,
  "mem_available_mb": $MEM_AVAIL,
  "cpu_util_pct": $CPU_PCT,
  "active_instances": $ACTIVE_INSTANCES,
  "status": "healthy"
}
EOF
    sleep 2
done
