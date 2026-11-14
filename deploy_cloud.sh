#!/usr/bin/env bash
# Automated Deployment & Healthcheck Script for Mini-Cloud Environment
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

echo "================================================================="
echo "   Miniature Cloud Environment Deployment (Track A)             "
echo "   Course: Cloud Computing Technologies                         "
echo "================================================================="

echo "[1/4] Preparing directories and shared storage..."
mkdir -p logs ssh_keys compute controller
chmod 700 ssh_keys

echo "[2/4] Building and bootstrapping multi-node cluster containers..."
docker compose down -v 2>/dev/null || true
docker compose up -d --build

echo "[3/4] Waiting for node initialization & SSH key exchange (10s)..."
sleep 10

echo "[4/4] Verifying node status..."
docker compose exec ctrl-node /opt/controller/cloud-cli nodes

echo ""
echo "================================================================="
echo "   Cluster Successfully Deployed!                                "
echo "================================================================="
echo "To interact with the cloud environment:"
echo "  docker compose exec -it ctrl-node cloud-cli nodes"
echo "  docker compose exec -it ctrl-node cloud-cli launch web-01 256"
echo "  docker compose exec -it ctrl-node cloud-cli list"
echo "  docker compose exec -it ctrl-node cloud-cli audit"
echo "================================================================="
