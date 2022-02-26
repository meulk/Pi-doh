#!/bin/sh
#
# PiDoH 0.5

# Cloudflared (DoH)
# Configuring DNS-Over-HTTPS

wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
#cloudflared -v

sudo mkdir /etc/cloudflared/
sudo nano /etc/cloudflared/config.yml
