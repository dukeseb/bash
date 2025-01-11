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


#Install PHP
echo -e "${green}\n \nWhich PHP Version do you want to install? (ie 8.2)${clear}"
read phpversion
apt install -y software-properties-common apt-transport-https lsb-release ca-certificates wget 
add-apt-repository ppa:ondrej/php
apt update
apt -y install php$phpversion php$phpversion-{mysql,zip,bcmath,mbstring,xml,curl,gd}
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


#Install and Configure FTPS (vsftpd)
echo -e "${yellow}\n \nInstalling and configuring FTPS (vsftpd)${clear}"
sleep 2
apt install -y vsftpd
systemctl enable vsftpd
systemctl start vsftpd

# Create SSL certificates for FTPS
echo -e "${green}\n \nGenerating SSL Certificates for FTPS${clear}"
sleep 1
mkdir -p /etc/ssl/private
openssl req -newkey rsa:2048 -nodes -keyout /etc/ssl/private/vsftpd.key -out /etc/ssl/private/vsftpd.csr
openssl req -x509 -key /etc/ssl/private/vsftpd.key -in /etc/ssl/private/vsftpd.csr -out /etc/ssl/certs/vsftpd.crt -days 3650
chmod 600 /etc/ssl/private/vsftpd.key
chmod 644 /etc/ssl/certs/vsftpd.crt

# Configure vsftpd for FTPS
echo -e "${yellow}\n \nConfiguring FTPS with SSL/TLS encryption${clear}"
sleep 2
sed -i 's/^#\(ssl_enable=\).*$/\1YES/' /etc/vsftpd.conf
sed -i 's/^#\(rsa_cert_file=\).*$/\1\/etc\/ssl\/certs\/vsftpd.crt/' /etc/vsftpd.conf
sed -i 's/^#\(rsa_private_key_file=\).*$/\1\/etc\/ssl\/private\/vsftpd.key/' /etc/vsftpd.conf
sed -i 's/^#\(ssl_ciphers=\).*$/\1HIGH/' /etc/vsftpd.conf
sed -i 's/^#\(ssl_tlsv1_2=\).*$/\1YES/' /etc/vsftpd.conf
sed -i 's/^#\(allow_anon_ssl=\).*$/\1NO/' /etc/vsftpd.conf
sed -i 's/^#\(force_local_data_ssl=\).*$/\1YES/' /etc/vsftpd.conf
sed -i 's/^#\(force_local_logins_ssl=\).*$/\1YES/' /etc/vsftpd.conf
sed -i 's/^#\(ssl_tlsv1_3=\).*$/\1YES/' /etc/vsftpd.conf
sed -i 's/^#\(pasv_min_port=\).*$/\140000/' /etc/vsftpd.conf
sed -i 's/^#\(pasv_max_port=\).*$/\140100/' /etc/vsftpd.conf

# Restart vsftpd service
systemctl restart vsftpd


#Configure UFW for FTPS (Port 990)
echo -e "${yellow}\n \nAllowing FTPS (Port 990) through the firewall${clear}"
ufw allow 990/tcp
ufw reload


#Mount Network Share
echo -e "${yellow}\n \nSetting Up Network Share${clear}"
sleep 2
echo -e "${green}What is the IP Address?${clear}"
read ipaddress
echo -e "${green}What is your Share Username?${clear}"
read shareusername
echo -e "${green}What is your Share Password?${clear}"
read sharepasswd
mkdir /mnt/share
touch /credentials.cifs_user
echo -e "USER=$shareusername \nPASSWORD=$sharepasswd" >> /credentials.cifs_user
chmod 600 /credentials.cifs_user
echo -e "\n//$ipaddress/Public /mnt/share cifs rw,nosuid,nodev,noexec,relatime,vers=3.0,sec=ntlmv2,cache=strict,credentials=/credentials.cifs_user,uid=1000,noforceuid,gid=1000,noforcegid,addr=192.168.2.4,file_mode=0777,dir_mode=0777,iocharset=utf8 0 0" >> /etc/fstab


#Closing Information
echo -e "${yellow}\n \nThis is your current IP ADDRESS${clear}"
hostname -I
echo -e "${red}\nSystem will reboot in 5 seconds${clear}"
sleep 5
reboot
