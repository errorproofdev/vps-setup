#!/bin/bash

################################################################################
# PostgreSQL Setup Test Checklist
# Step-by-step guide to testing the dynamic SSH system with PostgreSQL
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Checklist functions
log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Track progress
STEP=0
MAX_STEPS=15
completed_steps=0

start_step() {
    ((STEP++))
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "STEP $STEP/$MAX_STEPS: $1"
    echo "═══════════════════════════════════════════════════════════════════════"
}

mark_complete() {
    success "$1"
    ((completed_steps++))
}

show_progress() {
    echo ""
    echo "Progress: $completed_steps/$MAX_STEPS steps completed"
    echo ""
}

################################################################################
# STEP 1: Verify Prerequisites
################################################################################
start_step "Verify Prerequisites"

log "Checking for required tools..."

# Check SSH
if command -v ssh &> /dev/null; then
    success "SSH is installed"
else
    error "SSH is not installed"
    exit 1
fi

# Check bash
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    success "Bash 4+ is available"
else
    error "Bash 4+ is required"
    exit 1
fi

# Check for scripts directory
if [[ -d "./scripts" ]]; then
    success "Scripts directory found"
else
    error "Scripts directory not found. Run from vps-setup root directory"
    exit 1
fi

mark_complete "Prerequisites verified"
show_progress

################################################################################
# STEP 2: Verify SSH Configuration
################################################################################
start_step "Verify SSH Configuration"

log "Checking ~/.ssh/config for server entries..."

read -p "Enter SQL server alias (e.g., sql-steelgem): " SQL_HOST
read -p "Enter Node server alias (e.g., node-steelgem): " NODE_HOST

log "Verifying $SQL_HOST configuration..."
if grep -q "Host $SQL_HOST" ~/.ssh/config 2>/dev/null; then
    success "$SQL_HOST found in ~/.ssh/config"
else
    warning "$SQL_HOST not found in ~/.ssh/config"
    log "Add this to ~/.ssh/config:"
    cat << EOF
Host $SQL_HOST
    HostName your-ip-or-hostname
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking=accept-new
EOF
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log "Verifying $NODE_HOST configuration..."
if grep -q "Host $NODE_HOST" ~/.ssh/config 2>/dev/null; then
    success "$NODE_HOST found in ~/.ssh/config"
else
    warning "$NODE_HOST not found in ~/.ssh/config"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

mark_complete "SSH configuration verified"
show_progress

################################################################################
# STEP 3: Test SSH Connectivity
################################################################################
start_step "Test SSH Connectivity"

log "Testing connection to $SQL_HOST..."
if ssh "$SQL_HOST" "echo 'OK'" &> /dev/null; then
    success "Connected to $SQL_HOST"
else
    error "Cannot connect to $SQL_HOST"
    log "Troubleshooting:"
    log "  1. Check SSH key: ssh -v $SQL_HOST"
    log "  2. Verify IP address in ~/.ssh/config"
    log "  3. Check security group/firewall allows SSH (port 22)"
    exit 1
fi

log "Testing connection to $NODE_HOST..."
if ssh "$NODE_HOST" "echo 'OK'" &> /dev/null; then
    success "Connected to $NODE_HOST"
else
    error "Cannot connect to $NODE_HOST"
    exit 1
fi

mark_complete "SSH connectivity verified"
show_progress

################################################################################
# STEP 4: Setup .env File
################################################################################
start_step "Setup .env File"

log "Creating .env configuration file..."

cat > .env << EOF
# SSH Configuration
SSH_HOST="$SQL_HOST"
SSH_USER="ubuntu"
SSH_PORT="22"

# VPS Configuration
UBUNTU_SUDOERS=true
UBUNTU_SUDOERS_CMDS="/usr/bin/systemctl,/usr/sbin/nginx,/usr/bin/apt-get"
INSTALL_TAILSCALE=false

# Tailscale Configuration (optional)
# TS_HOSTNAME="$SQL_HOST"
# TS_AUTH_KEY="your-tailscale-auth-key"

# PostgreSQL Configuration
POSTGRES_ADMIN_USER="postgres"
POSTGRES_ADMIN_PASSWORD="temporary-password-change-me"
EOF

success ".env file created"
log "Content:"
cat .env

mark_complete ".env file created"
show_progress

################################################################################
# STEP 5: Verify Scripts are Executable
################################################################################
start_step "Verify Scripts are Executable"

log "Making scripts executable..."

chmod +x scripts/*.sh 2>/dev/null || true
chmod +x test-postgresql-connectivity.sh 2>/dev/null || true

success "All scripts are executable"

mark_complete "Scripts are executable"
show_progress

################################################################################
# STEP 6: Run Syntax Check
################################################################################
start_step "Run Syntax Check"

log "Checking script syntax..."

scripts_ok=true
for script in scripts/*.sh test-postgresql-connectivity.sh; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            success "$script syntax OK"
        else
            error "$script has syntax errors"
            bash -n "$script" || true
            scripts_ok=false
        fi
    fi
done

if [[ "$scripts_ok" == false ]]; then
    error "Some scripts have syntax errors"
    exit 1
fi

mark_complete "Script syntax is valid"
show_progress

################################################################################
# STEP 7: Run VPS Setup on $SQL_HOST
################################################################################
start_step "Run VPS Setup on $SQL_HOST"

log "This will:"
log "  - Update system packages"
log "  - Configure firewall"
log "  - Install NGINX"
log "  - Setup fail2ban"
log "  - Harden SSH"
log "  - Configure Tailscale (if enabled)"

read -p "Continue with VPS setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Skipping VPS setup"
else
    log "Running: ./scripts/vps-setup.sh"
    if ./scripts/vps-setup.sh; then
        success "VPS setup completed successfully"
        mark_complete "VPS setup completed"
    else
        error "VPS setup failed"
        log "Check the output above for details"
        read -p "Continue to next step? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

show_progress

################################################################################
# STEP 8: Install PostgreSQL
################################################################################
start_step "Install PostgreSQL on $SQL_HOST"

read -p "Install PostgreSQL now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Running: SSH_HOST='$SQL_HOST' ./scripts/services.sh postgresql"
    if SSH_HOST="$SQL_HOST" ./scripts/services.sh postgresql; then
        success "PostgreSQL installed successfully"
        mark_complete "PostgreSQL installed"
    else
        error "PostgreSQL installation failed"
        log "Try installing manually:"
        log "  ssh $SQL_HOST \"sudo apt-get update && sudo apt-get install -y postgresql\""
        read -p "Continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    warning "Skipping PostgreSQL installation"
fi

show_progress

################################################################################
# STEP 9: Get Server IP Addresses
################################################################################
start_step "Get Server IP Addresses"

log "Retrieving IP addresses..."

SQL_IP=$(ssh "$SQL_HOST" "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "unknown")
NODE_IP=$(ssh "$NODE_HOST" "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "unknown")

log "SQL Server IP: $SQL_IP"
log "Node Server IP: $NODE_IP"

if [[ "$SQL_IP" == "unknown" ]] || [[ "$NODE_IP" == "unknown" ]]; then
    warning "Could not retrieve all IP addresses"
else
    success "IP addresses retrieved"
    mark_complete "IP addresses retrieved"
fi

show_progress

################################################################################
# STEP 10: Configure PostgreSQL Network Access
################################################################################
start_step "Configure PostgreSQL Network Access"

log "This will configure PostgreSQL to accept connections from $NODE_HOST"

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Configuring PostgreSQL..."
    
    ssh "$SQL_HOST" << EOF
        # Update postgresql.conf
        sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
                /etc/postgresql/*/main/postgresql.conf
        
        # Update pg_hba.conf
        echo "host    all             all             $NODE_IP/32            scram-sha-256" | \
            sudo tee -a /etc/postgresql/*/main/pg_hba.conf > /dev/null
        
        # Restart PostgreSQL
        sudo systemctl restart postgresql
        
        # Verify
        echo "PostgreSQL configuration updated"
        sudo systemctl status postgresql --no-pager
EOF
    
    success "PostgreSQL configuration updated"
    mark_complete "PostgreSQL network access configured"
else
    warning "Skipping PostgreSQL configuration"
fi

show_progress

################################################################################
# STEP 11: Create Test Database and User
################################################################################
start_step "Create Test Database and User"

log "Creating test database and user..."

ssh "$SQL_HOST" << 'EOF'
    sudo -u postgres psql << 'PSQL'
        -- Drop existing if present
        DROP DATABASE IF EXISTS testdb;
        DROP USER IF EXISTS testuser;
        
        -- Create new user and database
        CREATE USER testuser WITH PASSWORD 'testpassword';
        CREATE DATABASE testdb OWNER testuser;
        GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
        
        -- Verify
        \du testuser
        \l testdb
PSQL
EOF

success "Test database and user created"
mark_complete "Test database created"
show_progress

################################################################################
# STEP 12: Install PostgreSQL Client on Node Server
################################################################################
start_step "Install PostgreSQL Client on $NODE_HOST"

log "Installing PostgreSQL client tools..."

if ssh "$NODE_HOST" "sudo apt-get update && sudo apt-get install -y postgresql-client" 2>/dev/null; then
    success "PostgreSQL client installed on $NODE_HOST"
    mark_complete "PostgreSQL client installed"
else
    warning "PostgreSQL client installation may have issues"
    warning "Continuing with connectivity test..."
fi

show_progress

################################################################################
# STEP 13: Configure Firewall (if needed)
################################################################################
start_step "Configure Firewall"

log "Checking firewall rules on $SQL_HOST..."

ssh "$SQL_HOST" "sudo ufw status | head -5"

log "If PostgreSQL connection fails, run:"
log "  ssh $SQL_HOST \"sudo ufw allow from $NODE_IP to any port 5432\""

mark_complete "Firewall check completed"
show_progress

################################################################################
# STEP 14: Test Connectivity (Manual)
################################################################################
start_step "Test PostgreSQL Connectivity"

log "Testing connection from $NODE_HOST to PostgreSQL on $SQL_HOST..."
log "Connection details:"
log "  Host: $SQL_IP"
log "  Port: 5432"
log "  User: testuser"
log "  Database: testdb"
log ""

read -p "Run connectivity test now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if ssh "$NODE_HOST" "PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb -c 'SELECT NOW();'" 2>&1; then
        success "PostgreSQL connection successful!"
        mark_complete "Connectivity test passed"
    else
        error "PostgreSQL connection failed"
        log "Troubleshooting steps:"
        log "  1. Check PostgreSQL is running: ssh $SQL_HOST 'sudo systemctl status postgresql'"
        log "  2. Check it's listening: ssh $SQL_HOST 'sudo ss -tlnp | grep 5432'"
        log "  3. Check pg_hba.conf: ssh $SQL_HOST 'sudo cat /etc/postgresql/*/main/pg_hba.conf | tail -10'"
        log "  4. Check firewall: ssh $SQL_HOST 'sudo ufw status'"
        log "  5. Verify password: Check testuser password in PostgreSQL"
        read -p "Continue? (y/n): " -n 1 -r
        echo
    fi
else
    warning "Skipping connectivity test"
fi

show_progress

################################################################################
# STEP 15: Run Automated Test Script
################################################################################
start_step "Run Automated Connectivity Test"

log "The automated test script will run all tests at once"

read -p "Run automated test script? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ -f "./test-postgresql-connectivity.sh" ]]; then
        ./test-postgresql-connectivity.sh "$SQL_HOST" "$NODE_HOST"
        if [[ $? -eq 0 ]]; then
            success "All automated tests passed!"
            mark_complete "Automated tests completed"
        else
            warning "Some tests failed (see above)"
        fi
    else
        error "test-postgresql-connectivity.sh not found"
    fi
else
    warning "Skipping automated test script"
fi

show_progress

################################################################################
# Final Summary
################################################################################
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "TEST SUMMARY"
echo "═══════════════════════════════════════════════════════════════════════"

echo ""
echo "Completed Steps: $completed_steps/$MAX_STEPS"
echo ""

if [[ $completed_steps -ge 10 ]]; then
    success "Most tests completed successfully!"
    
    echo ""
    echo "Next Steps:"
    echo "  1. Verify PostgreSQL is working with: ./test-postgresql-connectivity.sh $SQL_HOST $NODE_HOST"
    echo "  2. Update .env with production settings"
    echo "  3. Deploy your application: ./scripts/deploy.sh production"
    echo "  4. Configure database backups: ./scripts/backup-dotfiles.sh"
    echo ""
    
    success "PostgreSQL setup test complete!"
else
    warning "Some tests were skipped or failed"
    echo ""
    echo "To continue testing later:"
    echo "  ./test-postgresql-connectivity.sh $SQL_HOST $NODE_HOST"
fi

echo ""
echo "Configuration saved in .env:"
cat .env
echo ""

echo "═══════════════════════════════════════════════════════════════════════"
