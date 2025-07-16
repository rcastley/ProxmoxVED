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
echo -e "${TAB3}┌─────────────────────────────────────────────────────────────────────────┐"
echo -e "${TAB3}│                          SPLUNK GENERAL TERMS                           │"
echo -e "${TAB3}└─────────────────────────────────────────────────────────────────────────┘"
echo ""
echo -e "${TAB3}Before proceeding with the Splunk Enterprise installation, you must"
echo -e "${TAB3}review and accept the Splunk General Terms."
echo ""
echo -e "${TAB3}Please review the terms at:"
echo -e "${TAB3}${GATEWAY}${BGN}https://www.splunk.com/en_us/legal/splunk-general-terms.html${CL}"
echo ""

while true; do
    echo -e "${TAB3}Do you accept the Splunk General Terms? (y/N): \c"
    read -r response
    case $response in
        [Yy]|[Yy][Ee][Ss])
            msg_ok "Terms accepted. Proceeding with installation..."
            break
            ;;
        [Nn]|[Nn][Oo]|"")
            msg_error "Terms not accepted. Installation cannot proceed."
            msg_error "Please review the terms and run the script again if you wish to proceed."
            exit 1
            ;;
        *)
            msg_error "Invalid response. Please enter 'y' for yes or 'n' for no."
            ;;
    esac
done

# Prompt user to choose between stable and beta version
echo ""
echo -e "${TAB3}┌─────────────────────────────────────────────────────────────────────────┐"
echo -e "${TAB3}│                         VERSION SELECTION                               │"
echo -e "${TAB3}└─────────────────────────────────────────────────────────────────────────┘"
echo ""
echo -e "${TAB3}Choose which version of Splunk Enterprise to install:"
echo -e "${TAB3}  1) Stable release (latest production version)"
echo -e "${TAB3}  2) Beta release (v10.0.0 - for testing purposes)"
echo ""

while true; do
    echo -e "${TAB3}Enter your choice (1 for stable, 2 for beta) [1]: \c"
    read -r version_choice
    case $version_choice in
        ""|1)
            INSTALL_BETA=false
            msg_ok "Selected stable release"
            break
            ;;
        2)
            INSTALL_BETA=true
            msg_ok "Selected beta release"
            break
            ;;
        *)
            msg_error "Invalid choice. Please enter '1' for stable or '2' for beta."
            ;;
    esac
done

if [ "$INSTALL_BETA" = true ]; then
    # Beta version
    DEB_URL="https://download.splunk.com/products/splunk/beta/10.0.0-20250530/linux/splunkbeta-10.0.0-424dcd67496a-linux-amd64.deb"
    VERSION="10.0.0-beta"
    DEB_FILE="splunk-beta.deb"
else
    # Stable version
    URL="https://www.splunk.com/en_us/download/splunk-enterprise.html"
    DEB_URL=$(curl -s "$URL" | grep -o 'data-link="[^"]*' | sed 's/data-link="//' | grep "https.*products/splunk/releases" | grep "\.deb$")
    VERSION=$(echo "$DEB_URL" | sed 's|.*/releases/\([^/]*\)/.*|\1|')
    DEB_FILE="splunk-enterprise.deb"
fi

msg_info "Installing Dependencies"
$STD apt-get install -y curl
msg_ok "Installed Dependencies"

if [ "$INSTALL_BETA" = true ]; then
    msg_info "Downloading Splunk Enterprise Beta"
else
    msg_info "Downloading Splunk Enterprise"
fi

$STD curl -fsSL -o "$DEB_FILE" "$DEB_URL" || {
    msg_error "Failed to download Splunk Enterprise from the provided link."
    exit 1
}

if [ "$INSTALL_BETA" = true ]; then
    msg_ok "Downloaded Splunk Enterprise Beta v${VERSION}"
else
    msg_ok "Downloaded Splunk Enterprise v${VERSION}"
fi

if [ "$INSTALL_BETA" = true ]; then
    msg_info "Installing Splunk Enterprise Beta"
else
    msg_info "Installing Splunk Enterprise"
fi

$STD dpkg -i "$DEB_FILE" || {
    msg_error "Failed to install Splunk Enterprise. Please check the .deb file."
    exit 1
}

if [ "$INSTALL_BETA" = true ]; then
    msg_ok "Installed Splunk Enterprise Beta v${VERSION}"
else
    msg_ok "Installed Splunk Enterprise v${VERSION}"
fi

msg_info "Creating Splunk admin user"
# Define the target directory and file based on version
if [ "$INSTALL_BETA" = true ]; then
    SPLUNK_HOME="/opt/splunkbeta"
else
    SPLUNK_HOME="/opt/splunk"
fi

TARGET_DIR="${SPLUNK_HOME}/etc/system/local"
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

if [ "$INSTALL_BETA" = true ]; then
    msg_info "Starting Splunk Enterprise Beta"
else
    msg_info "Starting Splunk Enterprise"
fi

$STD ${SPLUNK_HOME}/bin/splunk start --accept-license --answer-yes --no-prompt
$STD ${SPLUNK_HOME}/bin/splunk enable boot-start

if [ "$INSTALL_BETA" = true ]; then
    msg_ok "Splunk Enterprise Beta started"
else
    msg_ok "Splunk Enterprise started"
fi

motd_ssh
customize

msg_info "Cleaning up"
$STD rm -f "$DEB_FILE"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
