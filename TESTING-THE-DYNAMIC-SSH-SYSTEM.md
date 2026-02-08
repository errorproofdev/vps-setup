# Testing the Dynamic SSH System - Complete Guide

## Overview

You now have a complete system for managing multiple VPS instances without hardcoded SSH aliases. This guide shows you exactly how to test it end-to-end.

## What Was Built

```
┌─────────────────────────────────────────────────────────────┐
│              Dynamic SSH Configuration System               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ssh-config.sh ──┐                                         │
│   (SSH logic)    ├─→ vps-setup.sh (base VPS setup)       │
│                  │                                         │
│                  ├─→ deploy.sh (deploy configs)           │
│                  │                                         │
│                  └─→ deploy-bastion.sh (app deploy)       │
│                                                             │
│  Resolution Methods (in order):                            │
│  1. Command-line: SSH_HOST="sql-steelgem" ./script.sh     │
│  2. Environment: export SSH_HOST="sql-steelgem"           │
│  3. .env file: SSH_HOST="sql-steelgem"                    │
│  4. SSH config: Host sql-steelgem in ~/.ssh/config        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Quick Reference: Using the System

### Setup 1: Using .env (Production Recommended)

```bash
# Create .env
cat > .env << 'EOF'
SSH_HOST="sql-steelgem"
SSH_USER="ubuntu"
SSH_PORT="22"

# Other configuration
INSTALL_TAILSCALE=true
TS_HOSTNAME="sql-steelgem"
EOF

# Run scripts - they automatically use SSH_HOST from .env
./scripts/vps-setup.sh
```

### Setup 2: Using Environment Variables

```bash
# Method 1: Inline with command
SSH_HOST="sql-steelgem" SSH_USER="ubuntu" ./scripts/vps-setup.sh

# Method 2: Export first
export SSH_HOST="sql-steelgem"
export SSH_USER="ubuntu"
./scripts/vps-setup.sh
```

### Setup 3: Using SSH Config

```bash
# Add to ~/.ssh/config
Host sql-steelgem
    HostName 192.168.1.50
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519

# Script will resolve it
./scripts/vps-setup.sh
```

## Test Scenario: PostgreSQL Setup Across Two Servers

This scenario demonstrates the real power of the dynamic SSH system by setting up a PostgreSQL server on one VPS and accessing it from another.

### Prerequisites

1. **Two servers accessible via SSH**
   ```bash
   # Verify connectivity
   ssh sql-steelgem "echo 'OK'"
   ssh node-steelgem "echo 'OK'"
   ```

2. **SSH configuration**
   ```bash
   # Add to ~/.ssh/config
   Host sql-steelgem
       HostName 192.168.1.50
       User ubuntu
       StrictHostKeyChecking=accept-new
   
   Host node-steelgem
       HostName 192.168.1.51
       User ubuntu
       StrictHostKeyChecking=accept-new
   ```

### Phase 1: Setup Base VPS on sql-steelgem

```bash
# Method A: Using .env
echo 'SSH_HOST="sql-steelgem"' > .env
./scripts/vps-setup.sh

# Method B: Using environment variable
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Method C: Using SSH config directly (if configured)
./scripts/vps-setup.sh
```

**What gets installed automatically:**
- Ubuntu system updates and security patches
- SSH hardening and fail2ban
- UFW firewall with standard rules
- NGINX web server
- Tailscale VPN (optional, configurable)
- System hardening and user management

**Verify it worked:**
```bash
ssh sql-steelgem "systemctl status sshd"
ssh sql-steelgem "systemctl status nginx"
ssh sql-steelgem "ufw status"
```

### Phase 2: Install PostgreSQL

```bash
# Install PostgreSQL on sql-steelgem
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql

# Or directly via SSH
ssh sql-steelgem "sudo apt-get update && sudo apt-get install -y postgresql postgresql-contrib"
```

**Verify installation:**
```bash
ssh sql-steelgem "sudo systemctl status postgresql"
ssh sql-steelgem "sudo -u postgres psql -c 'SELECT version();'"
```

### Phase 3: Configure PostgreSQL for Remote Access

Get the IP addresses:
```bash
SQL_IP=$(ssh sql-steelgem "hostname -I | awk '{print \$1}'")
NODE_IP=$(ssh node-steelgem "hostname -I | awk '{print \$1}'")

echo "SQL Server IP: $SQL_IP"
echo "Node Server IP: $NODE_IP"
```

Configure PostgreSQL to accept remote connections:
```bash
ssh sql-steelgem << EOF
  # Allow network connections
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
          /etc/postgresql/*/main/postgresql.conf
  
  # Allow connections from node-steelgem
  echo "host    all             all             $NODE_IP/32            scram-sha-256" | \
      sudo tee -a /etc/postgresql/*/main/pg_hba.conf
  
  # Restart PostgreSQL
  sudo systemctl restart postgresql
  
  # Verify listening
  sudo ss -tlnp | grep 5432
EOF
```

### Phase 4: Create Test Database

```bash
ssh sql-steelgem << 'EOF'
  sudo -u postgres psql << 'PSQL'
    -- Create test user
    CREATE USER testuser WITH PASSWORD 'testpassword';
    
    -- Create test database
    CREATE DATABASE testdb OWNER testuser;
    
    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
    
    -- Verify
    \du testuser
    \l testdb
PSQL
EOF
```

### Phase 5: Install PostgreSQL Client on node-steelgem

```bash
ssh node-steelgem << 'EOF'
  sudo apt-get update
  sudo apt-get install -y postgresql-client
  psql --version
EOF
```

### Phase 6: Test End-to-End Connectivity

```bash
# Test connection from node-steelgem to sql-steelgem
ssh node-steelgem << EOF
  PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb -c 'SELECT NOW();'
EOF
```

**Expected output:**
```
              now              
-------------------------------
 2026-01-30 12:34:56.789012+00
(1 row)
```

## Automated Testing: Use the Test Script

We've provided a complete test script that automates all of this:

```bash
# Make it executable
chmod +x test-postgresql-connectivity.sh

# Run it
./test-postgresql-connectivity.sh sql-steelgem node-steelgem

# Or with custom hosts
./test-postgresql-connectivity.sh sql-prod node-prod
```

The script will:
1. Verify SSH connectivity
2. Check PostgreSQL installation
3. Verify service is running
4. Test network configuration
5. Get server IP addresses
6. Check pg_hba.conf settings
7. Verify test user exists
8. Check PostgreSQL client installation
9. **Test actual connectivity**
10. Test data transfer capability

## Real-World Usage Examples

### Example 1: Deploy to Multiple Web Servers

```bash
# Deploy to first web server
SSH_HOST="web1.example.com" ./scripts/vps-setup.sh

# Deploy to second web server
SSH_HOST="web2.example.com" ./scripts/vps-setup.sh

# Deploy to third web server
SSH_HOST="web3.example.com" ./scripts/vps-setup.sh
```

### Example 2: Multi-Tier Architecture

```bash
# 1. Setup database server
SSH_HOST="db-primary" ./scripts/vps-setup.sh

# 2. Setup PostgreSQL on it
SSH_HOST="db-primary" ./scripts/services.sh postgresql

# 3. Setup application server
SSH_HOST="app-server" ./scripts/vps-setup.sh

# 4. Setup Node.js on it
SSH_HOST="app-server" ./scripts/services.sh nodejs

# 5. Deploy application
./scripts/deploy-bastion.sh myapp app-server 3000

# 6. Configure database access
# (Update app config to point to db-primary)
```

### Example 3: Scaling Application

```bash
# Scale by adding more servers
for i in {1..5}; do
  SSH_HOST="app-server-$i" ./scripts/vps-setup.sh
done

# Deploy to each
for i in {1..5}; do
  SSH_HOST="app-server-$i" ./scripts/deploy.sh production
done
```

## How the System Works

### SSH Resolution Order

When you run a script, it resolves the SSH host in this order:

1. **Command-line argument** (if provided)
   ```bash
   SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
   ```

2. **Environment variable**
   ```bash
   export SSH_HOST="sql-steelgem"
   ./scripts/vps-setup.sh
   ```

3. **.env file in current directory**
   ```bash
   cat .env
   # SSH_HOST="sql-steelgem"
   ./scripts/vps-setup.sh
   ```

4. **SSH config (~/.ssh/config)**
   ```bash
   Host sql-steelgem
       HostName 192.168.1.50
       User ubuntu
   ./scripts/vps-setup.sh
   ```

5. **Default (localhost)**
   ```bash
   ./scripts/vps-setup.sh  # Runs locally
   ```

### Key Functions in ssh-config.sh

```bash
# Get SSH connection string
resolve_ssh_host "sql-steelgem"

# Execute command on remote server
ssh_exec "sql-steelgem" "whoami"

# Copy files to remote server
ssh_copy_to "sql-steelgem" "/local/file" "/remote/path"

# Copy files from remote server
ssh_copy_from "sql-steelgem" "/remote/file" "/local/path"

# Test SSH connectivity
validate_ssh_connection "sql-steelgem"
```

## Integration with Existing Scripts

All major scripts now support the dynamic SSH system:

### vps-setup.sh
```bash
# Automatically reads SSH_HOST from .env or environment
./scripts/vps-setup.sh
```

### services.sh
```bash
# Install service on remote server
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql
```

### deploy.sh
```bash
# Deploy configuration to remote server
SSH_HOST="production-server" ./scripts/deploy.sh production
```

### deploy-bastion.sh
```bash
# Deploy application between servers
./scripts/deploy-bastion.sh myapp destination-server 3000
```

## Troubleshooting Common Issues

### "Cannot connect to sql-steelgem"

**Check SSH connectivity:**
```bash
ssh -v sql-steelgem "echo 'OK'"
```

**Check ~/.ssh/config:**
```bash
cat ~/.ssh/config | grep -A 3 "Host sql-steelgem"
```

**Test without SSH config:**
```bash
ssh ubuntu@192.168.1.50 "echo 'OK'"
```

### "PostgreSQL connection refused"

**Check PostgreSQL is listening:**
```bash
ssh sql-steelgem "sudo ss -tlnp | grep 5432"
```

**Check firewall allows connections:**
```bash
ssh sql-steelgem "sudo ufw status"
ssh sql-steelgem "sudo ufw allow from $NODE_IP to any port 5432"
```

**Check pg_hba.conf:**
```bash
ssh sql-steelgem "sudo cat /etc/postgresql/*/main/pg_hba.conf"
```

### "Authentication failed"

**Verify user exists:**
```bash
ssh sql-steelgem "sudo -u postgres psql -c '\\du testuser'"
```

**Reset user password:**
```bash
ssh sql-steelgem "sudo -u postgres psql -c \"ALTER USER testuser WITH PASSWORD 'newpassword';\""
```

## Best Practices

### 1. Always Use .env for Production

```bash
# Create .env for each environment
cat > .env.production << 'EOF'
SSH_HOST="prod-sql-server"
SSH_USER="ubuntu"
SSH_PORT="22"
INSTALL_TAILSCALE=true
TS_HOSTNAME="prod-sql-server"
EOF

# Use it
cp .env.production .env
./scripts/vps-setup.sh
```

### 2. Keep SSH Config Updated

```bash
# Add all your servers to ~/.ssh/config
Host sql-primary
    HostName 192.168.1.10
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519

Host sql-replica
    HostName 192.168.1.11
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519

Host app-server
    HostName 192.168.1.20
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
```

### 3. Document Server Roles

```bash
# In .env or .env.example
# Database Server
SQL_HOST="sql-primary"
SQL_REPLICA_HOST="sql-replica"

# Application Servers
APP_SERVER_1="app-server-1"
APP_SERVER_2="app-server-2"

# Bastion/Jump Host
BASTION_HOST="bastion"
```

### 4. Test Connectivity Before Deployment

```bash
# Always test SSH access first
ssh $SSH_HOST "echo 'Connected' && uptime"

# Before running setup
./scripts/vps-setup.sh
```

## File Structure

```
vps-setup/
├── scripts/
│   ├── ssh-config.sh              ← New SSH utility module
│   ├── vps-setup.sh               ← Updated to use ssh-config.sh
│   ├── deploy.sh                  ← Updated to use dynamic SSH
│   ├── deploy-bastion.sh          ← Updated to use dynamic SSH
│   └── services.sh                ← Service installation module
├── test-postgresql-connectivity.sh ← New test script
├── .env.example                   ← Updated with SSH examples
├── POSTGRESQL-TEST-GUIDE.md       ← This testing guide
├── TESTING-THE-DYNAMIC-SSH-SYSTEM.md ← Complete overview (you are here)
├── DYNAMIC-SSH-GUIDE.md           ← SSH configuration details
├── IMPLEMENTATION-SUMMARY.md      ← Architecture overview
└── README.md                       ← Main documentation
```

## Summary

You now have:

✅ **Dynamic SSH system** - No hardcoded aliases
✅ **Flexible configuration** - .env, environment, SSH config, or command-line
✅ **Multi-server support** - Deploy to multiple servers easily
✅ **Complete test suite** - PostgreSQL connectivity testing
✅ **Full documentation** - Guides, examples, and troubleshooting

To test it immediately:

```bash
# 1. Verify SSH access
ssh sql-steelgem "echo 'OK'"

# 2. Run base VPS setup
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# 3. Install PostgreSQL
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql

# 4. Run the connectivity test
./test-postgresql-connectivity.sh sql-steelgem node-steelgem
```

That's it! The entire PostgreSQL setup and connectivity test runs with the new dynamic SSH system.
