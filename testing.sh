#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://ubuntu.com/

# App Default Values
echo -e "Loading..."
APP="Ubuntu"
var_tags="os"
var_cpu="1"
var_ram="512"
var_disk="2"
var_os="ubuntu"
var_version="24.04"

# App Output & Base Settings
header_info "$APP"
base_settings

# Core
variables
color
catch_errors

# Start container creation
start
build_container
description

# Display the current IP address of the container
msg_info "Fetching current IP address..."
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
    msg_error "Unable to fetch IP address!"
else
    msg_ok "Current IP Address: $IP_ADDRESS"
fi

# Final success message
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
