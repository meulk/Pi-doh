#!/bin/sh
#
# Pi-DoH v1.0
# Script to install and configure Pi-hole and Cloudflared to be your network's recursive DNS server
set -e
# Check the script is being run as root

if [[ $EUID -ne 0 ]] ; then
	echo "This script must be run as root to continue, either sudo this script or run under the root account"
	exit 1
fi


# This function just checks to see if a command is present. This is used to assume the distro we are running.
is_command() {
	local check_command="$1"

	command -v "${check_command}" > /dev/null 2>&1
}


# Main install functions, this installs Pi-hole and Cloudflared

pihole_install() {
	if is_command apt-get ; then
		tput setaf 2; echo "Running Debian based distro, continuing..."
		tput setaf 2; echo "Pi-hole installation beginning..."
		curl -sSL https://install.pi-hole.net | bash
	else
		tput setaf 1; echo "This script will only run on Debian based distros. Quiting..."
		exit 1
	fi
}

dns_install() {
	if is_command apt-get; then
	whichbit=$(uname -m)

	# Check if Raspberry Pi is running 32 bit or 64 bit and download correct version of Cloudflared
	
	if [[ $whichbit == "aarch64" ]]; then
		# Download Cloudflared - arm64 architecture (64-bit Raspberry Pi)
                tput setaf 2; echo "Architecture is 64 bit."
		tput setaf 2; echo "Installing Cloudflared (arm64)..." 
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
		sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
        else
                # Download Cloudflared -armhf architecture (32-bit Raspberry Pi)
		tput setaf 1; echo "Architecture is 32 bit."
		tput setaf 2; echo "Installing Cloudflared (armhf)..."
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm
		sudo cp ./cloudflared-linux-arm /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
        fi
	
	
	

	# Configuring cloudflared to run on startup
	# Create a configuration file for cloudflared
	sudo mkdir /etc/cloudflared/
	tput setaf 2; echo "Creating Cloudflared config file..." 
	wget -O /etc/cloudflared/config.yml "https://raw.githubusercontent.com/meulk/Pi-doh/main/config.yml"

	# install the service via cloudflared's service command
	sudo cloudflared service install --legacy
	
	else
		tput setaf 1; echo "This script will only run on Debian based distros. Quiting..."
		exit 1
	fi
}

configure() {
	# Start the systemd Cloudflared service
	tput setaf 2; echo "Starting Cloudflared..."
  	sudo systemctl start cloudflared

	# Create a weekly cronjob to update Cloudflared
	tput setaf 2; echo "Creating cron job to update Cloudflared at 04.00 on a Sunday morning weekly..."
	(crontab -l 2>/dev/null; echo "0 4 * * 0 sudo cloudflared update && sudo systemctl restart cloudflared") | crontab -
	
	# Add custom DNS to Pi-hole
  	dohDNS="PIHOLE_DNS_1=127.0.0.1#5053"
  	target="/etc/pihole/setupVars.conf"

  	# replace PIHOLE_DNS_1 with new DOH DNS
  	sed -i "s/PIHOLE_DNS_1=.*/$dohDNS/" "${target}"
  	# remove PIHOLE_DNS_2 line
  	sed -i '/^PIHOLE_DNS_2=/d' "${target}"
	
	# Setup the alias "piup" to make it easier to run updates for Raspberry Pi
	{
	echo "\n\n"
	echo "# Easy updates for the Pi using the command piup"
	echo "alias piup='sudo apt update && sudo apt full-upgrade && sudo apt autoremove && sudo apt clean'"
	}>> ~/.bashrc
	
}

dns() {

	servfail=$(dig @127.0.0.1 -p 5053 google.com | grep SERVFAIL)
	noerror=$(dig @127.0.0.1 -p 5053 google.com | grep NOERROR)

	if [[ $servfail == *"SERVFAIL"* ]]; then
		tput setaf 2; echo "First DNS test completed successfully."
	else
		tput setaf 1; echo "First DNS query returned unexpected result."
	fi

	if [[ $noerror == *"NOERROR"* ]]; then
		tput setaf 2; echo "Second DNS test completed successfully."
	else
		tput setaf 1; echo " Second DNS query returned unexpected result."
	fi
}

teleporter() {
	tput setaf 2; echo "Now reinstall any blocklist backups via Teleporter in the Pi-hole GUI settings."
{


echo "This script will install Pi-hole, Cloudflared and automatically configure your Pi-hole DNS configuration to use Cloudflared."
printf "\nWhat would you like to do? (enter a number and press enter) \n1) Install Pi-hole and Cloudflare along with required configuration.\n2) Install Cloudflared along with required configuration.\n"

read answer

if [ "$answer" == "1" ] ;then
	pihole_install
	dns_install
	configure
	dns
	teleporter
else
	dns_install
	configure
	dns
fi
