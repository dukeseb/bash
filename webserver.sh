#!/bin/bash
# https://www.linuxcapable.com/how-to-install-apache-on-debian-linux/
# https://www.transip.eu/knowledgebase/entry/2076-sftp-tutorial-debian-9/
# https://www.transip.eu/knowledgebase/entry/1851-installing-an-ssh-server-debian/?utm_source=knowledge%20base
# https://tecadmin.net/how-to-install-php-on-debian-12/
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mariadb-php-lamp-stack-on-debian-10
# https://www.digitalocean.com/community/tutorials/how-to-install-php-8-1-and-set-up-a-local-development-environment-on-ubuntu-22-04

# Set the color variable
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'

#Required Domain Information
echo -e "${green}What is your website name? (only include root domain ie. domain.com)${clear}"
read domain

echo -e "${green}\n \nWhat is the email associated with this domain?${clear}"
read email


#Install updates
apt update && apt upgrade -y


#Install Curl
apt install curl


#Install Apache Web Server
echo -e "${yellow}\n \nInstalling Apache2 Web Server${clear}"
sleep 2
apt install apache2 -y
systemctl enable apache2 --now


#Install UFW Firewall
echo -e "${yellow}\n \nInstalling & Configuring UFW${clear}"
sleep 2
apt install ufw -y
ufw enable
ufw allow 80
ufw allow 443


#Setting up Website
echo -e "${yellow}\n \nSetting up Website${clear}"
sleep 1
echo "making directory for domain, ,changing ownership, adding permissions...."
sleep 2
mkdir /var/www/$domain
chown -R $USER:$USER /var/www/$domain
chmod -R 755 /var/www/$domain


#Setting up Virtual Host
echo -e "${yellow}\n \nSetting up Virtual Host${clear}"
sleep 2
#write to file /etc/apache2/sites-available/$domain.conf
#<VirtualHost *:80>
#    ServerAdmin $email
#    ServerName $domain
#    ServerAlias www.$domain
#    DocumentRoot /var/www/$domain
#    ErrorLog ${APACHE_LOG_DIR}/error.log
#    CustomLog ${APACHE_LOG_DIR}/access.log combined
#</VirtualHost>
echo -e "<VirtualHost *:80> \n  ServerAdmin $email \n  ServerName $domain \n  ServerAlias www.$domain \n  DocumentRoot /var/www/$domain \n  ErrorLog ${APACHE_LOG_DIR}/error.log \n  CustomLog ${APACHE_LOG_DIR}/access.log combined \n</VirtualHost>" >> /etc/apache2/sites-available/$domain.conf
a2dissite 000-default.conf
a2ensite $domain.conf
echo -e "${yellow}\n \nIs Virtual Host configuration syntax OK${clear}"
sleep 3
apache2ctl configtest
sleep 3
systemctl restart apache2
systemctl enable apache2


#Setting up certbot
#echo "setting up certbot for $domain"
#apt install python3-certbot-apache -y
#certbot --apache --agree-tos --redirect --hsts --staple-ocsp --email $email -d $domain
#echo "Validating certbot - Dry Run"
#certbot renew --dry-run
#sleep 3



#Install MariaDB
echo -e "${yellow}\n \nInstalling MariaDB${clear}"
sleep 2
apt install mariadb-server -y



#Install PHP
echo -e "${green}\n \nWhich PHP Version do you want to install? (ie 8.2)${clear}"
read phpversion

apt install -y apt-transport-https lsb-release ca-certificates wget 
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list 
apt update
apt-get install -y php$phpversion-cli php$phpversion-common php$phpversion-mysql php$phpversion-zip php$phpversion-gd php$phpversion-mbstring php$phpversion-curl php$phpversion-xml php$phpversion-bcmath
a2enmod php
systemctl restart apache2


#Install SFTP
echo -e "${yellow}\n \nSetting up SSH / SFTP${clear}"
sleep 2
echo "${green}What is the username for SFTP Access?${clear}"
read ftplogin
ufw allow ssh
groupadd sftp
useradd -G sftp -d /var/www/$domain -s /sbin/nologin $ftplogin
echo -e "\n \nEnter password for SFTP / SSH login"
passwd $ftplogin
chmod g+rx /var/www
chown $ftplogin:$ftplogin /var/www/$domain
#Append Write to file /etc/ssh/sshd_config
  # AllowGroups ssh sftp
  # Match Group sftp
  # ChrootDirectory /var/www/$domain
  # ForceCommand internal-sftp
#echo -e "AllowGroups ssh sftp \nMatch Group sftp \nChrootDirectory /var/www/$domain \nForceCommand internal-sftp" >> /etc/ssh/sshd_config

#Match User $ftplogin
#	ForceCommand internal-sftp
#	PasswordAuthentication yes
#	ChrootDirectory /var/www/$domain
#	PermitTunnel no
#	AllowAgentForwarding no
#	AllowTcpForwarding no
#	X11Forwarding no
echo -e "Match User $ftplogin \n  ForceCommand internal-sftp \n  PasswordAuthentication yes \n  ChrootDirectory /var/www/$domain \n  PermitTunnel no \n  AllowAgentForwarding no \n  AllowTcpForwarding no \n  X11Forwarding no" >> /etc/ssh/sshd_config

systemctl restart sshd

echo -e "${yellow}\n \nThis is your current IP ADDRESS${clear}"
hostname -I
echo -e "${red}\nSystem will reboot in 5 seconds${clear}"
sleep 10
reboot
