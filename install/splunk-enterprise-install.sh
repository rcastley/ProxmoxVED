#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: rcastley
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.splunk.com/en_us/download.html

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

get_latest_version() {
    URL="https://www.splunk.com/en_us/download/splunk-enterprise.html"
    DEB_URL=$(curl -s "$URL" | grep -o 'data-link="[^"]*' | sed 's/data-link="//' | \
    grep "https.*products/splunk/releases" | \
    grep "\.deb$")
}

msg_info "Installing Dependencies"
$STD apt-get install -y curl
msg_ok "Installed Dependencies"

msg_info "Downloading Splunk Enterprise"
$STD curl -fsSL -o splunk-enterprise.deb $DEB_URL || {
    msg_error "Failed to download Splunk Enterprise from the provided link."
    exit 1
}
msg_ok "Downloaded Splunk Enterprise"

msg_info "Installing Splunk Enterprise"
$STD dpkg -i splunk-enterprise.deb || {
    msg_error "Failed to install Splunk Enterprise. Please check the .deb file."
    exit 1
}
msg_ok "Installed Splunk Enterprise"

msg_info "Creating Splunk admin user"
# Define the target directory and file
TARGET_DIR="/opt/splunk/etc/system/local"
TARGET_FILE="${TARGET_DIR}/user-seed.conf"
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
{
    echo "Application-Credentials"
    echo "Username: $ADMIN_USER"
    echo "Password: $ADMIN_PASS"
} >> ~/application.creds

cat > "$TARGET_FILE" << EOF
[user_info]
USERNAME = $ADMIN_USER
PASSWORD = $ADMIN_PASS
EOF
msg_ok "Created Splunk admin user"

msg_info "Starting Splunk Enterprise"
$STD /opt/splunk/bin/splunk start --accept-license --answer-yes --no-prompt
$STD /opt/splunk/bin/splunk enable boot-start
msg_ok "Splunk Enterprise started"

motd_ssh
customize

msg_info "Cleaning up"
$STD rm -f splunk-enterprise.deb
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
