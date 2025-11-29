# MADE BY REMORAZE

# Note:
# This is meant for locally hosting a proxy that is completly private since traffic is going through a shadowsocks server.

#!/bin/bash

set -e  # Exit immediately if a command fails

# -------- CONFIGURATION --------
SS_PASSWORD="ChangeThisPassword123!"   # Shadowsocks password
DOMAIN=""                              # Put your domain for HTTPS, leave empty for local access
WEB_PORT=8080                           # Web UI port
SS_PORT=8388                            # Shadowsocks port
PROJECT_DIR="$HOME/ss-web-proxy"
# --------------------------------

echo "==============================="
echo "Starting full Shadowsocks + Web Proxy + HTTPS setup"
echo "Project directory: $PROJECT_DIR"
echo "==============================="

# 1) Update system
echo "[1/12] Updating system..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl git ufw

# 2) Install Docker
echo "[2/12] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
else
    echo "Docker already installed, skipping."
fi

# 3) Install Docker Compose plugin
echo "[3/12] Installing Docker Compose..."
sudo apt install -y docker-compose-plugin

# 4) Add user to docker group
echo "[4/12] Adding user to docker group..."
sudo usermod -aG docker $USER || true

# 5) Create project directories
echo "[5/12] Creating project folders..."
mkdir -p "$PROJECT_DIR/web/public"
cd "$PROJECT_DIR"

# 6) Create docker-compose.yml
echo "[6/12] Writing docker-compose.yml..."
cat > docker-compose.yml <<EOL
version: "3.8"
services:
  shadowsocks:
    image: ghcr.io/shadowsocks/ssserver-rust:latest
    container_name: ssserver
    restart: unless-stopped
    ports:
      - "${SS_PORT}:${SS_PORT}/tcp"
      - "${SS_PORT}:${SS_PORT}/udp"
    environment:
      - PASSWORD=${SS_PASSWORD}
      - METHOD=aes-256-gcm

  web:
    image: node:20-bullseye
    container_name: ss-web-proxy
    restart: unless-stopped
    working_dir: /usr/src/app
    volumes:
      - ./web:/usr/src/app
    expose:
      - "${WEB_PORT}"
    command: ["bash", "-lc", "npm install --silent && npm start"]

  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
volumes:
  caddy_data:
  caddy_config:
EOL

# 7) Create Caddyfile
echo "[7/12] Writing Caddyfile..."
if [ -z "$DOMAIN" ]; then
    # Local access only
    echo ":80 { reverse_proxy web:${WEB_PORT} }" > Caddyfile
else
    # HTTPS via domain
    echo "${DOMAIN} { reverse_proxy web:${WEB_PORT} }" > Caddyfile
fi

# 8) Create Node.js web proxy files
echo "[8/12] Writing web proxy files..."
# package.json
cat > web/package.json <<EOL
{
  "name": "ss-web-proxy",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "unblocker": "^1.0.3",
    "body-parser": "^1.20.2"
  }
}
EOL

# server.js
cat > web/server.js <<'EOL'
const express = require('express');
const Unblocker = require('unblocker');
const path = require('path');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public')));

const unblocker = new Unblocker({ prefix: '/proxy/', ssl: false });
app.use(unblocker);

app.post('/go', (req, res) => {
  const rawUrl = req.body.url || '';
  if (!rawUrl.startsWith('http')) return res.redirect('/?err=need_full_url');
  res.redirect('/view?u=' + encodeURIComponent('/proxy/' + rawUrl));
});

app.get('/view', (req, res) => {
  const u = req.query.u || '';
  res.send(`<iframe src="${u}" style="width:100%;height:100vh;border:0"></iframe>`);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log('Web proxy running on port', PORT));
EOL

# index.html
cat > web/public/index.html <<'EOL'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Simple Proxy Search</title>
  <style>
    body { font-family: Arial, sans-serif; display:flex; flex-direction:column; align-items:center; padding:24px; background:#111; color:#eee; }
    form { width:100%; max-width:900px; display:flex; gap:8px; }
    input[type=text]{flex:1;padding:12px;border-radius:6px;border:1px solid #444;background:#222;color:#fff}
    button{padding:12px 16px;border-radius:6px;border:none;background:#28a745;color:#fff}
  </style>
</head>
<body>
  <h2>🔒 Web Proxy</h2>
  <form method="POST" action="/go">
    <input type="text" name="url" placeholder="https://example.com" required />
    <button type="submit">Go</button>
  </form>
</body>
</html>
EOL

# 9) Start Docker Compose
echo "[9/12] Starting Docker Compose services..."
docker compose up -d

# 10) Configure firewall
echo "[10/12] Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow ${SS_PORT}/tcp
sudo ufw allow ${SS_PORT}/udp
sudo ufw --force enable

# 11) Enable Docker services on boot
echo "[11/12] Enabling Docker services to auto-start on reboot..."
sudo systemctl enable docker

# 12) Finish
echo "[12/12] Setup complete!"
echo "=============================================="
if [ -z "$DOMAIN" ]; then
    echo "Access web proxy locally: http://$(hostname -I | awk '{print $1}'):${WEB_PORT}/"
else
    echo "Access web proxy via domain: https://${DOMAIN}/"
fi
echo "Shadowsocks server is running on port ${SS_PORT} with your password."
echo "Use any Shadowsocks client to connect."
echo "=============================================="
