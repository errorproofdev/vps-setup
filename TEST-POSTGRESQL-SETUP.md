# Test Scenario: PostgreSQL VPS Setup with Dynamic SSH

## Objective

Setup a new VPS at `sql-steelgem` with PostgreSQL and verify connectivity from `node-steelgem`

## Prerequisites Check

### 1. Verify SSH Configuration

```bash
# Check if sql-steelgem is in your SSH config
grep "sql-steelgem" ~/.ssh/config

# Test SSH connectivity
ssh sql-steelgem "echo 'Connected to sql-steelgem'"
ssh node-steelgem "echo 'Connected to node-steelgem'"
```

### 2. Verify .env Configuration

```bash
# Create/update .env for PostgreSQL test
cat > .env << 'EOF'
# SSH Configuration
SSH_HOST="sql-steelgem"
SSH_USER="ubuntu"
SSH_PORT="22"

# VPS Configuration
UBUNTU_SUDOERS=true
UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx,/usr/bin/apt-get"
INSTALL_TAILSCALE=true
TS_HOSTNAME="sql-steelgem"

# PostgreSQL Configuration
POSTGRES_ADMIN_USER="postgres"
POSTGRES_ADMIN_PASSWORD="your-secure-password-here"
EOF

cat .env
```

## Step 1: Setup Base VPS on sql-steelgem

Using the new dynamic SSH configuration, setup the base VPS:

```bash
# Method 1: Using .env (recommended for production)
./scripts/vps-setup.sh

# Method 2: Using environment variables (for testing)
SSH_HOST="sql-steelgem" SSH_USER="ubuntu" ./scripts/vps-setup.sh

# Method 3: Using SSH config directly
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh
```

**Expected Output:**

```
✓ SSH connection verified to ubuntu@sql-steelgem:22
✓ System updated successfully
✓ User ubuntu created successfully
✓ Tailscale installed (and 'tailscale up' attempted)
✓ Firewall configured successfully
✓ NGINX installed
✓ fail2ban configured successfully
✓ SSH hardened
✓ VPS configuration completed!
```

**Verify Setup:**

```bash
# SSH into the server and check
ssh sql-steelgem "hostname && uptime"
ssh sql-steelgem "systemctl status sshd"
ssh sql-steelgem "ufw status"
```

## Step 2: Install PostgreSQL on sql-steelgem

After base VPS is setup, install PostgreSQL:

```bash
# Using remote execution with dynamic SSH
SSH_HOST="sql-steelgem" ./scripts/services.sh postgresql

# Or directly SSH and run
ssh sql-steelgem "cd /home/ubuntu/vps-setup && ./scripts/services.sh postgresql"
```

**Verify PostgreSQL Installation:**

```bash
ssh sql-steelgem "sudo systemctl status postgresql"
ssh sql-steelgem "sudo -u postgres psql -c 'SELECT version();'"
```

## Step 3: Configure PostgreSQL for Remote Connections

Configure PostgreSQL to accept connections from node-steelgem:

```bash
# Get node-steelgem's IP address
NODE_IP=$(ssh node-steelgem "hostname -I | awk '{print \$1}'")
echo "Node Steelgem IP: $NODE_IP"

# Configure PostgreSQL to listen on all interfaces
ssh sql-steelgem << 'REMOTE_SCRIPT'
  sudo cp /etc/postgresql/*/main/postgresql.conf /etc/postgresql/*/main/postgresql.conf.backup
  
  # Enable network access
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf
  
  # Update pg_hba.conf to allow connections from node-steelgem
  echo "host    all             all             NODE_IP_PLACEHOLDER/32          md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
  
  # Restart PostgreSQL
  sudo systemctl restart postgresql
REMOTE_SCRIPT
```

**Better approach - use a script:**

```bash
cat > configure-postgres.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Get node-steelgem IP
NODE_IP=$(ssh node-steelgem "hostname -I | awk '{print \$1}'")
echo "Allowing connections from node-steelgem at $NODE_IP"

# Configure on sql-steelgem
ssh sql-steelgem << SCRIPT
  set -euo pipefail
  
  # Backup configuration
  sudo cp /etc/postgresql/*/main/postgresql.conf /etc/postgresql/*/main/postgresql.conf.backup
  sudo cp /etc/postgresql/*/main/pg_hba.conf /etc/postgresql/*/main/pg_hba.conf.backup
  
  # Enable network listening
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf
  
  # Allow connections from node-steelgem
  echo "host    all             all             $NODE_IP/32            md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf
  
  # Restart PostgreSQL
  sudo systemctl restart postgresql
  
  # Verify it's listening
  sudo netstat -tlnp | grep postgres || sudo ss -tlnp | grep postgres
SCRIPT
EOF

chmod +x configure-postgres.sh
./configure-postgres.sh
```

## Step 4: Create Test Database and User

```bash
ssh sql-steelgem << 'EOF'
  # Create test database and user
  sudo -u postgres psql << PSQL_EOF
    CREATE USER testuser WITH PASSWORD 'testpassword';
    CREATE DATABASE testdb OWNER testuser;
    GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
PSQL_EOF

  # Verify
  sudo -u postgres psql -l | grep testdb
EOF
```

## Step 5: Test Connection from node-steelgem

Verify that node-steelgem can connect to PostgreSQL on sql-steelgem:

```bash
# Install PostgreSQL client on node-steelgem if needed
ssh node-steelgem "sudo apt-get update && sudo apt-get install -y postgresql-client"

# Get sql-steelgem IP
SQL_IP=$(ssh sql-steelgem "hostname -I | awk '{print \$1}'")
echo "SQL Steelgem IP: $SQL_IP"

# Test connection from node-steelgem
ssh node-steelgem "psql -h $SQL_IP -U testuser -d testdb -c 'SELECT now();'"
```

**Expected Output:**

```
              now              
-------------------------------
 2026-01-30 12:34:56.789012+00
(1 row)
```

## Complete Test Script

Here's a complete automated test script:

```bash
#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }

log "Starting PostgreSQL VPS test..."

# Step 1: Test SSH connectivity
log "Step 1: Testing SSH connectivity..."
ssh sql-steelgem "echo 'OK'" > /dev/null && success "Connected to sql-steelgem" || error "Cannot connect to sql-steelgem"
ssh node-steelgem "echo 'OK'" > /dev/null && success "Connected to node-steelgem" || error "Cannot connect to node-steelgem"

# Step 2: Setup VPS on sql-steelgem
log "Step 2: Setting up base VPS on sql-steelgem..."
SSH_HOST="sql-steelgem" ./scripts/vps-setup.sh > /tmp/vps-setup.log 2>&1 && success "VPS setup completed" || error "VPS setup failed"

# Step 3: Install PostgreSQL
log "Step 3: Installing PostgreSQL on sql-steelgem..."
ssh sql-steelgem "cd /home/ubuntu/vps-setup && ./scripts/services.sh postgresql" > /tmp/postgres-install.log 2>&1 && success "PostgreSQL installed" || error "PostgreSQL installation failed"

# Step 4: Get IPs
log "Step 4: Configuring PostgreSQL..."
NODE_IP=$(ssh node-steelgem "hostname -I | awk '{print \$1}'")
log "Node Steelgem IP: $NODE_IP"

# Step 5: Configure PostgreSQL
ssh sql-steelgem << SCRIPT > /dev/null 2>&1
  set -euo pipefail
  sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf
  echo "host    all             all             $NODE_IP/32            md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf > /dev/null
  sudo systemctl restart postgresql
SCRIPT
success "PostgreSQL configured for remote access"

# Step 6: Create test database
log "Step 5: Creating test database..."
ssh sql-steelgem << 'SCRIPT' > /dev/null 2>&1
  sudo -u postgres psql << PSQL_EOF
    DROP DATABASE IF EXISTS testdb;
    DROP USER IF EXISTS testuser;
    CREATE USER testuser WITH PASSWORD 'testpassword';
    CREATE DATABASE testdb OWNER testuser;
    GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
PSQL_EOF
SCRIPT
success "Test database created"

# Step 7: Install PostgreSQL client on node-steelgem
log "Step 6: Installing PostgreSQL client on node-steelgem..."
ssh node-steelgem "sudo apt-get update && sudo apt-get install -y postgresql-client" > /tmp/postgres-client.log 2>&1
success "PostgreSQL client installed"

# Step 8: Test connection
log "Step 7: Testing connection from node-steelgem to sql-steelgem..."
SQL_IP=$(ssh sql-steelgem "hostname -I | awk '{print \$1}'")
log "SQL Steelgem IP: $SQL_IP"

if ssh node-steelgem "PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb -c 'SELECT now();'" > /tmp/postgres-test.log 2>&1; then
    success "PostgreSQL connection successful!"
    echo ""
    echo "Connection details:"
    echo "  Host: $SQL_IP"
    echo "  User: testuser"
    echo "  Database: testdb"
    echo ""
    success "All tests passed! PostgreSQL is accessible from node-steelgem"
else
    error "PostgreSQL connection failed"
fi
```

## Verification Checklist

- [ ] SSH connectivity to both servers verified
- [ ] Base VPS setup completed on sql-steelgem
- [ ] PostgreSQL installed on sql-steelgem
- [ ] PostgreSQL configured to listen on network interfaces
- [ ] pg_hba.conf updated with node-steelgem IP
- [ ] Test database and user created
- [ ] PostgreSQL client installed on node-steelgem
- [ ] Connection test successful from node-steelgem

## Troubleshooting

### Cannot connect to sql-steelgem

```bash
# Verify SSH works
ssh sql-steelgem "echo 'test'"

# Check if key is correct
ssh -v sql-steelgem "echo 'test'" 2>&1 | grep -i auth
```

### PostgreSQL not listening

```bash
# Check on sql-steelgem
ssh sql-steelgem "sudo netstat -tlnp | grep postgres"
ssh sql-steelgem "sudo ss -tlnp | grep postgres"
```

### Connection refused from node-steelgem

```bash
# Check firewall on sql-steelgem
ssh sql-steelgem "sudo ufw status"

# Open PostgreSQL port if needed
ssh sql-steelgem "sudo ufw allow 5432/tcp"
```

### Authentication failed

```bash
# Check pg_hba.conf
ssh sql-steelgem "sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -A 2 all"

# Verify password
ssh sql-steelgem "sudo -u postgres psql -c \"\\du testuser\""
```

## Using Dynamic SSH Configuration Throughout

Notice how the entire test uses the new dynamic SSH configuration:

1. **No hardcoded aliases** - Uses `ssh sql-steelgem` which resolves from `~/.ssh/config`
2. **Environment variable support** - Can use `SSH_HOST="sql-steelgem"` with scripts
3. **Multiple methods** - Works with IP, hostname, or SSH config entries
4. **Flexible configuration** - Can be passed via .env, environment, or command line

This demonstrates the full power of the dynamic SSH system for multi-server deployments!

## Next Steps

After successful test:

1. Run your application deployment: `./scripts/deploy-bastion.sh myapp example.com 3000`
2. Configure additional services as needed
3. Setup monitoring and backups
4. Document your server configuration in .env for future reference
