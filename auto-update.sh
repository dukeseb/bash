#!/bin/bash

# Set color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
clear='\033[0m'

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
