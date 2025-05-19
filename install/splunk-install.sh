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

# Function to validate URL
validate_url() {
    local url=$1
    # Check if the URL is accessible
    if curl --output /dev/null --silent --head --fail "$url"; then
        return 0
    else
        return 1
    fi
}

# Prompt for Splunk download URL
echo -n "Enter Splunk Enterprise download URL: "
read SPLUNK_URL

# Validate the URL
msg_info "Validating download URL"
if ! validate_url "$SPLUNK_URL"; then
    msg_error "Invalid URL or URL not accessible. Exiting..."
    exit 1
fi
msg_ok "URL validated successfully"

# Extract filename from URL
SPLUNK_FILENAME=$(basename "$SPLUNK_URL")

msg_info "Installing Splunk Enterprise"
if ! wget -q -O "$SPLUNK_FILENAME" "$SPLUNK_URL"; then
    msg_error "Download failed. Exiting..."
    exit 1
fi

if ! $STD dpkg -i "$SPLUNK_FILENAME"; then
    msg_error "Installation failed. Exiting..."
    exit 1
fi
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
$STD rm -f "$SPLUNK_FILENAME"
msg_ok "Cleaned"
