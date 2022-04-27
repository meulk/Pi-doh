#!/bin/bash
#
# Pi-DoH v1.15
# Script to install and configure Pi-hole and Cloudflared's DNS-Over-HTTPS proxy functionality

set -e
# Set output colours
COL_NC="\e[0m" # No Color
GREEN="\e[1;32m"
RED="\e[1;31m"
YELLOW="\e[0;33m"
TICK="[${GREEN}✓${COL_NC}]"
CROSS="[${RED}✗${COL_NC}]"
INFO="[i]"

# Check the script is being run as root
if [[ $EUID -ne 0 ]] ; then
	printf "${CROSS} This script must be run as root to continue, either sudo this script or run under the root account\n"
	exit 1
fi

# Checks to see if the given command (passed as a string argument) exists on the system.
# The function returns 0 (success) if the command exists, and 1 if it doesn't.
is_command() {
	local check_command="$1"
	command -v "${check_command}" > /dev/null 2>&1
}

# Main install functions, these install Pi-hole and Cloudflared

pihole_install() {
	if is_command apt-get ; then
		printf "${TICK}${GREEN} Debian based system detected, continuing...${COL_NC}\n"
		sleep 1
		printf "${INFO} Pi-hole installation beginning...\n"
		sleep 1
		curl -sSL https://install.pi-hole.net | bash
	else
		printf "${CROSS} This script will only run on a Debian based system. Quiting...\n"
		exit 1
	fi
}

dns_install() {
	if is_command apt-get; then
	printf "\n${YELLOW}Installing Cloudflared\n${COL_NC}"
	sleep 2
	whichbit=$(uname -m)

	# Check if Raspberry Pi is running 32-bit or 64-bit and download correct version of Cloudflared
	
	if [[ $whichbit == "aarch64" ]]; then
		# Download Cloudflared - arm64 architecture (64-bit Raspberry Pi)
                printf "\n${INFO} 64-bit Architecture detected.\n"
                sleep 1
		printf "${TICK} Installing Cloudflared (arm64)...\n"
		sleep 1
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
		sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
		

        elif [[ $whichbit == "armv7l" ]]; then
                # Download Cloudflared -armhf architecture (32-bit Raspberry Pi)
		printf "\n${INFO} 32-bit Architecture detected.\n"
		sleep 1
		printf "${TICK} Installing Cloudflared (armhf)...\n"
		sleep 1
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm
		sudo cp ./cloudflared-linux-arm /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
       			
	else
		printf "${CROSS} This script will only run on a Debian based system. Quiting...\n"
		exit 1
	fi

	# Configuring Cloudflared to run on startup	
	# Create a configuration file for Cloudflared
	
#	printf "${TICK} Creating Cloudflared config file...\n"
#	sleep 1
#	sudo mkdir /etc/cloudflared/
#	wget -O /etc/cloudflared/config.yml "https://raw.githubusercontent.com/meulk/Pi-doh/main/config.yml"
	# install the service via Cloudflared's service command
#	sudo cloudflared service install --legacy
#	printf "${TICK} Cloudflared installed.\n"
#	sleep 1
fi
}

configure() {
	sudo useradd -s /usr/sbin/nologin -r -M cloudflared
	
	{
	echo "# Commandline args for cloudflared, using Cloudflare DNS"
	echo "CLOUDFLARED_OPTS=--port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query"
	}>> /etc/default/cloudflared
	
	sudo chown cloudflared:cloudflared /etc/default/cloudflared
	sudo chown cloudflared:cloudflared /usr/local/bin/cloudflared

}

configure_old() {
	# Start the systemd Cloudflared service
	printf "${TICK} Starting Cloudflared...\n"
	sleep 1
  	sudo systemctl start cloudflared

	# Create a weekly cronjob to update Cloudflared
	printf "${TICK} Creating cron job to update Cloudflared at 04.00 every Sunday morning...\n"
	sleep 1
	(crontab -l 2>/dev/null; echo "0 4 * * 0 sudo cloudflared update && sudo systemctl restart cloudflared") | crontab -
	
	# Add custom DNS to Pi-hole
  	dohDNS="PIHOLE_DNS_1=127.0.0.1#5053"
  	target="/etc/pihole/setupVars.conf"

  	# replace PIHOLE_DNS_1 with new DOH DNS
  	sed -i "s/PIHOLE_DNS_1=.*/$dohDNS/" "${target}"
  	# remove PIHOLE_DNS_2 line
  	sed -i '/^PIHOLE_DNS_2=/d' "${target}"
	
	# Restart Pi-hole FTL
	sudo service pihole-FTL restart
	
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
		printf "${TICK} First DNS test completed successfully.\n"
		sleep 1
	else
		printf "${CROSS} First DNS query returned unexpected result.\n"
		sleep 1
	fi

	if [[ $noerror == *"NOERROR"* ]]; then
		printf "${TICK} Second DNS test completed successfully.\n"
		sleep 1
	else
		printf "${CROSS} Second DNS query returned unexpected result.\n"
		sleep 1
	fi
}

cleanup() {
	# Remove setup script
	rm pi-doh.sh
	printf "${TICK} ${GREEN} Installation Complete! \n ${COL_NC}"
	printf "${INFO} Now re-install any blocklist backups via Teleporter in the Pi-hole GUI settings.\n"
}

printf "\n${YELLOW}Pi-doh v1.15\n${COL_NC}"
printf "This script will install Pi-hole and/or Cloudflared, enabling DNS-Over-HTTPS functionality.\n"

printf "\n${GREEN}What would you like to do?${COL_NC} (enter a number and press enter) \n\n1) Install Pi-hole and Cloudflare along with required configuration.\n2) Install Cloudflared along with required configuration.\n"

read answer

if [ "$answer" == "1" ] ;then
	pihole_install
	dns_install
	configure
	dns
	cleanup
else
	dns_install
	configure
	dns
	rm pi-doh.sh
	printf "${TICK} ${GREEN} Installation Complete! \n ${COL_NC}"
fi
