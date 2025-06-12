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

# Prompt user to accept Splunk General Terms
echo -e "\033[1;33m┌─────────────────────────────────────────────────────────────────────────┐\033[0m"
echo -e "\033[1;33m│                          SPLUNK GENERAL TERMS                           │\033[0m"
echo -e "\033[1;33m└─────────────────────────────────────────────────────────────────────────┘\033[0m"
echo ""
echo -e "\033[1;37mBefore proceeding with the Splunk Enterprise installation, you must\033[0m"
echo -e "\033[1;37mreview and accept the Splunk General Terms.\033[0m"
echo ""
echo -e "\033[1;36mPlease review the terms at:\033[0m"
echo -e "\033[1;34mhttps://www.splunk.com/en_us/legal/splunk-general-terms.html\033[0m"
echo ""

while true; do
    echo -e "\033[1;37mDo you accept the Splunk General Terms? (y/N): \033[0m\c"
    read -r response
    case $response in
        [Yy]|[Yy][Ee][Ss])
            echo -e "\033[1;32m✓ Terms accepted. Proceeding with installation...\033[0m"
            echo ""
            break
            ;;
        [Nn]|[Nn][Oo]|"")
            echo -e "\033[1;31m✗ Terms not accepted. Installation cannot proceed.\033[0m"
            echo -e "\033[1;33mPlease review the terms and run the script again if you wish to proceed.\033[0m"
            exit 1
            ;;
        *)
            echo -e "\033[1;31mInvalid response. Please enter 'y' for yes or 'n' for no.\033[0m"
            ;;
    esac
done

URL="https://www.splunk.com/en_us/download/splunk-enterprise.html"

DEB_URL=$(curl -s "$URL" | grep -o 'data-link="[^"]*' | sed 's/data-link="//' | grep "https.*products/splunk/releases" | grep "\.deb$")
VERSION=$(echo "$DEB_URL" | sed 's|.*/releases/\([^/]*\)/.*|\1|')

msg_info "Installing Dependencies"
$STD apt-get install -y curl
msg_ok "Installed Dependencies"

msg_info "Downloading Splunk Enterprise"
$STD curl -fsSL -o splunk-enterprise.deb $DEB_URL || {
    msg_error "Failed to download Splunk Enterprise from the provided link."
    exit 1
}
msg_ok "Downloaded Splunk Enterprise v${VERSION}"

msg_info "Installing Splunk Enterprise"
$STD dpkg -i splunk-enterprise.deb || {
    msg_error "Failed to install Splunk Enterprise. Please check the .deb file."
    exit 1
}
msg_ok "Installed Splunk Enterprise v${VERSION}"

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
