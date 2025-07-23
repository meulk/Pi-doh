#!/bin/bash
set -euo pipefail

# Variables
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
CLOUDFLARED_SERVICE="/etc/systemd/system/cloudflared.service"
DOH_PORT=5053
LOCAL_DNS="127.0.0.1#$DOH_PORT"
PIHOLE_SETUPVARS="/etc/pihole/setupVars.conf"
DNSMASQ_CONF="/etc/dnsmasq.d/01-pihole.conf"

echo "===> Starting cloudflared + Pi-hole DoH setup..."

# 1. Install prerequisites if missing
if ! command -v curl >/dev/null 2>&1; then
  echo "[INFO] Installing curl..."
  sudo apt-get update
  sudo apt-get install -y curl
fi

# 2. Download cloudflared latest binary for your architecture
ARCH=$(dpkg --print-architecture)
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH"

if [ ! -x "$CLOUDFLARED_BIN" ]; then
  echo "[INFO] Downloading cloudflared binary for $ARCH..."
  sudo curl -L -o "$CLOUDFLARED_BIN" "$CLOUDFLARED_URL"
  sudo chmod +x "$CLOUDFLARED_BIN"
else
  echo "[INFO] cloudflared binary already installed."
fi

# 3. Create systemd service file (overwrite any existing one)
echo "[INFO] Creating cloudflared systemd service..."

sudo tee "$CLOUDFLARED_SERVICE" > /dev/null << EOF
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=network.target

[Service]
ExecStart=$CLOUDFLARED_BIN proxy-dns --port $DOH_PORT --address 127.0.0.1 --upstream https://1.1.1.1/dns-query
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 4. Reload systemd, enable and start cloudflared
echo "[INFO] Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "[INFO] Enabling cloudflared service..."
sudo systemctl enable cloudflared

echo "[INFO] Starting cloudflared service..."
sudo systemctl restart cloudflared

sleep 3

# Check if service is running
if systemctl is-active --quiet cloudflared; then
  echo "[INFO] cloudflared service is running."
else
  echo "[ERROR] cloudflared service failed to start."
  sudo journalctl -u cloudflared --no-pager -n 20
  exit 1
fi

# 5. Backup Pi-hole setupVars.conf
echo "[INFO] Backing up Pi-hole setupVars.conf..."
sudo cp "$PIHOLE_SETUPVARS" "${PIHOLE_SETUPVARS}.bak.$(date +%s)"

# 6. Configure Pi-hole upstream DNS to cloudflared in setupVars.conf
echo "[INFO] Updating Pi-hole upstream DNS to use cloudflared DoH..."

if grep -q "^PIHOLE_DNS_1=" "$PIHOLE_SETUPVARS"; then
  sudo sed -i "s|^PIHOLE_DNS_1=.*|PIHOLE_DNS_1=$LOCAL_DNS|" "$PIHOLE_SETUPVARS"
else
  echo "PIHOLE_DNS_1=$LOCAL_DNS" | sudo tee -a "$PIHOLE_SETUPVARS" > /dev/null
fi
sudo sed -i "/^PIHOLE_DNS_[23]/d" "$PIHOLE_SETUPVARS"

# 7. Modify dnsmasq config only if it exists
if [ -f "$DNSMASQ_CONF" ]; then
  echo "[INFO] Backing up dnsmasq config..."
  sudo cp "$DNSMASQ_CONF" "${DNSMASQ_CONF}.bak.$(date +%s)"
  
  echo "[INFO] Updating dnsmasq config to forward DNS queries to cloudflared DoH..."
  sudo sed -i "/^server=/d" "$DNSMASQ_CONF"
  echo "server=$LOCAL_DNS" | sudo tee -a "$DNSMASQ_CONF" > /dev/null
else
  echo "[INFO] $DNSMASQ_CONF does not exist, skipping dnsmasq config update."
fi

# 8. Restart Pi-hole DNS service
echo "[INFO] Restarting pihole-FTL service..."
sudo systemctl restart pihole-FTL

echo "[SUCCESS] cloudflared DoH setup completed successfully."
echo "Pi-hole is now configured to use cloudflared on $LOCAL_DNS."

exit 0
