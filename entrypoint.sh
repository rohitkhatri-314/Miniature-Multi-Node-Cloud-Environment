#!/usr/bin/env bash
set -e

ROLE="$1"
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Synchronize shared SSH keys
if [ "$ROLE" == "controller" ]; then
    if [ ! -f /root/.ssh_shared/id_rsa ]; then
        echo "[BOOTSTRAP] Generating SSH Keypair on Controller..."
        mkdir -p /root/.ssh_shared
        ssh-keygen -t rsa -b 2048 -f /root/.ssh_shared/id_rsa -N "" -q
    fi
    cp /root/.ssh_shared/id_rsa /root/.ssh/id_rsa
    cp /root/.ssh_shared/id_rsa.pub /root/.ssh/id_rsa.pub
    cat /root/.ssh_shared/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/id_rsa
    chmod 644 /root/.ssh/id_rsa.pub
    chmod 600 /root/.ssh/authorized_keys

    # Disable Host key checking for automated cluster commands
    cat <<EOF > /root/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
    chmod 600 /root/.ssh/config

    echo "[BOOTSTRAP] Setting up Controller CLI environment..."
    ln -sf /opt/controller/cloud-cli /usr/local/bin/cloud-cli
    chmod +x /opt/controller/cloud-cli 2>/dev/null || true
    chmod +x /opt/controller/scheduler.py 2>/dev/null || true

elif [ "$ROLE" == "compute" ]; then
    # Wait until controller generates keys
    while [ ! -f /root/.ssh_shared/id_rsa.pub ]; do
        sleep 1
    done
    cat /root/.ssh_shared/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    echo "[BOOTSTRAP] Setting up security firewall & isolation rules..."
    # Apply Security Groups / Firewall Rules:
    # 1. Allow established connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 2. Allow management traffic from management subnet (192.168.100.0/24)
    iptables -A INPUT -s 192.168.100.0/24 -j ACCEPT
    # 3. Allow guest traffic on guest subnet (10.0.1.0/24)
    iptables -A INPUT -s 10.0.1.0/24 -p icmp -j ACCEPT
    iptables -A INPUT -s 10.0.1.0/24 -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -s 10.0.1.0/24 -p tcp --dport 8080 -j ACCEPT
    # 4. Block Guest network from accessing SSH / Management interface of Compute or Controller
    iptables -A INPUT -s 10.0.1.0/24 -p tcp --dport 22 -j LOG --log-prefix "[MINICLOUD-SEC-ALERT] Unauthorized SSH: "
    iptables -A INPUT -s 10.0.1.0/24 -p tcp --dport 22 -j DROP

    # Start local telemetry / node stats responder
    chmod +x /opt/compute/agent.sh 2>/dev/null || true
    if [ -f /opt/compute/agent.sh ]; then
        /opt/compute/agent.sh &
    fi
fi

# Start SSH daemon in background
service ssh start

# Keep container alive and stream audit logs if controller
if [ "$ROLE" == "controller" ]; then
    touch /var/log/minicloud/audit.log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SYSTEM] Controller node initialized." >> /var/log/minicloud/audit.log
    tail -f /var/log/minicloud/audit.log
else
    tail -f /var/log/faillog 2>/dev/null || sleep infinity
fi
