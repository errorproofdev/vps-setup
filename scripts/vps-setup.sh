#!/bin/bash

# VPS Configuration Script for Ubuntu 24.04
# Author: Generated Script
# Description: Comprehensive VPS setup for hosting various services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
}

# Load environment variables from .env if present
load_env() {
    if [[ -f "${ENV_FILE}" ]]; then
        log "Loading environment from ${ENV_FILE}"
        set -a
        # shellcheck source=/dev/null
        . "${ENV_FILE}"
        set +a
    fi
}

# Function to execute script on remote host via SSH
execute_remote() {
    local remote_host="${1:-}"
    local remote_user="${2:-ubuntu}"
    local remote_port="${3:-22}"
    
    if [[ -z "$remote_host" ]]; then
        error "No remote host specified"
        return 1
    fi

    log "Executing VPS setup on remote host: $remote_user@$remote_host:$remote_port"
    
    # Verify SSH connectivity
    if ! ssh -p "$remote_port" "$remote_user@$remote_host" -o ConnectTimeout=5 "echo 'SSH connection test'" > /dev/null 2>&1; then
        error "Cannot connect to $remote_user@$remote_host:$remote_port"
        return 1
    fi
    success "SSH connection verified to $remote_user@$remote_host"

    # Build environment variable string for remote execution
    local env_vars=""
    local critical_vars=(
        "UBUNTU_USER"
        "SSH_PORT"
        "ALLOW_PUBLIC_SSH"
        "INSTALL_TAILSCALE"
        "INSTALL_NGINX"
        "SSH_PUBKEY"
        "TAILSCALE_HOSTNAME"
        "TAILSCALE_AUTH_KEY"
        "UBUNTU_SUDO"
        "UBUNTU_SUDOERS"
        "UBUNTU_SUDOERS_CMDS"
        "APP_GROUP"
    )

    for var in "${critical_vars[@]}"; do
        if eval "[[ -n \${$var+x} ]]"; then
            local value="${!var}"
            env_vars="${env_vars} ${var}=\"${value//\"/\\\"}\""
        fi
    done

    log "Transferring and executing setup script on remote host..."
    
    # Send script to remote host and execute with preserved environment
    cat "${BASH_SOURCE[0]}" | ssh -p "$remote_port" "$remote_user@$remote_host" \
        "cd /tmp && ${env_vars} sudo bash" || {
        error "Remote execution failed"
        return 1
    }

    success "Remote VPS setup completed successfully"
    return 0
}

# Function to show help/usage
show_help() {
        cat << 'EOF'
VPS Setup Script (Ubuntu 24.04)

Usage:
    # Local execution (on target VPS)
    sudo ./vps-setup.sh [--help]

    # Remote execution (from local machine)
    SSH_HOST="192.168.1.100" SSH_USER="ubuntu" SSH_PORT="22" ./vps-setup.sh

Configurable environment variables:
    # SSH Configuration (for remote execution)
    SSH_HOST              Default: (empty) Target host (triggers remote mode)
    SSH_USER              Default: ubuntu  SSH username for remote execution
    SSH_PORT              Default: 22      SSH port for remote execution
    
    # VPS Configuration
    ENV_FILE              Default: ./.env
    UBUNTU_USER           Default: ubuntu
    SSH_PORT              Default: 22
    ALLOW_PUBLIC_SSH      Default: false   (true|false)
    INSTALL_TAILSCALE     Default: true    (true|false)
    INSTALL_NGINX         Default: true    (true|false)
    SSH_PUBKEY            Default: (empty) Public key to add for ubuntu user
    TAILSCALE_HOSTNAME           Default: node-steelgem
    TAILSCALE_AUTH_KEY            Default: (empty) Tailscale auth key for non-interactive setup

User policy:
    UBUNTU_SUDO           Default: false   (true|false)
    UBUNTU_SUDOERS        Default: false   (true|false)
    UBUNTU_SUDOERS_CMDS   Default: /usr/bin/systemctl,/usr/bin/pm2,/usr/sbin/nginx,/usr/bin/apt-get
    APP_GROUP             Default: apps

Examples:
    # Local - Grant sudoers to app user
    UBUNTU_SUDOERS=true \
    UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx" \
    sudo ./vps-setup.sh

    # Local - With Tailscale
    TAILSCALE_AUTH_KEY="tskey-..." TAILSCALE_HOSTNAME="node-steelgem" sudo ./vps-setup.sh

    # Remote - Using IP address
    SSH_HOST="192.168.1.100" SSH_USER="ubuntu" ./vps-setup.sh

    # Remote - Using hostname with .env
    cp .env.example .env
    # Edit .env with SSH_HOST, SSH_USER, SSH_PORT
    ./vps-setup.sh

    # Remote - Override SSH settings
    SSH_HOST="sql-steelgem" SSH_USER="ubuntu" SSH_PORT="2222" \
    UBUNTU_SUDOERS=true ./vps-setup.sh
EOF
}

load_env

# Configuration variables
UBUNTU_USER="${UBUNTU_USER:-ubuntu}"
SSH_PORT="${SSH_PORT:-22}"

# User policy (default: ubuntu is non-sudo app/CI user)
UBUNTU_SUDO="${UBUNTU_SUDO:-false}"      # true|false
APP_GROUP="${APP_GROUP:-apps}"          # application/CI group
UBUNTU_SUDOERS="${UBUNTU_SUDOERS:-false}" # true|false (create sudoers rule)
# Comma-separated list of allowed sudo commands when UBUNTU_SUDOERS=true
UBUNTU_SUDOERS_CMDS="${UBUNTU_SUDOERS_CMDS:-/usr/bin/systemctl,/usr/bin/pm2,/usr/sbin/nginx,/usr/bin/apt-get}"

# Public SSH is discouraged when using Tailscale SSH
ALLOW_PUBLIC_SSH="${ALLOW_PUBLIC_SSH:-false}"  # true|false

INSTALL_TAILSCALE="${INSTALL_TAILSCALE:-true}" # true|false
INSTALL_NGINX="${INSTALL_NGINX:-true}"         # true|false

# Optional: provide SSH public key for ubuntu user
SSH_PUBKEY="${SSH_PUBKEY:-}"

# Tailscale options (TAILSCALE_AUTH_KEY enables non-interactive)
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-node-steelgem}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"

# Function to detect if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "Running as root user"
        return 0
    else
        error "This script must be run as root"
        exit 1
    fi
}

# Function to update system packages
update_system() {
    log "Updating system packages..."
    
    # Update package lists
    apt-get update -y
    
    # Upgrade existing packages
    apt-get upgrade -y
    
    # Install basic utilities
    apt-get install -y curl wget git vim htop tree unzip software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release build-essential \
        screen tmux fail2ban ufw
    
    # Remove unnecessary packages
    apt-get autoremove -y
    apt-get autoclean
    
    success "System updated successfully"
}

# Function to create ubuntu user
create_ubuntu_user() {
    log "Setting up ${UBUNTU_USER} user..."

    if id "${UBUNTU_USER}" &>/dev/null; then
        warning "User ${UBUNTU_USER} already exists"
    else
        adduser --disabled-password --gecos "" "${UBUNTU_USER}"
        success "User ${UBUNTU_USER} created successfully"
    fi

    # Ensure application group exists and add ubuntu user
    if ! getent group "${APP_GROUP}" >/dev/null 2>&1; then
        groupadd "${APP_GROUP}"
    fi
    usermod -aG "${APP_GROUP}" "${UBUNTU_USER}"

    if [[ "${UBUNTU_SUDO}" == "true" ]]; then
        usermod -aG sudo "${UBUNTU_USER}"
        log "Granted sudo to ${UBUNTU_USER} (UBUNTU_SUDO=true)"
    else
        log "Leaving ${UBUNTU_USER} without sudo (UBUNTU_SUDO=false)"
    fi

    if [[ "${UBUNTU_SUDOERS}" == "true" ]]; then
        local sudoers_file="/etc/sudoers.d/${UBUNTU_USER}-apps"
        local cmd_list
        cmd_list=$(echo "${UBUNTU_SUDOERS_CMDS}" | tr ',' ',')
        log "Creating sudoers rule for ${UBUNTU_USER} (UBUNTU_SUDOERS=true)"
        cat > "${sudoers_file}" << EOF
# Allow limited sudo commands for ${UBUNTU_USER}
${UBUNTU_USER} ALL=(ALL) NOPASSWD: ${cmd_list}
EOF
        chmod 0440 "${sudoers_file}"
        if visudo -cf "${sudoers_file}"; then
            success "Sudoers rule validated: ${sudoers_file}"
        else
            rm -f "${sudoers_file}"
            warning "Invalid sudoers rule removed: ${sudoers_file}"
        fi
    fi

    # Ensure .ssh exists
    install -d -m 0700 -o "${UBUNTU_USER}" -g "${UBUNTU_USER}" "/home/${UBUNTU_USER}/.ssh"
    touch "/home/${UBUNTU_USER}/.ssh/authorized_keys"
    chown "${UBUNTU_USER}:${UBUNTU_USER}" "/home/${UBUNTU_USER}/.ssh/authorized_keys"
    chmod 0600 "/home/${UBUNTU_USER}/.ssh/authorized_keys"

    # Copy authorized_keys from root if exists
    if [[ -f "/root/.ssh/authorized_keys" ]]; then
        cat "/root/.ssh/authorized_keys" >> "/home/${UBUNTU_USER}/.ssh/authorized_keys" || true
    fi

    # Add provided SSH_PUBKEY (idempotent)
    if [[ -n "${SSH_PUBKEY}" ]]; then
        grep -Fq "${SSH_PUBKEY}" "/home/${UBUNTU_USER}/.ssh/authorized_keys" \
            || echo "${SSH_PUBKEY}" >> "/home/${UBUNTU_USER}/.ssh/authorized_keys"
    fi
}

# Function to configure SSH
configure_ssh() {
    log "Hardening SSH..."

    local SSH_CONFIG="/etc/ssh/sshd_config"
    cp -a "${SSH_CONFIG}" "${SSH_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    set_sshd() {
        local key="$1" value="$2"
        if grep -qE "^[#[:space:]]*${key}[[:space:]]+" "${SSH_CONFIG}"; then
            sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "${SSH_CONFIG}"
        else
            echo "${key} ${value}" >> "${SSH_CONFIG}"
        fi
    }

    set_sshd "Port" "${SSH_PORT}"
    set_sshd "PermitRootLogin" "no"
    set_sshd "PasswordAuthentication" "no"
    set_sshd "KbdInteractiveAuthentication" "no"
    set_sshd "ChallengeResponseAuthentication" "no"
    set_sshd "PubkeyAuthentication" "yes"

    systemctl reload ssh || systemctl restart ssh

    success "SSH hardened"
}

# Function to install Tailscale
install_tailscale() {
    if [[ "${INSTALL_TAILSCALE}" != "true" ]]; then
        log "Skipping Tailscale installation"
        return
    fi

    log "Installing Tailscale..."

    if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi

    systemctl enable --now tailscaled

    # Bring up Tailscale (interactive unless TAILSCALE_AUTH_KEY is provided)
    if [[ -n "${TAILSCALE_AUTH_KEY}" ]]; then
        tailscale up --ssh --hostname "${TAILSCALE_HOSTNAME}" --authkey "${TAILSCALE_AUTH_KEY}" || true
    else
        tailscale up --ssh --hostname "${TAILSCALE_HOSTNAME}" || true
    fi

    success "Tailscale installed (and 'tailscale up' attempted)"
}

# Function to configure firewall
configure_firewall() {
    log "Configuring firewall (UFW)..."

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    if [[ "${ALLOW_PUBLIC_SSH}" == "true" ]]; then
        ufw allow "${SSH_PORT}/tcp" comment "SSH"
    fi

    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"

    ufw --force enable

    success "Firewall configured successfully"
    ufw status verbose
}

# Function to install NGINX
install_nginx() {
    if [[ "${INSTALL_NGINX}" != "true" ]]; then
        log "Skipping NGINX installation"
        return
    fi

    log "Installing NGINX..."
    apt-get install -y nginx

    # Disable default site; WordPress site blocks should be created in sites-available
    rm -f /etc/nginx/sites-enabled/default || true

    systemctl enable nginx
    systemctl restart nginx

    success "NGINX installed"
}

# Function to configure fail2ban
configure_fail2ban() {
    log "Configuring fail2ban..."
    
    # Create fail2ban configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600
EOF
    
    # Restart fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    success "fail2ban configured successfully"
}

# Function to show system information
show_system_info() {
    log "System Information:"
    echo "----------------------------------------"
    echo "Hostname: $(hostname)"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
    IP_LOCAL=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    echo "IP Address: ${IP_LOCAL:-Unknown}"
    echo "----------------------------------------"
}

# Function to display next steps
show_next_steps() {
    log "Setup completed successfully!"
    echo
    echo "Next Steps:"
    echo "1. (If needed) Authenticate Tailscale: tailscale up"
    echo "2. Verify Tailscale SSH: ssh ${UBUNTU_USER}@${TAILSCALE_HOSTNAME}"
    echo "3. If verified, keep public SSH closed (ALLOW_PUBLIC_SSH=false)"
    echo "4. Configure your applications/services"
    echo
    echo "Useful Commands:"
    echo "- Check firewall: ufw status"
    echo "- Check NGINX: systemctl status nginx"
    echo "- Check fail2ban: systemctl status fail2ban"
    echo "- View logs: journalctl -f"
}

# Main execution function
main() {
    log "Starting VPS configuration for Ubuntu 24.04"

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # Check if SSH_HOST is provided (remote mode)
    if [[ -n "${SSH_HOST:-}" ]]; then
        log "Remote execution mode detected"
        SSH_USER="${SSH_USER:-ubuntu}"
        SSH_PORT="${SSH_PORT:-22}"
        execute_remote "$SSH_HOST" "$SSH_USER" "$SSH_PORT"
        exit $?
    fi
    
    # Local execution mode
    # Check if running as root
    check_root
    
    # Show system info
    show_system_info
    
    # Run configuration steps
    update_system
    create_ubuntu_user
    install_tailscale
    configure_firewall
    install_nginx
    configure_fail2ban
    configure_ssh
    
    # Show completion message
    show_next_steps
    
    success "VPS configuration completed!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi