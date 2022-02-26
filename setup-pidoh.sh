#!/bin/sh
#
# PiDoH 0.5

# Cloudflared (DoH)
# Configuring DNS-Over-HTTPS

# Download Cloudflared - arm64 architecture (64-bit Raspberry Pi)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
#cloudflared -v

# Configuring cloudflared to run on startup
# create a configuration file for cloudflared
sudo mkdir /etc/cloudflared/
wget -O /etc/cloudflared/config.yml "https://raw.githubusercontent.com/meulk/doh/main/config.yml"

# install the service via cloudflared's service command
sudo cloudflared service install --legacy

# Start the systemd service
sudo systemctl start cloudflared
#sudo systemctl status cloudflared

# Automating Cloudflared Updates
sudo chmod +x /etc/cron.weekly/cloudflared-updater
sudo chown root:root /etc/cron.weekly/cloudflared-updater
