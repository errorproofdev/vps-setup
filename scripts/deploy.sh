#!/bin/bash

# Quick deployment script for common VPS configurations
# Supports both local and remote execution via SSH
# 
# Usage: ./deploy.sh [config-type] [--local|--remote]
# Examples:
#   ./deploy.sh web                    # Local execution
#   SSH_HOST="192.168.1.100" ./deploy.sh web  # Remote execution
#   ./deploy.sh web --remote --host 192.168.1.100

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

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

load_env

# Check if running as root (for local execution)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root for local execution"
        echo "For remote execution, use: SSH_HOST=\"hostname\" ./deploy.sh [config]"
        exit 1
    fi
}

# Function to execute deployment on remote host
deploy_remote() {
    local remote_host="${1:-}"
    local remote_user="${2:-ubuntu}"
    local remote_port="${3:-22}"
    local config="${4:-minimal}"

    if [[ -z "$remote_host" ]]; then
        error "No remote host specified"
        return 1
    fi

    log "Deploying configuration '$config' on remote host: $remote_user@$remote_host:$remote_port"
    
    # Verify SSH connectivity
    if ! ssh -p "$remote_port" "$remote_user@$remote_host" -o ConnectTimeout=5 "echo 'SSH connection test'" > /dev/null 2>&1; then
        error "Cannot connect to $remote_user@$remote_host:$remote_port"
        return 1
    fi
    success "SSH connection verified"

    # Send vps-setup.sh to remote and execute it
    log "Transferring VPS setup script to remote host..."
    cat "${SCRIPT_DIR}/vps-setup.sh" | ssh -p "$remote_port" "$remote_user@$remote_host" \
        "cd /tmp && sudo bash -c 'cat > vps-setup.sh && chmod +x vps-setup.sh && ./vps-setup.sh'" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        success "Remote deployment completed"
        return 0
    else
        error "Remote deployment failed"
        return 1
    fi
}

# Function to download and run main script (local)
run_main_script() {
    log "Running main VPS setup script..."
    if [[ -f "${SCRIPT_DIR}/vps-setup.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/vps-setup.sh"
        "${SCRIPT_DIR}/vps-setup.sh"
    else
        echo "Error: vps-setup.sh not found"
        exit 1
    fi
}

# Function to install specific services (local)
install_services() {
    local services=("$@")
    
    if [[ -f "${SCRIPT_DIR}/services.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/services.sh"
        for service in "${services[@]}"; do
            log "Installing service: $service"
            "${SCRIPT_DIR}/services.sh" "$service"
        done
    else
        echo "Error: services.sh not found"
        exit 1
    fi
}

# Basic web server configuration
deploy_web_server() {
    log "Deploying basic web server configuration..."
    run_main_script
    install_services "tailscale" "php" "ssl"
    success "Web server deployment completed"
}

# Database server configuration
deploy_database_server() {
    log "Deploying database server configuration..."
    run_main_script
    install_services "mysql" "postgresql" "redis"
    success "Database server deployment completed"
}

# Development server configuration
deploy_dev_server() {
    log "Deploying development server configuration..."
    run_main_script
    install_services "php" "nvm" "mysql" "redis" "docker"
    success "Development server deployment completed"
}

# Production server configuration
deploy_production_server() {
    log "Deploying production server configuration..."
    run_main_script
    install_services "tailscale" "php" "mysql" "redis" "docker" "backup" "ssl" "monitoring"
    success "Production server deployment completed"
}

# CI/CD server configuration
deploy_cicd_server() {
    log "Deploying CI/CD server configuration..."
    run_main_script
    install_services "docker" "gitlab-runner"
    success "CI/CD server deployment completed"
}

# Full stack configuration
deploy_full_stack() {
    log "Deploying full stack configuration..."
    run_main_script
    install_services "all"
    success "Full stack deployment completed"
}

# Minimal configuration
deploy_minimal() {
    log "Deploying minimal configuration..."
    run_main_script
    success "Minimal deployment completed"
}

# Show available configurations
show_configs() {
    echo "VPS Deployment Script - Configuration Options"
    echo "=============================================="
    echo
    echo "Available deployment configurations:"
    echo "1) minimal     - Core system only (NGINX, firewall, security)"
    echo "2) web         - Web server (PHP, SSL certificates)"
    echo "3) database    - Database server (MySQL, PostgreSQL, Redis)"
    echo "4) dev         - Development environment (PHP, Node.js, databases, Docker)"
    echo "5) production  - Production-ready server with monitoring and backups"
    echo "6) cicd        - CI/CD server (Docker, GitLab Runner)"
    echo "7) full        - Complete stack with all services"
    echo
    echo "Local Execution:"
    echo "  sudo ./deploy.sh [configuration]"
    echo "  sudo ./deploy.sh web         # Deploy web server"
    echo "  sudo ./deploy.sh production  # Deploy production server"
    echo
    echo "Remote Execution (via SSH, no sudo needed locally):"
    echo "  SSH_HOST=\"192.168.1.100\" ./deploy.sh [configuration]"
    echo "  SSH_HOST=\"192.168.1.100\" SSH_USER=\"ubuntu\" SSH_PORT=\"22\" ./deploy.sh web"
    echo
    echo "With .env configuration:"
    echo "  cp .env.example .env"
    echo "  # Edit .env with SSH_HOST, SSH_USER, SSH_PORT"
    echo "  ./deploy.sh web"
    echo
    echo "Or use command line overrides:"
    echo "  SSH_HOST=\"sql-steelgem\" ./deploy.sh minimal"
}

# Main execution
main() {
    # Check for remote execution mode
    if [[ -n "${SSH_HOST:-}" ]]; then
        log "Remote execution mode detected"
        SSH_USER="${SSH_USER:-ubuntu}"
        SSH_PORT="${SSH_PORT:-22}"
        
        local config="${1:-minimal}"
        deploy_remote "$SSH_HOST" "$SSH_USER" "$SSH_PORT" "$config"
        exit $?
    fi
    
    # Local execution mode
    check_root
    
    if [[ $# -eq 0 ]]; then
        show_configs
        exit 0
    fi
    
    local config=$1
    
    case $config in
        "minimal")
            deploy_minimal
            ;;
        "web")
            deploy_web_server
            ;;
        "database")
            deploy_database_server
            ;;
        "dev")
            deploy_dev_server
            ;;
        "production")
            deploy_production_server
            ;;
        "cicd")
            deploy_cicd_server
            ;;
        "full")
            deploy_full_stack
            ;;
        "help"|"-h"|"--help")
            show_configs
            ;;
        *)
            echo "Unknown configuration: $config"
            echo
            show_configs
            exit 1
            ;;
    esac
    
    echo
    log "Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Configure your applications"
    echo "2. Set up backups"
    echo "3. Configure monitoring"
    echo "4. Set up SSL certificates (if not done automatically)"
    echo
    echo "Server information:"
    IP_LOCAL=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    echo "- IP: ${IP_LOCAL:-Unknown}"
    echo "- Hostname: $(hostname)"
    echo "- Uptime: $(uptime -p)"
}

# Run main function
main "$@"