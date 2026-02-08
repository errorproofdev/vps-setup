# Dynamic SSH Configuration - Testing and Usage Guide

This document provides practical examples and test scenarios for the new dynamic SSH configuration system that eliminates hardcoded aliases.

## Overview

The VPS setup scripts now support three methods for specifying SSH targets:

1. **Environment variables** - Simplest, pass on command line
2. **.env configuration file** - Persistent configuration
3. **~/.ssh/config file** - Standard SSH configuration

No more hardcoded aliases like `ssh sql-steelgem`!

## Scenario 1: Quick Setup with Direct IP

Use this when you want to quickly setup a VPS with a known IP address.

```bash
# Setup a VPS at 192.168.1.100
SSH_HOST="192.168.1.100" \
SSH_USER="ubuntu" \
SSH_PORT="22" \
./scripts/vps-setup.sh

# Or just the minimal version
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh
```

**Verification:**

```bash
# SSH should connect to the specified host
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.100 "uname -a"

# Verify the script ran by checking system info
ssh ubuntu@192.168.1.100 "hostname && uptime"
```

## Scenario 2: Using .env Configuration File

Use this for multiple deployments or when you want persistent configuration.

```bash
# Step 1: Create .env from template
cp .env.example .env

# Step 2: Edit .env with your servers
cat > .env << EOF
# Production servers
SSH_HOST="192.168.1.100"
SSH_USER="ubuntu"
SSH_PORT="22"

# Deployment targets
SOURCE_HOST="edge-prod"
DESTINATION_HOST="node-steelgem"
SOURCE_PATH="/home/ubuntu/current"
DESTINATION_PATH="/var/www/apps"

# VPS Configuration
UBUNTU_SUDOERS=true
UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx,/usr/bin/pm2"
INSTALL_TAILSCALE=true
TAILSCALE_HOSTNAME="node-steelgem"
EOF

# Step 3: Run scripts without passing SSH variables
./scripts/vps-setup.sh

# Step 4: Deploy web server
./scripts/deploy.sh web

# Step 5: Deploy applications
./scripts/deploy-bastion.sh myapp example.com 3000
```

**Verification:**

```bash
# Check that .env is loaded
grep "SSH_HOST" .env

# Verify the script can access the server
SSH_HOST="192.168.1.100" ssh-keyscan -p 22 192.168.1.100

# Test the deployment
SSH_HOST="192.168.1.100" \
DESTINATION_HOST="192.168.1.101" \
./scripts/deploy-bastion.sh test-app example.com 3000
```

## Scenario 3: SSH Config File Integration

Use this for complex multi-server setups with SSH-specific settings.

```bash
# Step 1: Configure ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'

# Edge Production Server
Host edge-prod
    HostName 192.168.1.100
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa_prod
    StrictHostKeyChecking no

# Steelgem Production Database
Host sql-steelgem
    HostName 192.168.1.101
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_rsa_prod
    StrictHostKeyChecking no

# Development Server
Host dev-server
    HostName 192.168.1.102
    User developer
    Port 2222
    IdentityFile ~/.ssh/id_rsa_dev
    StrictHostKeyChecking no
EOF

# Step 2: Verify SSH config works
ssh edge-prod "hostname"
ssh sql-steelgem "hostname"
ssh dev-server "hostname"

# Step 3: Setup VPS using hostnames
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Step 4: Deploy to edge-prod
SOURCE_HOST="edge-prod" \
DESTINATION_HOST="sql-steelgem" \
./scripts/deploy-bastion.sh myapp example.com 3000
```

**Verification:**

```bash
# Test SSH config resolution
ssh edge-prod "echo 'Connected!'"
ssh sql-steelgem "echo 'Connected!'"

# List configured hosts
grep "^Host " ~/.ssh/config

# Test with scripts
SSH_HOST="edge-prod" ./scripts/vps-setup.sh --help
```

## Scenario 4: Multiple Server Deployment

Setup multiple VPS instances simultaneously without aliases.

```bash
# Configuration for multiple servers
cat > .env << EOF
UBUNTU_SUDOERS=true
UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx"
INSTALL_TAILSCALE=true
TAILSCALE_HOSTNAME="node-web-1"
EOF

# Setup web server 1
SSH_HOST="192.168.1.100" \
TAILSCALE_HOSTNAME="node-web-1" \
./scripts/vps-setup.sh

# Setup web server 2
SSH_HOST="192.168.1.101" \
TAILSCALE_HOSTNAME="node-web-2" \
./scripts/vps-setup.sh

# Setup database server
SSH_HOST="192.168.1.102" \
TAILSCALE_HOSTNAME="node-db" \
./scripts/vps-setup.sh

# Deploy web server configuration
SSH_HOST="192.168.1.100" ./scripts/deploy.sh web
SSH_HOST="192.168.1.101" ./scripts/deploy.sh web

# Deploy database configuration
SSH_HOST="192.168.1.102" ./scripts/deploy.sh database
```

**Verification:**

```bash
# Verify all servers are responding
for host in 192.168.1.100 192.168.1.101 192.168.1.102; do
    echo "Testing $host..."
    ssh ubuntu@$host "uptime"
done

# Check Tailscale status on all nodes
ssh ubuntu@192.168.1.100 "tailscale status"
ssh ubuntu@192.168.1.101 "tailscale status"
ssh ubuntu@192.168.1.102 "tailscale status"
```

## Scenario 5: Application Deployment Between Servers

Deploy applications from source to destination without aliases.

```bash
# Configuration
export SOURCE_HOST="192.168.1.100"        # Production web server
export DESTINATION_HOST="192.168.1.101"   # Staging server
export SOURCE_PATH="/home/ubuntu/current"
export DESTINATION_PATH="/var/www/apps"

# Deploy application
./scripts/deploy-bastion.sh myapp example.com 3000

# Verify deployment
ssh ubuntu@192.168.1.101 "ls -la /var/www/apps/"
ssh ubuntu@192.168.1.101 "pm2 status"

# Check application is responding
ssh ubuntu@192.168.1.101 "curl -I http://localhost:3000"
```

**Full deployment cycle:**

```bash
# 1. Setup source server
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh

# 2. Setup destination server
SSH_HOST="192.168.1.101" ./scripts/vps-setup.sh

# 3. Deploy application
SOURCE_HOST="192.168.1.100" \
DESTINATION_HOST="192.168.1.101" \
./scripts/deploy-bastion.sh myapp example.com 3000

# 4. Verify on both servers
ssh ubuntu@192.168.1.100 "pm2 status"  # Source
ssh ubuntu@192.168.1.101 "pm2 status"  # Destination
```

## Scenario 6: Port Forwarding / Non-Standard SSH Ports

Configure servers with custom SSH ports without aliases.

```bash
# Setup server with custom SSH port
SSH_HOST="192.168.1.100:2222" \
SSH_USER="ubuntu" \
./scripts/vps-setup.sh

# Or configure in .env
cat > .env << EOF
SSH_HOST="192.168.1.100:2222"
SSH_USER="ubuntu"
EOF

./scripts/vps-setup.sh

# Or configure in ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'
Host custom-port-server
    HostName 192.168.1.100
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/id_rsa
EOF

# Then use it with scripts
SSH_HOST="custom-port-server" ./scripts/vps-setup.sh
```

**Verification:**

```bash
# Test SSH connection on custom port
ssh -p 2222 ubuntu@192.168.1.100 "echo 'Connected!'"

# Or using host alias
ssh custom-port-server "echo 'Connected!'"
```

## Scenario 7: Conditional Server Setup Based on Environment

Use environment variables to setup different server types.

```bash
# Setup functions
setup_web_server() {
    local host="$1"
    echo "Setting up web server on $host..."
    SSH_HOST="$host" ./scripts/deploy.sh web
}

setup_database_server() {
    local host="$1"
    echo "Setting up database server on $host..."
    SSH_HOST="$host" ./scripts/deploy.sh database
}

setup_development_server() {
    local host="$1"
    echo "Setting up development server on $host..."
    SSH_HOST="$host" ./scripts/deploy.sh dev
}

# Usage
setup_web_server "192.168.1.100"
setup_database_server "192.168.1.101"
setup_development_server "192.168.1.102"

# Or with config file
source .env
SSH_HOST="$SOURCE_HOST" ./scripts/deploy.sh web
SSH_HOST="$DESTINATION_HOST" ./scripts/deploy.sh database
```

## Testing the SSH Configuration Module

Test the ssh-config.sh module directly:

```bash
# Source the module
source ./scripts/ssh-config.sh

# Test 1: Resolve hostname
resolve_ssh_host "192.168.1.100"
ssh_show_config

# Test 2: Validate connection
validate_ssh_connection

# Test 3: Execute remote command
ssh_exec "hostname && uptime"

# Test 4: Copy files to remote
echo "test file" > /tmp/testfile.txt
ssh_copy_to "/tmp/testfile.txt" "/tmp/"

# Test 5: Copy files from remote
ssh_copy_from "/etc/hostname" "/tmp/remote-hostname"
cat /tmp/remote-hostname
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity manually
ssh -v ubuntu@192.168.1.100 "echo 'Connected'"

# Check SSH keys
ls -la ~/.ssh/

# Verify server is accessible
ping 192.168.1.100

# Check firewall
ssh ubuntu@192.168.1.100 "sudo ufw status"
```

### Script Not Finding SSH Target

```bash
# Verify SSH_HOST is set
echo $SSH_HOST

# Check .env file
cat .env | grep SSH_HOST

# Test with explicit parameters
SSH_HOST="192.168.1.100" SSH_USER="ubuntu" SSH_PORT="22" ./scripts/vps-setup.sh --help

# Check ~/.ssh/config
cat ~/.ssh/config | grep -A 5 "Host myserver"
```

### Remote Script Execution Issues

```bash
# Check that target server has bash
ssh ubuntu@192.168.1.100 "which bash"

# Verify sudo access
ssh ubuntu@192.168.1.100 "sudo whoami"

# Check if required commands exist
ssh ubuntu@192.168.1.100 "which apt-get nginx systemctl"

# View execution logs
ssh ubuntu@192.168.1.100 "sudo journalctl -f"
```

## Best Practices

1. **Use .env for persistent configuration**

   ```bash
   cp .env.example .env
   # Commit .env to version control (with secrets removed)
   git add .env
   ```

2. **Use ~/.ssh/config for complex server setups**

   ```bash
   # Centralize all SSH configuration
   # Makes scripts portable and easy to maintain
   ```

3. **Test connectivity before deployment**

   ```bash
   SSH_HOST="192.168.1.100" ssh ubuntu@192.168.1.100 "echo 'Ready'"
   ```

4. **Use environment variables for one-off tests**

   ```bash
   SSH_HOST="test-server" ./scripts/vps-setup.sh --help
   ```

5. **Log all deployments**

   ```bash
   SSH_HOST="192.168.1.100" ./scripts/deploy.sh web | tee deploy.log
   ```

## Migration from Old Alias-Based Setup

If you were using hardcoded aliases before:

### Old way (no longer needed)

```bash
# This relied on shell aliases
ssh sql-steelgem "sudo ./vps-setup.sh"
```

### New way

```bash
# Configure once in ~/.ssh/config
Host sql-steelgem
    HostName 192.168.1.100
    User ubuntu
    Port 22

# Then use dynamically
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Or use IP directly
SSH_HOST="192.168.1.100" ./scripts/vps-setup.sh

# Or in .env
echo 'SSH_HOST="sql-steelgem"' >> .env
./scripts/vps-setup.sh
```

## Summary

The new dynamic SSH system provides:

✅ **No hardcoded aliases** - Use IPs, hostnames, or SSH config
✅ **Flexible configuration** - Environment, .env, or SSH config
✅ **Portable scripts** - Work anywhere SSH is configured
✅ **Multiple servers** - Easy multi-server deployments
✅ **Clear priorities** - Environment > .env > SSH config > defaults

Enjoy your new alias-free VPS setup workflow! 🚀
