#!/bin/bash
# Purpose: Create and configure ubuntu and appuser on fresh VPS
# Run as: sudo bash setup-system-users.sh
# Status: First-time VPS user setup

set -euo pipefail

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    echo -e "\033[0;34m[$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $*"
}

success() {
    echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] ✓\033[0m $*"
}

warning() {
    echo -e "\033[0;33m[$(date '+%Y-%m-%d %H:%M:%S')] ⚠\033[0m $*"
}

error() {
    echo -e "\033[0;31m[$(date '+%Y-%m-%d %H:%M:%S')] ✗\033[0m $*"
}

# ============================================================================
# Main Setup
# ============================================================================

main() {
    log "Starting system user setup on $(hostname)"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        return 1
    fi
    
    echo ""
    log "========================================="
    log "Phase 1: Create ubuntu User"
    log "========================================="
    
    # Check if ubuntu user exists
    if id ubuntu &>/dev/null; then
        warning "ubuntu user already exists, skipping creation"
    else
        log "Creating ubuntu user..."
        useradd -m -s /bin/bash -G sudo ubuntu || {
            error "Failed to create ubuntu user"
            return 1
        }
        success "Created ubuntu user"
    fi
    
    # Ensure sudo group exists
    groupmod -n sudo sudo 2>/dev/null || {
        log "Creating sudo group..."
        groupadd sudo || true
    }
    
    # Ensure ubuntu is in sudo group
    if ! groups ubuntu | grep -q sudo; then
        log "Adding ubuntu to sudo group..."
        usermod -a -G sudo ubuntu || {
            error "Failed to add ubuntu to sudo group"
            return 1
        }
        success "Added ubuntu to sudo group"
    fi
    
    # Configure passwordless sudo for ubuntu
    log "Configuring passwordless sudo for ubuntu..."
    
    # Ensure sudoers.d exists
    mkdir -p /etc/sudoers.d
    
    cat > /etc/sudoers.d/ubuntu << 'EOF'
# Allow ubuntu user to run all commands without password
ubuntu ALL=(ALL) NOPASSWD:ALL
EOF
    
    chmod 440 /etc/sudoers.d/ubuntu || {
        error "Failed to set sudoers permissions"
        return 1
    }
    success "Configured passwordless sudo"
    
    # Set up SSH directory for ubuntu
    log "Setting up SSH directory for ubuntu..."
    ubuntu_ssh_dir="/home/ubuntu/.ssh"
    mkdir -p "$ubuntu_ssh_dir"
    chmod 700 "$ubuntu_ssh_dir"
    chown -R ubuntu:ubuntu "$ubuntu_ssh_dir"
    success "SSH directory ready at $ubuntu_ssh_dir"
    
    echo ""
    log "========================================="
    log "Phase 2: Create appuser (Non-root Apps)"
    log "========================================="
    
    # Check if appuser exists
    if id appuser &>/dev/null; then
        warning "appuser already exists, skipping creation"
    else
        log "Creating appuser with /usr/sbin/nologin..."
        useradd -m -s /usr/sbin/nologin appuser || {
            error "Failed to create appuser"
            return 1
        }
        success "Created appuser"
    fi
    
    echo ""
    log "========================================="
    log "Phase 3: Create Application Directories"
    log "========================================="
    
    # Create application directories
    app_dirs=(
        "/var/www/apps"
        "/var/www/apps/detoxnearme"
        "/var/www/apps/edge-nextjs"
        "/var/www/apps/forge-nextjs"
        "/var/run/pm2"
        "/var/log/pm2"
    )
    
    for dir in "${app_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            warning "Directory already exists: $dir"
        else
            log "Creating directory: $dir"
            mkdir -p "$dir" || {
                error "Failed to create $dir"
                return 1
            }
        fi
        
        # Set ownership and permissions
        chown appuser:appuser "$dir"
        chmod 755 "$dir"
        log "Set ownership to appuser:appuser for $dir"
    done
    
    success "Application directories created and owned by appuser"
    
    echo ""
    log "========================================="
    log "Phase 4: Verify Configuration"
    log "========================================="
    
    # Check ubuntu user
    log "Checking ubuntu user..."
    if id ubuntu &>/dev/null; then
        ubuntu_uid=$(id -u ubuntu)
        ubuntu_shell=$(getent passwd ubuntu | cut -d: -f7)
        ubuntu_groups=$(groups ubuntu | cut -d: -f2)
        success "ubuntu user exists"
        log "  UID: $ubuntu_uid"
        log "  Shell: $ubuntu_shell"
        log "  Groups:$ubuntu_groups"
    else
        error "ubuntu user not found!"
        return 1
    fi
    
    # Test sudo access
    log "Testing passwordless sudo for ubuntu..."
    if sudo -u ubuntu -l &>/dev/null; then
        success "ubuntu can run sudo commands"
    else
        warning "Could not verify sudo access for ubuntu"
    fi
    
    # Check appuser
    log "Checking appuser..."
    if id appuser &>/dev/null; then
        appuser_uid=$(id -u appuser)
        appuser_shell=$(getent passwd appuser | cut -d: -f7)
        success "appuser exists"
        log "  UID: $appuser_uid"
        log "  Shell: $appuser_shell (should be /usr/sbin/nologin)"
    else
        error "appuser not found!"
        return 1
    fi
    
    # Check directory ownership
    log "Checking directory ownership..."
    for dir in "${app_dirs[@]}"; do
        owner=$(stat -f "%Su:%Sg" "$dir" 2>/dev/null || stat -c "%U:%G" "$dir")
        mode=$(stat -f "%A" "$dir" 2>/dev/null || stat -c "%a" "$dir")
        log "  $dir → $owner ($mode)"
    done
    
    echo ""
    log "========================================="
    log "✓ System User Setup Complete!"
    log "========================================="
    
    cat << 'EOF'

Users are now configured:
  • ubuntu   - SSH access, passwordless sudo (/bin/bash)
  • appuser  - Application runner, no login (/usr/sbin/nologin)

Next Steps:
  1. Add your SSH public key to /home/ubuntu/.ssh/authorized_keys
  2. Test SSH connection as ubuntu user
  3. Run configure.sh to set up system services
  4. Deploy applications in /var/www/apps/

Test SSH Access:
  ssh ubuntu@<VPS_IP>

From ubuntu account, verify appuser and directories:
  sudo -u appuser bash -c 'echo "appuser verified"'
  sudo ls -la /var/www/apps/
  sudo -u appuser ls -la /var/run/pm2/

EOF
}

main "$@"
