#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
#$STD apt-get install -y gnup
msg_ok "Installed Dependencies"

echo -e "fetching healthchecks"
fetch_and_deploy_gh_release "healthchecks" "healthchecks/healthchecks" "tarball" "latest" "/opt/healthchecks"
# minimal call: fetch_and_deploy_gh_release "healthchecks" "healthchecks/healthchecks" "tarball"
echo -e "healthchecks done"

echo -e "fetching defguard"
fetch_and_deploy_gh_release "defguard" "DefGuard/defguard" "binary" "latest" "/opt/defguard"
# minimal call: fetch_and_deploy_gh_release "defguard" "DefGuard/defguard" "binary"
echo -e "defguard done"

#PHP_VERSION=8.2 PHP_FPM=YES install_php
#install_composer

# Example Setting for Test
#NODE_MODULE="pnpm@10.1,yarn"
#RELEASE=$(curl_handler -fsSL https://api.github.com/repos/babybuddy/babybuddy/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
#msg_ok "Get Release $RELEASE"
#NODE_VERSION="22" NODE_MODULE="yarn" install_node_and_modules

#PG_VERSION="16" install_postgresql
#MARIADB_VERSION="11.8"
#MYSQL_VERSION="8.0"

#install_mongodb
#install_postgresql
#install_mariadb
#install_mysql

# msg_info "Setup DISTRO env"
# DISTRO="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
# msg_ok "Setup DISTRO"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

# read -p "Remove this script? <y/N> " prompt
# if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
#   pct stop "$CTID"
#   pct remove "$CTID"
#   msg_ok "Removed this script"
# else
#   msg_warn "Did not remove this script"
# fi
