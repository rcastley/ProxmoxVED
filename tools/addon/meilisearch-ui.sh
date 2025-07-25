#!/usr/bin/env bash

# community-scripts ORG | Meilisearch UI Addon Installer
# Author: MickLesk
# License: MIT

if command -v curl >/dev/null 2>&1; then
  source <(curl -fsSL https://git.community-scripts.org/community-scripts/ProxmoxVED/raw/branch/main/misc/core.func)
  load_functions
elif command -v wget >/dev/null 2>&1; then
  source <(wget -qO- https://git.community-scripts.org/community-scripts/ProxmoxVED/raw/branch/main/misc/core.func)
  load_functions
fi
source <(curl -fsSL https://git.community-scripts.org/community-scripts/ProxmoxVED/raw/branch/main/misc/tools.func)

color
catch_errors

APP="Meilisearch UI"
APP_TYPE="tools"
APP_DIR="/opt/meilisearch-ui"
SERVICE="meilisearch-ui"
REPO="riccox/meilisearch-ui"

header_info "$APP"

if ! command -v meilisearch >/dev/null || ! systemctl is-active --quiet meilisearch; then
  msg_error "Meilisearch is not installed or not running. Please install and start Meilisearch before using this addon."
  exit 1
fi

if ! grep -q -Ei 'debian|ubuntu' /etc/os-release; then
  msg_error "Unsupported OS. This addon supports only Debian or Ubuntu."
  exit 1
fi

MEM_MB=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo)
if ((MEM_MB < 4096)); then
  msg_error "Insufficient memory: ${MEM_MB} MB detected. At least 4096 MB RAM is required."
  exit 1
fi

IP=$(hostname -I | awk '{print $1}')
MASTER_KEY=$(grep -E '^master_key\s*=' /etc/meilisearch.toml | cut -d'"' -f2)

function is_installed() {
  [[ -d "$APP_DIR" ]] && systemctl is-active --quiet "$SERVICE"
}

function install_ui() {
  NODE_VERSION="22" NODE_MODULE="pnpm@latest" setup_nodejs
  fetch_and_deploy_gh_release "meilisearch-ui" "$REPO"

  msg_info "Setup ${APP}"
  cd "$APP_DIR" || exit 1
  sed -i 's|const hash = execSync("git rev-parse HEAD").toString().trim();|const hash = "unknown";|' vite.config.ts
  $STD pnpm install

  cat <<EOF >.env.local
VITE_SINGLETON_MODE=true
VITE_SINGLETON_HOST=http://${IP}:7700
VITE_SINGLETON_API_KEY=${MASTER_KEY}
EOF

  cat <<EOF >/etc/systemd/system/${SERVICE}.service
[Unit]
Description=${APP} Service
After=network.target meilisearch.service
Requires=meilisearch.service

[Service]
User=root
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${SERVICE}

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable -q --now "$SERVICE"
  msg_ok "${APP} installed at http://${IP}:24900"
}

function uninstall_ui() {
  msg_info "Stopping ${APP}"
  systemctl disable -q --now "$SERVICE"
  rm -f "/etc/systemd/system/${SERVICE}.service"
  systemctl daemon-reexec

  msg_info "Removing files"
  rm -rf "$APP_DIR"
  msg_ok "${APP} uninstalled"
}

function update_ui() {

  cp /opt/meilisearch-ui/.env.local /tmp/.env.local.bak

  NODE_VERSION="22" NODE_MODULE="pnpm@latest" setup_nodejs
  fetch_and_deploy_gh_release "meilisearch-ui" "$REPO"
  msg_info "Updating ${APP}"
  cd /opt/meilisearch-ui
  sed -i 's|const hash = execSync("git rev-parse HEAD").toString().trim();|const hash = "unknown";|' /opt/meilisearch-ui/vite.config.ts
  mv /tmp/.env.local.bak /opt/meilisearch-ui/.env.local
  $STD pnpm install
  systemctl restart "$SERVICE"
  msg_ok "${APP} updated"
}

if is_installed; then
  read -r -p "Update (1), Uninstall (2), Cancel (3)? [1/2/3]: " action
  action="${action//[[:space:]]/}"
  case "$action" in
  1) update_ui ;;
  2) uninstall_ui ;;
  3) msg_info "Cancelled" ;;
  *) msg_error "Invalid input" ;;
  esac
else
  read -r -p "Install ${APP}? (y/n): " answer
  answer="${answer//[[:space:]]/}"
  [[ "${answer,,}" =~ ^(y|yes)$ ]] && install_ui || msg_info "Installation skipped"
fi
