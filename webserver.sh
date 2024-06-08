#!/bin/bash
# https://www.linuxcapable.com/how-to-install-apache-on-debian-linux/
# https://reintech.io/blog/setting-up-sftp-secure-file-transfers-debian-12
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
sleep 1
echo "Making Directory for $domain"
sleep 2
mkdir -p /var/www/$domain
echo -e "${green}\n \nWhat is the email associated with this domain?${clear}"
read email

#Install updates
echo "Checking && Installing Updates"
sleep 2
apt update && apt upgrade -y

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
ufw allow 22

#Setting up Virtual Host
echo -e "${yellow}\n \nSetting up Virtual Host${clear}"
sleep 2
echo -e "<VirtualHost *:80> \n  ServerAdmin $email \n  ServerName $domain \n  ServerAlias www.$domain \n  DocumentRoot /var/www/$domain \n  ErrorLog ${APACHE_LOG_DIR}/error.log \n  CustomLog ${APACHE_LOG_DIR}/access.log combined \n  <IfModule mod_speling.c> \n    CheckSpelling On \n    CheckCaseOnly On \n  </IfModule> \n</VirtualHost>" >> /etc/apache2/sites-available/$domain.conf
a2dissite 000-default.conf
a2ensite $domain.conf
a2enmod speling
echo -e "${yellow}\n \nIs Virtual Host configuration syntax OK${clear}"
sleep 3
apache2ctl configtest
sleep 3
echo -e "${yellow}\n \nDisabling Web Indexes${clear}"
sleep 3
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/apache2/apache2.conf
systemctl restart apache2
systemctl enable apache2

#Install MariaDB
while true; do
read -p "${green}\n \nDo you want to install MariaDB? (y/n)${clear} " yn
case $yn in
  [yY] ) echo -e "${yellow}\n \nInstalling MariaDB${clear}";
      sleep 2;
      apt install mariadb-server -y;
      break;;
  [nN] ) echo exiting...;
      exit;;
  * ) echo invalid response;;
esac  
done

#Install PHP
echo -e "${green}\n \nWhich PHP Version do you want to install? (ie 8.2)${clear}"
read phpversion
apt install -y apt-transport-https lsb-release ca-certificates wget 
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list 
apt update
apt -y install php$phpversion php$phpversion-xml php$phpversion-curl #<---- need to figure this out for blog page
#apt-get install -y php$phpversion-cli php$phpversion-common php$phpversion-mysql php$phpversion-zip php$phpversion-gd php$phpversion-mbstring php$phpversion-curl php$phpversion-xml php$phpversion-bcmath
a2enmod php
systemctl restart apache2


#Install SFTP
echo -e "${yellow}\n \nSetting up SFTP${clear}"
sleep 2
echo -e "${green}What is the username for SFTP Access?${clear}"
read ftplogin
sleep 1
echo -e "${magenta}Creating SFTP User $ftplogin and Assigning User to $domain${clear}"
sleep 2
groupadd sftpusers
useradd -m -g sftpusers -s /bin/false $ftplogin
echo -e "${green}\n \nEnter password for SFTP login${clear}"
passwd $ftplogin
sed -i 's|Subsystem\s\s*sftp\s\s*/usr/lib/openssh/sftp-server|Subsystem sftp internal-sftp|' /etc/ssh/sshd_config
echo -e "\nMatch Group sftpusers \n \tX11Forwarding no \n \tAllowTcpForwarding no \n \tChrootDirectory /var/www/ \n \tForceCommand internal-sftp" >> /etc/ssh/sshd_config
systemctl restart ssh
chown root:sftpusers /var/www
chmod 755 /var/www
chown $ftplogin:sftpusers /var/www/$domain


echo -e "${yellow}\n \nThis is your current IP ADDRESS${clear}"
hostname -I
echo -e "${red}\nSystem will reboot in 5 seconds${clear}"
sleep 10
reboot
