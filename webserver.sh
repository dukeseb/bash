#!/bin/bash

# References:
# https://www.linuxcapable.com/how-to-install-apache-on-debian-linux/
# https://reintech.io/blog/setting-up-sftp-secure-file-transfers-debian-12
# https://www.transip.eu/knowledgebase/entry/1851-installing-an-ssh-server-debian/?utm_source=knowledge%20base
# https://tecadmin.net/how-to-install-php-on-debian-12/
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mariadb-php-lamp-stack-on-debian-10
# https://www.digitalocean.com/community/tutorials/how-to-install-php-8-1-and-set-up-a-local-development-environment-on-ubuntu-22-04
# https://chatgpt.com is your friend ;)

# Set color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'

# Prompt for Domain Information
echo -e "${green}What is your website name? (only include root domain, e.g., domain.com)${clear}"
read domain
sleep 1
echo -e "${yellow}\nCreating directory for $domain${clear}"
sleep 2
mkdir -p /var/www/$domain

echo -e "${green}\nWhat is the email associated with this domain?${clear}"
read email

# Update system packages
echo -e "${yellow}\nChecking & Installing Updates${clear}"
sleep 2
apt update && apt upgrade -y

# Install Apache Web Server
echo -e "${yellow}\nInstalling Apache2 Web Server${clear}"
sleep 2
apt install apache2 -y
systemctl enable apache2 --now

# Install and configure UFW firewall
echo -e "${yellow}\nInstalling & Configuring UFW${clear}"
sleep 2
apt install ufw -y
ufw enable
ufw allow 80
ufw allow 443
ufw allow 22

# Setup Apache Virtual Host
echo -e "${yellow}\nSetting up Apache Virtual Host${clear}"
sleep 2
cat <<EOF > /etc/apache2/sites-available/$domain.conf
<VirtualHost *:80>
    ServerAdmin $email
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot /var/www/$domain
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    <IfModule mod_speling.c>
        CheckSpelling On
        CheckCaseOnly On
    </IfModule>
</VirtualHost>
EOF

a2dissite 000-default.conf
a2ensite $domain.conf
a2enmod speling

echo -e "${yellow}\nChecking Apache configuration syntax${clear}"
sleep 3
apache2ctl configtest
sleep 3

# Disable directory listing
echo -e "${yellow}\nDisabling Web Indexes${clear}"
sleep 3
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/apache2/apache2.conf

# Restart Apache
systemctl restart apache2

# PHP Installation (optional)
echo -e "${green}\nDo you want to install PHP? (y/n)${clear}"
read -p "Choice: " install_php

if [[ "$install_php" =~ ^[Yy]$ ]]; then
    echo -e "${green}\nWhich PHP version do you want to install? (e.g., 8.3)${clear}"
    read phpversion
    apt install -y software-properties-common apt-transport-https lsb-release ca-certificates wget 
    add-apt-repository ppa:ondrej/php
    apt update
    apt -y install php$phpversion php$phpversion-{mysql,zip,bcmath,mbstring,xml,curl,gd}
    systemctl restart apache2
else
    echo -e "${magenta}Skipping PHP installation.${clear}"
    sleep 2
fi

# Create test.html file
echo -e "${green}\nDo you want to create a test.html file to test the web server? (y/n): ${clear}"
read response
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

if [[ "$response" == "y" || "$response" == "yes" ]]; then
    cat <<EOF > "/var/www/$domain/test.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Server for $domain Enabled</title>
</head>
<body>
    <h1>Web Server for $domain Enabled</h1>
</body>
</html>
EOF
    echo -e "${cyan}\nTest.html file created in /var/www/$domain${clear}"
else
    echo -e "${yellow}\nSkipping creation of test.html file.${clear}"
fi

# Install and Configure SFTP
echo -e "${yellow}\nSetting up SFTP${clear}"
sleep 2
echo -e "${green}Enter the username for SFTP access:${clear}"
read ftplogin
sleep 1

# Create SFTP user
echo -e "${yellow}Creating SFTP user $ftplogin and assigning user to $domain${clear}"
sleep 2
groupadd sftpusers
useradd -m -g sftpusers -s /bin/false $ftplogin
echo -e "${green}\nEnter password for SFTP login:${clear}"
passwd $ftplogin

# Configure SSH for SFTP
sed -i 's|Subsystem\s*sftp\s*/usr/lib/openssh/sftp-server|Subsystem sftp internal-sftp|' /etc/ssh/sshd_config
cat <<EOF >> /etc/ssh/sshd_config
Match Group sftpusers
    X11Forwarding no
    AllowTcpForwarding no
    ChrootDirectory /var/www/
    ForceCommand internal-sftp
EOF

systemctl restart ssh
chown root:sftpusers /var/www
chmod 755 /var/www
chown $ftplogin:sftpusers /var/www/$domain

# Network Share Setup (Optional)
echo -e "${green}\nWould you like to connect to an SMB network share? (y/n)${clear}"
read choice

if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo -e "${green}Enter the share IP address:${clear}"
    read ipaddress
    echo -e "${green}Enter your share username:${clear}"
    read shareusername
    echo -e "${green}Enter your share password:${clear}"
    read -s sharepasswd

    mkdir /mnt/share
    touch /credentials.cifs_user
    echo -e "USER=$shareusername\nPASSWORD=$sharepasswd" > /credentials.cifs_user
    chmod 600 /credentials.cifs_user

    echo -e "\n//$ipaddress/Public /mnt/share cifs rw,nosuid,nodev,noexec,relatime,vers=3.0,sec=ntlmv2,cache=strict,credentials=/credentials.cifs_user,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,iocharset=utf8 0 0" >> /etc/fstab
else
    echo -e "${magenta}\nSkipping Network Share setup.${clear}"
    sleep 2
fi

# Automatic Updates and Reboot Setup
echo -e "${yellow}\nSetting up Daily Automatic Updates and Reboot${clear}"
sleep 2

echo -e "${green}\nPlease enter the time of day (24-hour format, e.g., 04:00) for daily updates:${clear}"
read -p "Enter time (HH:MM): " time_of_day

# Validate time format (basic check for HH:MM)
if [[ ! "$time_of_day" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    echo -e "${red}\nInvalid time format. Please use HH:MM format (e.g., 04:00).${clear}"
    exit 1
fi

# Paths for systemd service and timer files
SERVICE_FILE="/etc/systemd/system/daily-update-clean-reboot.service"
TIMER_FILE="/etc/systemd/system/daily-update-clean-reboot.timer"
SCRIPT_FILE="/usr/local/bin/daily-update-clean-reboot.sh"

# Create update, clean, and reboot script
cat > $SCRIPT_FILE << EOF
#!/bin/bash

# Run system updates
echo "Running apt update..."
apt update -y
apt upgrade -y

# Remove unnecessary packages and clean up
echo "Running apt autoremove..."
apt autoremove -y
apt clean

# Reboot the system
echo "Rebooting system..."
reboot
EOF

chmod +x $SCRIPT_FILE

# Create systemd service file
cat > $SERVICE_FILE << EOF
[Unit]
Description=Daily Update, Autoremove, Clean, and Reboot

[Service]
Type=oneshot
ExecStart=$SCRIPT_FILE
EOF

# Create systemd timer file
cat > $TIMER_FILE << EOF
[Unit]
Description=Run daily update, autoremove, clean, and reboot

[Timer]
OnCalendar=$time_of_day
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start systemd timer
systemctl daemon-reload
systemctl enable daily-update-clean-reboot.timer
systemctl start daily-update-clean-reboot.timer

echo -e "${cyan}\nSystemd timer enabled and started successfully.${clear}"

# Final message and reboot
echo -e "${green}\n \nVerify your website is online at http://$(hostname -I | tr -d ' ')/test.html${clear}"
sleep 2
echo -e "${red}\nSystem will reboot in 5 seconds.${clear}"
sleep 5
reboot
