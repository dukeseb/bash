#!/bin/bash

# =================================================================
#  FULL LAMP, SFTP & SMB AUTO-INSTALLER (Debian 12)
# =================================================================

# Color Palette
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- UI & Spinner Functions ---

print_header() {
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BOLD}${CYAN}          WEB SERVER PROVISIONING SCRIPT${NC}"
    echo -e "${BLUE}================================================================${NC}"
}

run_with_spinner() {
    local msg="$1"
    local cmd="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!
    
    tput civis 
    echo -ne "${BOLD}${MAGENTA}==>${NC} ${BOLD}$msg  ${NC}"
    
    local i=0
    while kill -0 $pid 2>/dev/null; do
        local frame=${spin:$((i % ${#spin})):1}
        printf "${CYAN}%s${NC}\b" "$frame"
        ((i++))
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    tput cnorm 
    if [ $exit_code -eq 0 ]; then
        echo -e "\b${GREEN}Done!${NC}"
    else
        echo -e "\b${RED}Error!${NC}"
        exit 1
    fi
}

# --- 1. User Input Section ---
print_header
echo -e "${YELLOW}[ PRIMARY CONFIGURATION ]${NC}"
read -p "  Website Domain (domain.com): " domain
read -p "  Admin Email: " email
echo -e "\n${BLUE}----------------------------------------------------------------${NC}"

# --- 2. System Core Setup ---
run_with_spinner "Preparing web directory..." "mkdir -p /var/www/$domain"
run_with_spinner "Updating system packages..." "apt update && apt upgrade -y"
run_with_spinner "Installing Apache & UFW..." "apt install apache2 ufw -y && systemctl enable apache2 --now"
run_with_spinner "Configuring Firewall (80, 443, 22)..." "ufw allow 80/tcp && ufw allow 443/tcp && ufw allow 22/tcp && echo 'y' | ufw enable"

# --- 3. Apache Virtual Host & Security ---
run_with_spinner "Creating Virtual Host config..." "cat <<EOF > /etc/apache2/sites-available/$domain.conf
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
EOF"

run_with_spinner "Activating site & disabling indexes..." "
a2dissite 000-default.conf && 
a2ensite $domain.conf && 
a2enmod speling && 
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/apache2/apache2.conf &&
systemctl restart apache2"

# --- 4. Test HTML Section ---
echo -e "\n${YELLOW}[ TEST PAGE ]${NC}"
read -p "  Create a test index.html file? (y/n): " mk_html
if [[ "$mk_html" =~ ^[Yy]$ ]]; then
    run_with_spinner "Generating index.html..." "cat <<EOF > /var/www/$domain/index.html
<!DOCTYPE html>
<html lang='en'>
<head><meta charset='UTF-8'><title>$domain Ready</title></head>
<body style='font-family:sans-serif;text-align:center;margin-top:100px;'>
    <h1>🚀 $domain is Online!</h1>
    <p>The web server is configured and running.</p>
</body>
</html>
EOF"
fi

# --- 5. PHP Installation Section ---
echo -e "\n${YELLOW}[ PHP RUNTIME ]${NC}"
read -p "  Install PHP? (y/n): " install_php
if [[ "$install_php" =~ ^[Yy]$ ]]; then
    read -p "  Version (e.g., 8.3): " phpversion
    run_with_spinner "Installing PHP $phpversion..." "apt install -y software-properties-common apt-transport-https lsb-release ca-certificates wget && add-apt-repository ppa:ondrej/php -y && apt update && apt -y install php$phpversion php$phpversion-{mysql,zip,bcmath,mbstring,xml,curl,gd} && systemctl restart apache2"
fi

# --- 6. SMB Share Section ---
echo -e "\n${YELLOW}[ SMB NETWORK SHARE ]${NC}"
read -p "  Connect to an SMB network share? (y/n): " smb_choice
if [[ "$smb_choice" =~ ^[Yy]$ ]]; then
    read -p "  Share IP: " ipaddress
    read -p "  Share Username: " shareusername
    read -s -p "  Share Password: " sharepasswd
    echo ""
    run_with_spinner "Configuring SMB mount..." "
    apt install cifs-utils -y &&
    mkdir -p /mnt/share &&
    echo -e 'USER=$shareusername\nPASSWORD=$sharepasswd' > /credentials.cifs_user &&
    chmod 600 /credentials.cifs_user &&
    echo '//$ipaddress/Public /mnt/share cifs rw,nosuid,nodev,noexec,relatime,vers=3.0,sec=ntlmv2,cache=strict,credentials=/credentials.cifs_user,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,iocharset=utf8 0 0' >> /etc/fstab"
fi

# --- 7. SFTP Access Section ---
echo -e "\n${YELLOW}[ SFTP ACCESS SETUP ]${NC}"
read -p "  Enable SFTP access? (y/n): " sftp_choice
if [[ "$sftp_choice" =~ ^[Yy]$ ]]; then
    read -p "  SFTP Username: " ftplogin
    groupadd sftpusers 2>/dev/null || true
    useradd -m -g sftpusers -s /bin/false "$ftplogin"
    echo -e "  ${CYAN}Set password for $ftplogin:${NC}"
    passwd "$ftplogin"

    run_with_spinner "Configuring SFTP Chroot..." "
    sed -i 's|Subsystem\s*sftp\s*/usr/lib/openssh/sftp-server|Subsystem sftp internal-sftp|' /etc/ssh/sshd_config &&
    printf \"Match Group sftpusers\n    X11Forwarding no\n    AllowTcpForwarding no\n    ChrootDirectory /var/www/\n    ForceCommand internal-sftp\n\" >> /etc/ssh/sshd_config &&
    systemctl restart ssh &&
    chown root:sftpusers /var/www &&
    chmod 755 /var/www &&
    chown $ftplogin:sftpusers /var/www/$domain"
fi

# --- 8. Maintenance Schedule Section ---
echo -e "\n${YELLOW}[ AUTOMATED MAINTENANCE ]${NC}"
read -p "  Enable daily updates and reboot? (y/n): " maint_choice
if [[ "$maint_choice" =~ ^[Yy]$ ]]; then
    read -p "  Daily Update Time (HH:MM): " time_of_day
    run_with_spinner "Setting up systemd timer..." "
    SCRIPT='/usr/local/bin/daily-update.sh'
    cat > \$SCRIPT << 'EOF'
#!/bin/bash
apt update && apt upgrade -y && apt autoremove -y && apt clean && reboot
EOF
    chmod +x \$SCRIPT
    cat > /etc/systemd/system/daily-update.service << EOF
[Unit]
Description=Daily Update and Reboot
[Service]
Type=oneshot
ExecStart=\$SCRIPT
EOF
    cat > /etc/systemd/system/daily-update.timer << EOF
[Unit]
Description=Run daily maintenance
[Timer]
OnCalendar=*-*-* $time_of_day:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload && systemctl enable --now daily-update.timer"
fi

# --- Final Message ---
echo -e "\n${BLUE}================================================================${NC}"
echo -e "${BOLD}${GREEN}          INSTALLATIONS COMPLETE${NC}"
echo -e "${BLUE}================================================================${NC}"
echo -e "${BOLD}Site URL:${NC} ${YELLOW}http://$(hostname -I | awk '{print $1}')/${NC}"
echo -e "${BOLD}SFTP User:${NC} $ftplogin"
echo -e "${RED}System will reboot in 5 seconds...${NC}"
sleep 5
reboot
