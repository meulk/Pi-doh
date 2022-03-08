# About Pi-doh 

Pi-doh installs and configures PiHole and Cloudflared to be your Pi-hole's DNS server, enabling DNS-Over-HTTPS functionality.

## What if I already have PiHole installed? ##
You will be prompted during the script to either install PiHole and Cloudflared (option 1), or to just install Cloudflared along with required configuration (option 2).

___
After the installation of Pi-hole is complete, use the following command to install:

`wget -O pi-doh.sh https://raw.githubusercontent.com/meulk/doh/main/pi-doh.sh && chmod 755 pi-doh.sh`

`sudo ./pi-doh.sh`
