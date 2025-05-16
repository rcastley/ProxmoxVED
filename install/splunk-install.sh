#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: rcastley
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.splunk.com/en_us/download/splunk-enterprise.html

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl wget
msg_ok "Installed Dependencies"

msg_info "Installing Splunk Enterprise"
wget -qO splunk-9.4.2-e9664af3d956-linux-amd64.deb "https://download.splunk.com/products/splunk/releases/9.4.2/linux/splunk-9.4.2-e9664af3d956-linux-amd64.deb"
$STD dpkg -i splunk-9.4.2-e9664af3d956-linux-amd64.deb
msg_ok "Installed Splunk Enterprise"

msg_info "Creating Splunk admin user"
# Define the target directory and file
USERNAME="admin"
PASSWORD="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)"
TARGET_DIR="/opt/splunk/etc/system/local"
TARGET_FILE="${TARGET_DIR}/user-seed.conf"
cat > "$TARGET_FILE" << EOF
[user_info]
USERNAME = $USERNAME
PASSWORD = $PASSWORD
EOF
{
  echo "Splunk-Enteprise-Credentials"
  echo "Admin User: $USERNAME"
  echo "Admin Password: $PASSWORD"
} >>~/splunk-enterprise.creds
msg_ok "Created Splunk admin user"

msg_info "Starting Splunk Enterprise"
$STD /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
msg_ok "Splunk Enterprise started"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
