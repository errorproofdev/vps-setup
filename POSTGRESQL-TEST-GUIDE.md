# PostgreSQL Setup & Connectivity Test Guide

This guide walks you through testing the new **dynamic SSH configuration system** by setting up PostgreSQL on a new VPS (`sql-steelgem`) and verifying connectivity from another server (`node-steelgem`).

## Quick Start

```bash
# Step 1: Make scripts executable
chmod +x scripts/*.sh
chmod +x test-postgresql-connectivity.sh

# Step 2: Setup your environment
cat > .env << 'EOF'
SSH_HOST="sql-steelgem"
SSH_USER="ubuntu"
SSH_PORT="22"
INSTALL_TAILSCALE=true
TS_HOSTNAME="sql-steelgem"
EOF

# Step 3: Run the complete test
./test-postgresql-connectivity.sh sql-steelgem node-steelgem
```

## Prerequisites

Before running the test, ensure you have:

### 1. SSH Configuration
Your servers must be accessible via SSH:

```bash
# Add to ~/.ssh/config or ensure they're already configured
Host sql-steelgem
    HostName sql-steelgem.local  # or IP address
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking=accept-new

Host node-steelgem
    HostName node-steelgem.local  # or IP address
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking=accept-new
```

### 2. Test Connectivity
```bash
# Test SSH access to both servers
ssh sql-steelgem "echo 'SQL server OK'"
ssh node-steelgem "echo 'Node server OK'"
```

## Detailed Test Workflow

### Phase 1: Base VPS Setup on sql-steelgem

Use the dynamic SSH system to setup the base VPS:

```bash
# Using .env file (recommended for production)
./scripts/vps-setup.sh

# Or using environment variable
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Or using SSH config (if sql-steelgem is in ~/.ssh/config)
./scripts/vps-setup.sh
```

**What gets installed:**
- System updates and security patches
- SSH hardening
- Firewall (UFW) configuration
- Fail2ban for DDoS protection
- NGINX web server
- Optional: Tailscale VPN
- User setup and sudo configuration

**Verify:**
```bash
ssh sql-steelgem "systemctl status sshd"
ssh sql-steelgem "ufw status"
ssh sql-steelgem "systemctl status nginx"
```

### Phase 2: PostgreSQL Installation

After base VPS setup, install PostgreSQL:

```bash
# Method 1: Direct remote execution
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql

# Method 2: SSH and run locally on the server
ssh sql-steelgem "cd /home/ubuntu/vps-setup && ./scripts/services.sh postgresql"

# Method 3: Manual installation (if scripts unavailable)
ssh sql-steelgem "sudo apt-get update && sudo apt-get install -y postgresql postgresql-contrib"
```

**Verify Installation:**
```bash
# Check PostgreSQL service
ssh sql-steelgem "sudo systemctl status postgresql"

# Check PostgreSQL version
ssh sql-steelgem "sudo -u postgres psql --version"

# Verify PostgreSQL is running
ssh sql-steelgem "sudo -u postgres psql -c 'SELECT version();'"
```

### Phase 3: PostgreSQL Network Configuration

PostgreSQL needs to be configured to accept connections from `node-steelgem`:

#### Step 1: Get the IP addresses

```bash
SQL_IP=$(ssh sql-steelgem "hostname -I | awk '{print \$1}'")
NODE_IP=$(ssh node-steelgem "hostname -I | awk '{print \$1}'")

echo "SQL Server: $SQL_IP"
echo "Node Server: $NODE_IP"
```

#### Step 2: Configure PostgreSQL to Listen on All Interfaces

```bash
ssh sql-steelgem << 'EOF'
# Backup original configuration
sudo cp /etc/postgresql/*/main/postgresql.conf \
        /etc/postgresql/*/main/postgresql.conf.backup

# Update listen_addresses to accept network connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
        /etc/postgresql/*/main/postgresql.conf

# Verify the change
sudo grep "listen_addresses" /etc/postgresql/*/main/postgresql.conf
EOF
```

#### Step 3: Update pg_hba.conf for Remote Access

```bash
ssh sql-steelgem << EOF
# Backup original
sudo cp /etc/postgresql/*/main/pg_hba.conf \
        /etc/postgresql/*/main/pg_hba.conf.backup

# Allow connections from node-steelgem
echo "host    all             all             $NODE_IP/32            scram-sha-256" | \
    sudo tee -a /etc/postgresql/*/main/pg_hba.conf > /dev/null

# Verify the entry was added
sudo tail -3 /etc/postgresql/*/main/pg_hba.conf
EOF
```

**Important:** The authentication method is important!
- `scram-sha-256` - Recommended for PostgreSQL 10+
- `md5` - Older but compatible (less secure)
- `trust` - Only for development/testing (no password)

#### Step 4: Restart PostgreSQL

```bash
ssh sql-steelgem << 'EOF'
# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql

# Verify it's listening on the network port
echo "Checking if PostgreSQL is listening..."
sudo ss -tlnp | grep 5432 || sudo netstat -tlnp | grep postgres
EOF
```

### Phase 4: Create Test Database and User

```bash
ssh sql-steelgem << 'EOF'
# Create test database and user
sudo -u postgres psql << 'PSQL_EOF'
    -- Drop existing test user/db if present
    DROP DATABASE IF EXISTS testdb;
    DROP USER IF EXISTS testuser;
    
    -- Create new user and database
    CREATE USER testuser WITH PASSWORD 'testpassword';
    CREATE DATABASE testdb OWNER testuser;
    GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
    
    -- Verify
    \du testuser
    \l testdb
PSQL_EOF
EOF
```

### Phase 5: Install PostgreSQL Client on node-steelgem

```bash
ssh node-steelgem << 'EOF'
# Update and install PostgreSQL client
sudo apt-get update
sudo apt-get install -y postgresql-client

# Verify installation
psql --version
EOF
```

### Phase 6: Test Connectivity

Now test the connection from `node-steelgem` to the PostgreSQL server on `sql-steelgem`:

```bash
# Get SQL server IP
SQL_IP=$(ssh sql-steelgem "hostname -I | awk '{print \$1}'")

# Test connection
ssh node-steelgem << EOF
PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb -c 'SELECT NOW();'
EOF
```

**Expected Output:**
```
              now              
-------------------------------
 2026-01-30 12:34:56.789012+00
(1 row)
```

## Automated Test Script

Run the complete test workflow automatically:

```bash
./test-postgresql-connectivity.sh [sql-host] [node-host]

# Examples:
./test-postgresql-connectivity.sh sql-steelgem node-steelgem
./test-postgresql-connectivity.sh 192.168.1.50 192.168.1.51
```

**What the script tests:**
1. SSH connectivity to both servers
2. PostgreSQL installation and service status
3. PostgreSQL network configuration (listening on 5432)
4. Server IP addresses
5. pg_hba.conf configuration
6. PostgreSQL test user existence
7. PostgreSQL client on node server
8. Actual connectivity from node to SQL database
9. Data transfer capability

## Complete Setup Script (All-in-One)

Here's a single script that handles all steps:

```bash
#!/bin/bash
set -euo pipefail

SQL_HOST="${1:-sql-steelgem}"
NODE_HOST="${2:-node-steelgem}"

echo "Setting up PostgreSQL test: $SQL_HOST → $NODE_HOST"

# Step 1: Setup base VPS
echo "Step 1: Setting up base VPS on $SQL_HOST..."
SSH_HOST="$SQL_HOST" ./scripts/vps-setup.sh

# Step 2: Install PostgreSQL
echo "Step 2: Installing PostgreSQL..."
SSH_HOST="$SQL_HOST" ./scripts/services.sh postgresql

# Step 3: Get IPs
SQL_IP=$(ssh $SQL_HOST "hostname -I | awk '{print \$1}'")
NODE_IP=$(ssh $NODE_HOST "hostname -I | awk '{print \$1}'")
echo "SQL IP: $SQL_IP"
echo "Node IP: $NODE_IP"

# Step 4: Configure PostgreSQL
echo "Step 3: Configuring PostgreSQL for remote access..."
ssh $SQL_HOST << SCRIPT
  # Update postgresql.conf
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
          /etc/postgresql/*/main/postgresql.conf
  
  # Update pg_hba.conf
  echo "host    all             all             $NODE_IP/32            scram-sha-256" | \
      sudo tee -a /etc/postgresql/*/main/pg_hba.conf
  
  # Restart PostgreSQL
  sudo systemctl restart postgresql
SCRIPT

# Step 5: Create test user and database
echo "Step 4: Creating test database..."
ssh $SQL_HOST << 'EOF'
  sudo -u postgres psql << 'PSQL_EOF'
    DROP DATABASE IF EXISTS testdb;
    DROP USER IF EXISTS testuser;
    CREATE USER testuser WITH PASSWORD 'testpassword';
    CREATE DATABASE testdb OWNER testuser;
    GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
PSQL_EOF
EOF

# Step 6: Install PostgreSQL client
echo "Step 5: Installing PostgreSQL client on $NODE_HOST..."
ssh $NODE_HOST "sudo apt-get update && sudo apt-get install -y postgresql-client"

# Step 7: Test connectivity
echo "Step 6: Testing connectivity..."
ssh $NODE_HOST << EOF
  PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb -c 'SELECT NOW();'
EOF

echo "✓ Setup complete!"
```

## Troubleshooting

### Connection Refused
```bash
# Check if PostgreSQL is listening
ssh sql-steelgem "sudo ss -tlnp | grep 5432"

# Check firewall
ssh sql-steelgem "sudo ufw status"

# Allow PostgreSQL port
ssh sql-steelgem "sudo ufw allow 5432/tcp"
```

### Authentication Failed
```bash
# Verify user exists
ssh sql-steelgem "sudo -u postgres psql -c '\\du testuser'"

# Check pg_hba.conf
ssh sql-steelgem "sudo cat /etc/postgresql/*/main/pg_hba.conf | tail -10"

# Test with postgres user (no password)
ssh node-steelgem "psql -h $SQL_IP -U postgres -d postgres -c 'SELECT 1;'"
```

### Firewall Issues
```bash
# On sql-steelgem, allow PostgreSQL
ssh sql-steelgem "sudo ufw allow from $NODE_IP to any port 5432"

# Verify rule
ssh sql-steelgem "sudo ufw status numbered"
```

## Key Concepts: Dynamic SSH Configuration

This test demonstrates all the features of the new dynamic SSH system:

### 1. **No Hardcoded Aliases**
```bash
# Before (hardcoded):
ssh ubuntu@192.168.1.50

# After (dynamic):
ssh sql-steelgem  # Resolved from ~/.ssh/config or .env
```

### 2. **Environment Variable Override**
```bash
# Can override SSH host via environment
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Or use .env
cat .env
# SSH_HOST="sql-steelgem"
./scripts/vps-setup.sh
```

### 3. **Multiple Resolution Methods**
```bash
# Method 1: .env file
SSH_HOST="sql-steelgem"

# Method 2: Environment variable
export SSH_HOST="sql-steelgem"

# Method 3: SSH config (~/.ssh/config)
Host sql-steelgem
    HostName 192.168.1.50
    User ubuntu
```

### 4. **Flexible Addressing**
```bash
# Works with hostname
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh

# Works with IP
SSH_HOST="192.168.1.50" ./scripts/vps-setup.sh

# Works with FQDN
SSH_HOST="sql-steelgem.local" ./scripts/vps-setup.sh
```

## Post-Setup Verification Checklist

- [ ] Base VPS setup completed on `sql-steelgem`
- [ ] PostgreSQL installed and running
- [ ] PostgreSQL listening on port 5432
- [ ] pg_hba.conf updated with node-steelgem IP
- [ ] Test user and database created
- [ ] PostgreSQL client installed on node-steelgem
- [ ] Connection test successful
- [ ] Data can be written and read across servers
- [ ] Firewall rules allow connection

## Next Steps

After successful test:

1. **Deploy Your Application**
   ```bash
   ./scripts/deploy.sh your-app
   ```

2. **Configure Backup**
   ```bash
   ./scripts/backup-dotfiles.sh
   ```

3. **Update Documentation**
   - Document server roles in .env
   - Keep SSH config updated
   - Record PostgreSQL access methods

4. **Production Hardening**
   - Change PostgreSQL password to something secure
   - Consider using SSL/TLS for PostgreSQL connections
   - Implement connection pooling
   - Setup monitoring and backups

## See Also

- [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md) - Dynamic SSH configuration details
- [IMPLEMENTATION-SUMMARY.md](./IMPLEMENTATION-SUMMARY.md) - System architecture overview
- [README.md](./README.md) - Main documentation
- [QUICK-START.md](./QUICK-START.md) - Quick reference guide
