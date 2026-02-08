#!/bin/bash

###############################################################################
# PostgreSQL Connectivity Test Script
# Tests the new dynamic SSH configuration for PostgreSQL setup
# Usage: ./test-postgresql-connectivity.sh [sql-steelgem] [node-steelgem]
###############################################################################

set -euo pipefail

# Source ssh-config.sh for dynamic SSH functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/ssh-config.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SQL_HOST="${1:-sql-steelgem}"
NODE_HOST="${2:-node-steelgem}"
SQL_USER="postgres"
SQL_PASS="testpassword"
SQL_DB="testdb"
TEST_USER="testuser"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
    return 1
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

###############################################################################
# Test 1: SSH Connectivity
###############################################################################
test_ssh_connectivity() {
    log "Test 1: Verifying SSH connectivity..."
    
    if ssh_exec "$SQL_HOST" "echo 'OK'" > /dev/null 2>&1; then
        success "Connected to $SQL_HOST"
    else
        error "Cannot connect to $SQL_HOST" || return 1
    fi
    
    if ssh_exec "$NODE_HOST" "echo 'OK'" > /dev/null 2>&1; then
        success "Connected to $NODE_HOST"
    else
        error "Cannot connect to $NODE_HOST" || return 1
    fi
}

###############################################################################
# Test 2: PostgreSQL Installation Check
###############################################################################
test_postgresql_installed() {
    log "Test 2: Verifying PostgreSQL installation..."
    
    if ssh_exec "$SQL_HOST" "which psql" > /dev/null 2>&1; then
        success "PostgreSQL is installed on $SQL_HOST"
        
        # Get version
        local version=$(ssh_exec "$SQL_HOST" "sudo -u postgres psql --version" 2>/dev/null || echo "unknown")
        log "Version: $version"
    else
        error "PostgreSQL not found on $SQL_HOST" || return 1
    fi
}

###############################################################################
# Test 3: PostgreSQL Service Status
###############################################################################
test_postgresql_service() {
    log "Test 3: Checking PostgreSQL service status..."
    
    if ssh_exec "$SQL_HOST" "sudo systemctl is-active postgresql" > /dev/null 2>&1; then
        success "PostgreSQL service is running on $SQL_HOST"
    else
        error "PostgreSQL service is not running on $SQL_HOST" || return 1
    fi
}

###############################################################################
# Test 4: Check PostgreSQL Network Configuration
###############################################################################
test_postgresql_network() {
    log "Test 4: Verifying PostgreSQL network configuration..."
    
    local listening=$(ssh_exec "$SQL_HOST" "sudo ss -tlnp 2>/dev/null | grep postgres || sudo netstat -tlnp 2>/dev/null | grep postgres || echo 'not-listening'" 2>/dev/null)
    
    if echo "$listening" | grep -q "5432"; then
        success "PostgreSQL is listening on port 5432"
    else
        warning "PostgreSQL may not be listening on network interface (check postgresql.conf)"
    fi
}

###############################################################################
# Test 5: Get IPs
###############################################################################
get_server_ips() {
    log "Test 5: Retrieving server IP addresses..."
    
    SQL_IP=$(ssh_exec "$SQL_HOST" "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "unknown")
    NODE_IP=$(ssh_exec "$NODE_HOST" "hostname -I | awk '{print \$1}'" 2>/dev/null || echo "unknown")
    
    log "$SQL_HOST IP: $SQL_IP"
    log "$NODE_HOST IP: $NODE_IP"
    
    if [[ "$SQL_IP" == "unknown" ]] || [[ "$NODE_IP" == "unknown" ]]; then
        error "Could not retrieve IP addresses" || return 1
    fi
}

###############################################################################
# Test 6: Check pg_hba.conf Configuration
###############################################################################
test_hba_config() {
    log "Test 6: Checking pg_hba.conf for $NODE_IP..."
    
    local hba_content=$(ssh_exec "$SQL_HOST" "sudo cat /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | grep -E 'host.*all.*all' || echo 'not-configured'" 2>/dev/null)
    
    if echo "$hba_content" | grep -q "$NODE_IP"; then
        success "pg_hba.conf is configured to accept connections from $NODE_HOST ($NODE_IP)"
    else
        warning "pg_hba.conf may not be configured for $NODE_HOST. Current config:"
        ssh_exec "$SQL_HOST" "sudo cat /etc/postgresql/*/main/pg_hba.conf | tail -5" 2>/dev/null || true
    fi
}

###############################################################################
# Test 7: Check Test User Exists
###############################################################################
test_user_exists() {
    log "Test 7: Checking if test user exists on $SQL_HOST..."
    
    if ssh_exec "$SQL_HOST" "sudo -u postgres psql -c \"\\du\" | grep -q $TEST_USER" 2>/dev/null; then
        success "Test user '$TEST_USER' exists"
    else
        warning "Test user '$TEST_USER' not found. Creating..."
        
        ssh_exec "$SQL_HOST" << 'PSQL_EOF' 2>/dev/null || warning "Could not create test user"
            sudo -u postgres psql << 'INNER_EOF'
                CREATE USER testuser WITH PASSWORD 'testpassword';
                CREATE DATABASE testdb OWNER testuser;
                GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
            INNER_EOF
PSQL_EOF
    fi
}

###############################################################################
# Test 8: PostgreSQL Client on Node
###############################################################################
test_postgres_client() {
    log "Test 8: Checking PostgreSQL client on $NODE_HOST..."
    
    if ssh_exec "$NODE_HOST" "which psql" > /dev/null 2>&1; then
        success "PostgreSQL client is installed on $NODE_HOST"
    else
        warning "PostgreSQL client not found. Installing..."
        
        if ssh_exec "$NODE_HOST" "sudo apt-get update && sudo apt-get install -y postgresql-client" > /dev/null 2>&1; then
            success "PostgreSQL client installed on $NODE_HOST"
        else
            error "Failed to install PostgreSQL client on $NODE_HOST" || return 1
        fi
    fi
}

###############################################################################
# Test 9: Connectivity Test
###############################################################################
test_postgresql_connectivity() {
    log "Test 9: Testing PostgreSQL connection from $NODE_HOST to $SQL_HOST..."
    
    if ssh_exec "$NODE_HOST" "PGPASSWORD='$SQL_PASS' psql -h $SQL_IP -U $TEST_USER -d $SQL_DB -c 'SELECT NOW();'" 2>/dev/null; then
        success "PostgreSQL connection successful!"
        success "Can connect from $NODE_HOST to PostgreSQL on $SQL_HOST"
        return 0
    else
        error "PostgreSQL connection failed from $NODE_HOST to $SQL_HOST" || return 1
    fi
}

###############################################################################
# Test 10: Data Transfer Test
###############################################################################
test_data_transfer() {
    log "Test 10: Testing data transfer capability..."
    
    if ssh_exec "$NODE_HOST" << 'EOF' 2>/dev/null; then
        PGPASSWORD='testpassword' psql -h $SQL_IP -U testuser -d testdb << 'PSQL_EOF'
            CREATE TABLE IF NOT EXISTS test_data (
                id SERIAL PRIMARY KEY,
                data TEXT,
                created_at TIMESTAMP DEFAULT NOW()
            );
            INSERT INTO test_data (data) VALUES ('Test data from node-steelgem');
            SELECT * FROM test_data;
        PSQL_EOF
EOF
        success "Data transfer test successful"
    else
        warning "Data transfer test encountered issues"
    fi
}

###############################################################################
# Summary Report
###############################################################################
print_summary() {
    echo ""
    echo "========================================"
    echo "PostgreSQL Connectivity Test Summary"
    echo "========================================"
    echo "SQL Host: $SQL_HOST ($SQL_IP)"
    echo "Node Host: $NODE_HOST ($NODE_IP)"
    echo ""
    echo "Connection Details:"
    echo "  Host: $SQL_IP"
    echo "  Port: 5432"
    echo "  User: $TEST_USER"
    echo "  Database: $SQL_DB"
    echo ""
    echo "To manually test:"
    echo "  ssh $NODE_HOST \"psql -h $SQL_IP -U $TEST_USER -d $SQL_DB -c 'SELECT NOW();'\""
    echo "========================================"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################
main() {
    log "Starting PostgreSQL connectivity tests..."
    log "Target SQL Server: $SQL_HOST"
    log "Target Node Server: $NODE_HOST"
    echo ""
    
    local failed=0
    
    # Run all tests
    test_ssh_connectivity || ((failed++))
    echo ""
    
    test_postgresql_installed || ((failed++))
    echo ""
    
    test_postgresql_service || ((failed++))
    echo ""
    
    test_postgresql_network || true
    echo ""
    
    get_server_ips || ((failed++))
    echo ""
    
    test_hba_config || true
    echo ""
    
    test_user_exists || true
    echo ""
    
    test_postgres_client || ((failed++))
    echo ""
    
    test_postgresql_connectivity || ((failed++))
    echo ""
    
    test_data_transfer || true
    echo ""
    
    print_summary
    
    if [[ $failed -eq 0 ]]; then
        success "All critical tests passed!"
        return 0
    else
        error "Some tests failed. See above for details."
        return 1
    fi
}

# Run main function
main "$@"
