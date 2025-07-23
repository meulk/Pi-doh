#Make this file executable:
#chmod +x setup-doh-cloudflared.sh

#!/bin/bash

set -e

echo "📦 Installing Cloudflared..."

# Download and install the latest Cloudflared
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
    ARCH_TYPE="arm64"
elif [[ "$ARCH" == "armv7l" ]]; then
    ARCH_TYPE="arm"
else
    ARCH_TYPE="amd64"
fi

wget -O cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH_TYPE}.deb"
sudo dpkg -i cloudflared.deb
rm cloudflared.deb

echo "✅ Cloudflared installed."

echo "⚙️ Configuring Cloudflared as a systemd service..."

# Create config directory and file
sudo mkdir -p /etc/cloudflared

sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-address: 127.0.0.1
upstream:
  - https://1.1.1.1/dns-query
  - https://1.0.0.1/dns-query
EOF

# Create and enable systemd service
sudo cloudflared service install --legacy

echo "✅ Cloudflared systemd service installed and enabled."

echo "🔁 Restarting cloudflared service..."
sudo systemctl restart cloudflared
sudo systemctl enable cloudflared

echo "🔧 Pointing Pi-hole to use Cloudflared (127.0.0.1#5053)..."
sudo sed -i 's/^PIHOLE_DNS_.*$/PIHOLE_DNS_1=127.0.0.1#5053/' /etc/pihole/setupVars.conf

echo "♻️ Restarting Pi-hole services..."
sudo pihole restartdns

echo "✅ DNS-over-HTTPS with Cloudflared is now configured for Pi-hole."
