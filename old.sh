#!/bin/sh
#
# Pi-DoH v0.9
# Configuring Cloudflared (DoH)- DNS-Over-HTTPS

set -e
# Setup the alias piup to run updates for Raspberry Pi
{
echo "\n\n"
echo "# Easy updates for the Pi using the command piup"
echo "alias piup='sudo apt update && sudo apt full-upgrade && sudo apt autoremove && sudo apt clean'"
}>> ~/.bashrc

# Download Cloudflared - arm64 architecture (64-bit Raspberry Pi)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

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
{
echo "#!/bin/sh"
echo "#"
echo "# cloudflared cron weekly update"
echo "set -e"
echo "sudo cloudflared update"
echo "sudo systemctl restart cloudflared"
echo "exit 0"
}>> /etc/cron.weekly/cloudflared-updater
sudo chmod +x /etc/cron.weekly/cloudflared-updater
sudo chown root:root /etc/cron.weekly/cloudflared-updater

# Add custom DNS to Pi-hole
dohDNS="PIHOLE_DNS_1=127.0.0.1#5053"
target="/etc/pihole/setupVars.conf"

# replace PIHOLE_DNS_1 with new DOH DNS
sed -i "s/PIHOLE_DNS_1.*/$dohDNS/" "${target}"
# remove PIHOLE_DNS_2 line
sed -i '/^PIHOLE_DNS_2/d' "${target}"

# Restart FTL
sudo service pihole-FTL restart

# Remove setup script
rm setup-pidoh.sh

echo -e "\n\e[0;32mNow reinstall blocklist backups via Teleporter in the Pi-hole GUI.\n"
