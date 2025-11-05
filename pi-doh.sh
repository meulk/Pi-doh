#!/bin/bash
#
# Pi-DoH v1.25
# Script to install and configure Pi-hole and Cloudflared's DNS-Over-HTTPS proxy functionality

set -e

PIHOLE_INSTALL=false

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
	printf "\n${CROSS} This script must be run as root to continue, either sudo this script or run under the root account\n"
	exit 1
fi

command_exists() {
	local check_command="$1"
	command -v "${check_command}" > /dev/null 2>&1
}

# Main install functions, these install Pi-hole and Cloudflared

pihole_install() {
	if command_exists apt-get ; then
		PIHOLE_INSTALL=true
		printf "\n${TICK}${GREEN} Debian based system detected, continuing...${COL_NC}\n"
		sleep 1
		printf "${INFO} Pi-hole installation beginning...\n"
		sleep 1
		curl -sSL https://install.pi-hole.net | bash
	else
		printf "\n${CROSS} This script will only run on a Debian based system. Quiting...\n"
		exit 1
	fi
}

cloudflared_install() {
	if command_exists apt-get; then
	printf "\n${YELLOW}Installing Cloudflared\n${COL_NC}"
	sleep 2
	whichbit=$(uname -m)

	# Check if Raspberry Pi is running 32-bit or 64-bit and download correct version of Cloudflared
	
	if [[ $whichbit == "aarch64" ]]; then
		# Download Cloudflared - arm64 architecture (64-bit Raspberry Pi)
                printf "\n${INFO} 64-bit Architecture detected.\n"
                sleep 1
		printf "${TICK} Installing Cloudflared (arm64)...\n\n"
		sleep 1
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
		sudo cp ./cloudflared-linux-arm64 /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
		sudo rm ./cloudflared-linux-arm64
		

        elif [[ $whichbit == "armv7l" ]]; then
                # Download Cloudflared -armhf architecture (32-bit Raspberry Pi)
		printf "\n${INFO} 32-bit Architecture detected.\n"
		sleep 1
		printf "${TICK} Installing Cloudflared (armhf)...\n\n"
		sleep 1
		wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm
		sudo cp ./cloudflared-linux-arm /usr/local/bin/cloudflared
		sudo chmod +x /usr/local/bin/cloudflared
		sudo rm ./cloudflared-linux-arm
       			
	else
		printf "\n${CROSS} This script will only run on a Debian based system. Quiting...\n"
		exit 1
	fi
fi
}

configure() {
	# Configuring Cloudflared to run on startup	
	# Create a configuration file for Cloudflared
	
	printf "${TICK} Setting up Cloudflared...\n\n"
	sleep 1
	sudo useradd -s /usr/sbin/nologin -r -M cloudflared
	
	{
	echo "# Commandline args for cloudflared, using Cloudflare DNS"
	echo "CLOUDFLARED_OPTS=--port 5053 --upstream https://1.1.1.1/dns-query --upstream https://1.0.0.1/dns-query"
	}>> /etc/default/cloudflared
	
	sudo chown cloudflared:cloudflared /etc/default/cloudflared
	sudo chown cloudflared:cloudflared /usr/local/bin/cloudflared

	wget -O /etc/systemd/system/cloudflared.service "https://raw.githubusercontent.com/meulk/Pi-doh/main/cloudflared.service"
	
	sudo systemctl enable cloudflared
	sudo systemctl start cloudflared
	printf "\n${TICK} Cloudflared installed.\n"
	sleep 1
	
	# Create a weekly cronjob to update Cloudflared
	printf "${TICK} Creating cronjob to update Cloudflared at 04.00 every Sunday morning...\n"
	sleep 1
	(crontab -l ; echo "0 4 * * 0 sudo cloudflared update && sudo systemctl restart cloudflared") 2>&1 | grep -v "no crontab" | sort | uniq | crontab -
	
	# Add custom DNS to Pi-hole
	sudo pihole-FTL --config dns.upstreams '["127.0.0.1#5053"]'
  	
	#dohDNS="PIHOLE_DNS_1=127.0.0.1#5053"
  	#target="/etc/pihole/setupVars.conf"

  	# replace PIHOLE_DNS_1 with new DOH DNS
  	#sed -i "s/PIHOLE_DNS_1=.*/$dohDNS/" "${target}"
  	# remove PIHOLE_DNS_2 line
  	#sed -i '/^PIHOLE_DNS_2=/d' "${target}"
	
	# Restart Pi-hole FTL
	printf "${TICK} Restarting Pi-hole FTL...\n"
	sudo service pihole-FTL restart	
}

dns() {
	noerror=$(dig @127.0.0.1 -p 5053 google.com | grep NOERROR)

	if [[ $noerror == *"NOERROR"* ]]; then
		printf "${TICK} DNS test completed successfully.\n"
		sleep 1
	else
		printf "${CROSS} DNS query returned unexpected result.\n"
		sleep 1
	fi
}

cleanup() {
	# Remove setup script
	rm pi-doh.sh
	printf "${TICK} ${GREEN}Installation Complete! \n\n ${COL_NC}"
	if [[ "${PIHOLE_INSTALL}" == true ]] ; then
         printf "${INFO} Now re-install any blocklist backups via Teleporter in the Pi-hole GUI settings.\n\n"
	fi
}

setup_alias() {
	printf "\n${INFO}${GREEN} To create the alias \"piup\" for easy updating of the Raspberry Pi, enter the following in terminal:${COL_NC}\n"
	printf "\n${YELLOW} echo \"alias piup='sudo apt-get update && sudo apt-get full-upgrade && sudo apt-get autoremove && sudo apt-get clean'\" >> ~/.bash_aliases\n"
	printf "\n${YELLOW} source ~/.bash_aliases${COL_NC}\n\n"

	# Install and setup Docker
 	# https://docs.docker.com/engine/install/debian/
 	# alias dockerup='sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
}

uninstall_cloudflared() {
	printf "\n${INFO} Uninstalling Cloudflared...\n"
	sleep 1
	sudo systemctl stop cloudflared
	sudo systemctl disable cloudflared
	sudo systemctl daemon-reload
	sudo deluser cloudflared
	sudo rm /etc/default/cloudflared
	sudo rm /etc/systemd/system/cloudflared.service
	sudo rm /usr/local/bin/cloudflared
	
	#delete cronjob
	(crontab -l ; echo "0 4 * * 0 sudo cloudflared update && sudo systemctl restart cloudflared") 2>&1 | grep -v "no crontab" | grep -v "sudo cloudflared" |  sort | uniq | crontab -
	printf "${TICK} Cloudflared has been uninstalled.\n"
}

printf "\n${YELLOW}Pi-doh v1.25\n${COL_NC}"
printf "This script will install Pi-hole and/or Cloudflared, enabling DNS-Over-HTTPS functionality.\n"

printf "\n${GREEN}What would you like to do?${COL_NC} (enter a number and press enter) \n\n1) Install Pi-hole and Cloudflare along with required configuration.\n2) Install Cloudflared along with required configuration.\n3) Uninstall Cloudflared.\n"

read answer

if [ "$answer" == "1" ] ;then
        pihole_install
	cloudflared_install
	configure
	dns
	cleanup
	setup_alias

elif [ "$answer" == "2" ] ;then
        cloudflared_install
	configure
	dns
	cleanup
	setup_alias

elif [ "$answer" == "3" ] ;then
        uninstall_cloudflared
else
        printf "${CROSS} ${RED}Choose 1-3 only ffs. \n\n ${COL_NC}"
fi

