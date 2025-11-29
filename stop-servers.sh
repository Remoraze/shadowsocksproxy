#!/bin/bash
set -e

PROJECT_DIR="$HOME/ss-web-proxy"

echo "Stopping Shadowsocks + Web Proxy + Caddy..."
cd "$PROJECT_DIR" || { echo "Project directory not found!"; exit 1; }

docker compose down

echo "All services stopped."
