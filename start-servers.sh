#!/bin/bash
set -e

PROJECT_DIR="$HOME/ss-web-proxy"

echo "Starting Shadowsocks + Web Proxy + Caddy..."
cd "$PROJECT_DIR" || { echo "Project directory not found!"; exit 1; }

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo "Docker is not running. Starting Docker..."
    sudo systemctl start docker
    sleep 5
fi

# Start all services
docker compose up -d

echo "======================================"
echo "All services started!"
echo "Shadowsocks server port: 8388"
echo "Web proxy port: 8080"
echo "Check status with: docker compose ps"
echo "======================================"
