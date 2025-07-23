#Make this file executable:
#chmod +x setup-doh-cloudflared.sh

#!/bin/bash

set -e

echo "🔧 Installing and configuring DNS-over-HTTPS using cloudflared (Pi-hole v6 compatible)..."

# Step 1: Install cloudflared
echo "📦 Installing cloudflared..."
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
    ARCH_URL="arm64"
elif [[ "$ARCH" == "armv7l" ]]; then
    ARCH_URL="arm"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

sudo mkdir -p /usr/local/bin
curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_URL" -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/cloudflared

# Step 2: Create cloudflared config
echo "📝 Writing cloudflared configuration..."
sudo mkdir -p /etc/cloudflared

sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
 - https://1.1.1.1/dns-query
 - https://1.0.0.1/dns-query
EOF

# Step 3: Create systemd service
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=cloudflared DNS over HTTPS proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/cloudflared --config /etc/cloudflared/config.yml
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# Step 4: Enable and start cloudflared
echo "🚀 Enabling and starting cloudflared..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# Step 5: Point system to cloudflared
echo "🔧 Updating /etc/resolv.conf to use 127.0.0.1#5053..."
if ! grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
    sudo sed -i '1s/^/nameserver 127.0.0.1\n/' /etc/resolv.conf
fi

# Step 6: Pi-hole DNSMasq Fix for v6 (disable case-randomisation)
echo "🛠 Configuring Pi-hole for DNS-over-HTTPS compatibility (v6 fix)..."
CUSTOM_DNSMASQ_CONF="/etc/dnsmasq.d/99-doh.conf"
if [ ! -f "$CUSTOM_DNSMASQ_CONF" ]; then
    sudo touch "$CUSTOM_DNSMASQ_CONF"
fi

if ! grep -q "no-case-randomisation" "$CUSTOM_DNSMASQ_CONF"; then
    echo "Adding 'no-case-randomisation' to $CUSTOM_DNSMASQ_CONF"
    echo "no-case-randomisation" | sudo tee -a "$CUSTOM_DNSMASQ_CONF" > /dev/null
fi

# Step 7: Restart Pi-hole DNS service
echo "🔁 Restarting Pi-hole DNS service..."
sudo systemctl restart pihole-FTL

# Step 8: Test
echo "🧪 Testing DoH resolution via cloudflared..."
dig_output=$(dig +short @127.0.0.1 -p 5053 whoami.cloudflare TXT)

if [[ "$dig_output" == *"cloudflare"* ]]; then
    echo "✅ DoH is working correctly via cloudflared!"
else
    echo "❌ DoH test failed. Check cloudflared logs: sudo journalctl -u cloudflared"
fi

echo "🎉 Setup complete. Pi-hole is now using DNS-over-HTTPS securely via cloudflared!"

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
