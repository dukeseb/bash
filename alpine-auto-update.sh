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

# Path for update, clean, and reboot script
SCRIPT_FILE="/usr/local/bin/daily-update-clean-reboot.sh"

# Create update, clean, and reboot script
cat > $SCRIPT_FILE << EOF
#!/bin/sh

# Run system updates
echo "Running apk update..."
apk update
apk upgrade

# Remove unnecessary packages and clean up
echo "Running apk autoremove..."
apk del \$(apk info -v | awk '/^i/ {print \$1}')

# Reboot the system
echo "Rebooting system..."
reboot
EOF

chmod +x $SCRIPT_FILE

# Set up the cron job
echo -e "${yellow}\nSetting up cron job for daily updates at $time_of_day${clear}"

# Add cron entry for daily updates at the specified time
echo "$time_of_day * * * * root $SCRIPT_FILE" >> /etc/crontab

# Start cron service if it's not running
echo -e "${cyan}\nStarting cron service...${clear}"
/etc/init.d/crond start
rc-update add crond

echo -e "${cyan}\nCron job set up successfully to run daily updates at $time_of_day and reboot the system.${clear}"
