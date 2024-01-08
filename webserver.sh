#!/bin/bash
# https://www.linuxcapable.com/how-to-install-apache-on-debian-linux/
# https://www.transip.eu/knowledgebase/entry/2076-sftp-tutorial-debian-9/
# https://www.transip.eu/knowledgebase/entry/1851-installing-an-ssh-server-debian/?utm_source=knowledge%20base
# https://tecadmin.net/how-to-install-php-on-debian-12/
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mariadb-php-lamp-stack-on-debian-10
# https://www.digitalocean.com/community/tutorials/how-to-install-php-8-1-and-set-up-a-local-development-environment-on-ubuntu-22-04


echo "What is your website name? (only include root domain ie. domain.com)"
read domain

echo "What is the email associated with this domain?"
read email


#Install updates
apt update && apt upgrade -y


#Install Curl
apt install curl


#Install Apache Web Server
echo "Installing Apache2 Web Server"
sleep 2
apt install apache2 -y
systemctl enable apache2 --now


#Install UFW Firewall
echo "Installing & Configuring UFW"
sleep 2
apt install ufw -y
ufw enable
ufw allow 'Apache Full' && sudo ufw allow 'Apache Secure'


#Setting up Website
echo "Setting up Website"
sleep 2
mkdir /var/www/$domain
chown -R $USER:$USER /var/www/$domain
chmod -R 755 /var/www/$domain


#Setting up Virtual Host
echo "Setting up Virtual Host"
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
rm /etc/apache2/sites-available/$domain.conf
echo -e "<VirtualHost *:80> \n  ServerAdmin $email \n  ServerName $domain \n  ServerAlias www.$domain \n  DocumentRoot /var/www/$domain \n  ErrorLog ${APACHE_LOG_DIR}/error.log \n  CustomLog ${APACHE_LOG_DIR}/access.log combined \n</VirtualHost>" >> /etc/apache2/sites-available/$domain.conf
a2dissite 000-default.conf
a2ensite $domain.conf
echo "Is Virtual Host configuration syntax OK"
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
echo "Installing MariaDB"
sleep 2
apt install mariadb-server



#Install PHP
echo "Which PHP Version do you want to install? (ie 8.2)"
read phpversion

apt install -y apt-transport-https lsb-release ca-certificates wget 
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list 
apt update
apt-get install -y php$phpversion-cli php$phpversion-common php$phpversion-mysql php$phpversion-zip php$phpversion-gd php$phpversion-mbstring php$phpversion-curl php$phpversion-xml php$phpversion-bcmath
a2enmod php
systemctl restart apache2


#Install SFTP
echo "Setting up SSH / SFTP"
sleep 2
echo "What is the username for SFTP Access?"
read ftplogin
ufw allow 22
groupadd sftp
useradd -g sftp -d /var/www/$domain -s /sbin/nologin $ftplogin
chown $ftplogin:sftp /var/www/$domain
#Append Write to file /etc/ssh/sshd_config
  # AllowGroups ssh sftp
  # Match Group sftp
  # ChrootDirectory /var/www/$domain
  # ForceCommand internal-sftp
echo -e "AllowGroups ssh sftp \nMatch Group sftp \nChrootDirectory /var/www/$domain \nForceCommand internal-sftp" >> /etc/ssh/sshd_config
systemctl reload sshd
