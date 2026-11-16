#!/usr/bin/env bash
# Isolated Telemetry Agent running on Compute Nodes
# Calculates node-specific resource consumption (RAM allocation & CPU load)

mkdir -p /var/log/minicloud /opt/minicloud/instances /opt/minicloud/stress

# Base capacity configured per virtual compute node (e.g. 4096 MB)
NODE_TOTAL_RAM_MB=4096

while true; do
    # 1. Calculate active instance reservations on THIS compute node
    RESERVED_RAM_MB=0
    for meta in /opt/minicloud/instances/*/meta.json; do
        if [ -f "$meta" ]; then
            INST_RAM=$(jq -r '.ram_mb // 0' "$meta" 2>/dev/null || echo 0)
            RESERVED_RAM_MB=$((RESERVED_RAM_MB + INST_RAM))
        fi
    done

    # 2. Check node-specific simulated / stressed memory overhead
    STRESS_RAM_MB=0
    if [ -f /opt/minicloud/stress/stress_ram.txt ]; then
        STRESS_RAM_MB=$(cat /opt/minicloud/stress/stress_ram.txt 2>/dev/null || echo 0)
    fi

    # 3. Calculate node-specific CPU utilization based on active processes in this node
    # Counts CPU % consumed by processes running exclusively inside this container
    LOCAL_CPU_PCT=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.2f", (s ? s : 0.0)}')
    
    # Add stress load if present
    if [ -f /opt/minicloud/stress/stress_cpu.txt ]; then
        ADD_CPU=$(cat /opt/minicloud/stress/stress_cpu.txt 2>/dev/null || echo 0)
        LOCAL_CPU_PCT=$(python3 -c "print(round($LOCAL_CPU_PCT + $ADD_CPU, 2))" 2>/dev/null || echo "$LOCAL_CPU_PCT")
    fi

    TOTAL_USED_RAM=$((RESERVED_RAM_MB + STRESS_RAM_MB))
    AVAIL_RAM=$((NODE_TOTAL_RAM_MB - TOTAL_USED_RAM))
    if [ $AVAIL_RAM -lt 0 ]; then
        AVAIL_RAM=0
    fi

    ACTIVE_INSTANCES=$(ls -1 /opt/minicloud/instances 2>/dev/null | wc -l)

    cat <<EOF > /opt/minicloud/metrics.json
{
  "node": "$(hostname)",
  "mem_total_mb": $NODE_TOTAL_RAM_MB,
  "mem_available_mb": $AVAIL_RAM,
  "cpu_util_pct": $LOCAL_CPU_PCT,
  "active_instances": $ACTIVE_INSTANCES,
  "status": "healthy"
}
EOF
    sleep 1
done
