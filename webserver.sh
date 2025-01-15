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
echo -e "${yellow}\n \nMaking Directory for $domain${clear}"
sleep 2
mkdir -p /var/www/$domain
echo -e "${green}\n \nWhat is the email associated with this domain?${clear}"
read email


#Install updates
echo -e "${yellow}\n \nChecking && Installing Updates${clear}"
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


#PHP Installation
echo -e "${green}\n \nDo you want to install PHP? (y/n)${clear}"
read -p "Choice: " install_php

if [[ "$install_php" =~ ^[Yy]$ ]]; then
    # Install PHP
    echo -e "${green}\n \nWhich PHP Version do you want to install? (ie 8.3)${clear}"
    read phpversion
    apt install -y software-properties-common apt-transport-https lsb-release ca-certificates wget 
    add-apt-repository ppa:ondrej/php
    # -old--> wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    # -old--> echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list 
    apt update
    apt -y install php$phpversion php$phpversion-{mysql,zip,bcmath,mbstring,xml,curl,gd}
    #systemctl restart apache2
    #apt -y install php$phpversion-{mysql,zip,bcmath,mbstring,xml,curl,gd}
    systemctl restart apache2
else
    echo -e "${magenta}Skipping PHP installation.${clear}"
    sleep 2
fi


#Install SFTP
echo -e "${yellow}\n \nSetting up SFTP${clear}"
sleep 2
echo -e "${green}What is the username for SFTP Access?${clear}"
read ftplogin
sleep 1
echo -e "${yellow}Creating SFTP User $ftplogin and Assigning User to $domain${clear}"
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


# Ask user if they want to set up the network share
echo -e "${green}\n \nWould you like to set up a Network Share? (y/n)${clear}"
read -p "Choice: " choice

if [[ "$choice" =~ ^[Yy]$ ]]; then
    #Mount Netowrk Share
    echo -e "${yellow}\n \nSetting Up Network Share${clear}"
    sleep 2
    echo -e "${green}What is the IP Address?${clear}"
    read ipaddress
    echo -e "${green}What is your Share Username?${clear}"
    read -s shareusername
    echo -e "${green}What is your Share Password?${clear}"
    read sharepasswd
    mkdir /mnt/share
    touch /credentials.cifs_user
    echo -e "USER=$shareusername \nPASSWORD=$sharepasswd" >> /credentials.cifs_user
    chmod 600 /credentials.cifs_user
    echo -e "\n//$ipaddress/Public /mnt/share cifs rw,nosuid,nodev,noexec,relatime,vers=3.0,sec=ntlmv2,cache=strict,credentials=/credentials.cifs_user,uid=1000,noforceuid,gid=1000,noforcegid,addr=192.168.2.4,file_mode=0777,dir_mode=0777,iocharset=utf8 0 0" >> /etc/fstab
else
    echo -e "${magenta}\n \nSkipping Network Share setup.${clear}"
    sleep 2
fi

#Setup Automatic Updates and Reboot
echo -e "${yellow}\n \nSetting Up Daily Automatic Updates and Reboot${clear}"
sleep 2

# Ask the user for the time of day they'd like the task to run (in 24-hour format)
echo -e "${green}\nPlease enter the time of day (24-hour format, e.g., 04:00) when you'd like the update to run:${clear}"
read -p "Enter time (HH:MM): " time_of_day

# Validate the time format (basic check for HH:MM)
if [[ ! "$time_of_day" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    echo -e "${red}\n \nInvalid time format. Please enter in HH:MM format (e.g., 04:00).${clear}"
    exit 1
fi

# Define paths for the service and timer files
SERVICE_FILE="/etc/systemd/system/daily-update-clean-reboot.service"
TIMER_FILE="/etc/systemd/system/daily-update-clean-reboot.timer"
SCRIPT_FILE="/usr/local/bin/daily-update-clean-reboot.sh"

# Create the bash script for updating, cleaning, and rebooting
echo -e "${yellow}\nCreating the update, clean, and reboot script...${clear}"
sleep 2

cat > $SCRIPT_FILE << EOF
#!/bin/bash

# Update package lists
echo "Running apt update..."
apt update -y

# Upgrade installed packages
echo "Running apt upgrade..."
apt upgrade -y

# Remove unnecessary packages
echo "Running apt autoremove..."
apt autoremove -y

# Clean up package cache
echo "Running apt clean..."
apt clean

# Reboot the system
echo "Rebooting system..."
reboot
EOF

# Make the script executable
chmod +x $SCRIPT_FILE

# Create the systemd service file
cat > $SERVICE_FILE << EOF
[Unit]
Description=Daily Update, Autoremove, Clean, and Reboot

[Service]
Type=oneshot
ExecStart=$SCRIPT_FILE
EOF

echo -e "${cyan}\nSystemd service created: $SERVICE_FILE${clear}"
sleep 2

# Create the systemd timer file
cat > $TIMER_FILE << EOF
[Unit]
Description=Run daily update, autoremove, clean, and reboot

[Timer]
OnCalendar=$time_of_day
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo -e "${cyan}\nSystemd timer created to run at $time_of_day: $TIMER_FILE${clear}"
sleep 2

# Reload systemd, enable and start the timer
systemctl daemon-reload
systemctl enable daily-update-clean-reboot.timer
systemctl start daily-update-clean-reboot.timer

echo -e "${cyan}\n \nSystemd timer enabled and started successfully.${clear}"
sleep 2


#Closing Information
echo -e "${yellow}\n \nThis is your current IP ADDRESS${clear}"
hostname -I
echo -e "${red}\nSystem will reboot in 5 seconds${clear}"
sleep 5
reboot
