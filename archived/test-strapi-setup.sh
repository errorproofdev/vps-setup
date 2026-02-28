#!/bin/bash

###############################################################################
# Strapi PostgreSQL & HTTPS/SSL Test Script
# Tests sql-steelgem server configuration for Strapi deployment
# Usage: ./test-strapi-setup.sh
###############################################################################

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SQL_HOST="${1:-sql-steelgem}"
DB_NAME="detoxnearme"
DB_USER="strapi"
DOMAIN="dev-cms.detoxnearme.com"
STRAPI_PORT="1337"
PROD_SERVER="detox-strapi-prod"
PROD_SERVER="detox-strapi-prod"

# Test results tracking
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED_TESTS++))
}

error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED_TESTS++))
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNING_TESTS++))
}

section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

###############################################################################
# Test 1: SSH Connectivity
###############################################################################
test_ssh_connectivity() {
    section "Test 1: SSH Connectivity"
    
    if ssh -o ConnectTimeout=5 "$SQL_HOST" "echo 'OK'" > /dev/null 2>&1; then
        success "SSH connection to $SQL_HOST established"
        
        # Get server info
        local os_info=$(ssh "$SQL_HOST" "cat /etc/os-release | grep PRETTY_NAME" 2>/dev/null | cut -d'"' -f2)
        log "Server OS: $os_info"
    else
        error "Cannot connect to $SQL_HOST via SSH"
        return 1
    fi
}

###############################################################################
# Test 2: PostgreSQL Installation & Service
###############################################################################
test_postgresql_service() {
    section "Test 2: PostgreSQL Installation & Service"
    
    # Check if PostgreSQL is installed
    if ssh "$SQL_HOST" "which psql" > /dev/null 2>&1; then
        success "PostgreSQL client is installed"
        
        # Get version
        local version=$(ssh "$SQL_HOST" "psql --version" 2>/dev/null)
        log "Version: $version"
    else
        error "PostgreSQL client not found"
        return 1
    fi
    
    # Check service status
    if ssh "$SQL_HOST" "sudo systemctl is-active postgresql" > /dev/null 2>&1; then
        success "PostgreSQL service is running"
    else
        error "PostgreSQL service is not running"
        return 1
    fi
    
    # Check if service is enabled
    if ssh "$SQL_HOST" "sudo systemctl is-enabled postgresql" > /dev/null 2>&1; then
        success "PostgreSQL service is enabled (starts on boot)"
    else
        warning "PostgreSQL service is not enabled for boot"
    fi
}

###############################################################################
# Test 3: Database & User Configuration
###############################################################################
test_database_config() {
    section "Test 3: Database & User Configuration"
    
    # Check if database exists
    if ssh "$SQL_HOST" "sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME" 2>/dev/null; then
        success "Database '$DB_NAME' exists"
    else
        error "Database '$DB_NAME' not found"
        return 1
    fi
    
    # Check if user exists
    if ssh "$SQL_HOST" "sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'\"" | grep -q 1 2>/dev/null; then
        success "Database user '$DB_USER' exists"
    else
        error "Database user '$DB_USER' not found"
        return 1
    fi
    
    # Check user permissions on database
    local perms=$(ssh "$SQL_HOST" "sudo -u postgres psql -d $DB_NAME -tAc \"SELECT has_database_privilege('$DB_USER', '$DB_NAME', 'CONNECT')\"" 2>/dev/null)
    if [[ "$perms" == "t" ]]; then
        success "User '$DB_USER' can connect to database '$DB_NAME'"
    else
        error "User '$DB_USER' cannot connect to database '$DB_NAME'"
    fi
}

###############################################################################
# Test 4: Database Connectivity Test
###############################################################################
test_database_connection() {
    section "Test 4: Database Connectivity Test"
    
    log "Attempting to connect as user '$DB_USER'..."
    
    # Test connection (will need password interactively or from .pgpass)
    if ssh "$SQL_HOST" "sudo -u postgres psql -d $DB_NAME -c '\conninfo'" > /dev/null 2>&1; then
        success "Successfully connected to database as postgres user"
    else
        warning "Could not test connection as postgres user"
    fi
    
    # Check if there are any tables
    local table_count=$(ssh "$SQL_HOST" "sudo -u postgres psql -d $DB_NAME -tAc \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'\"" 2>/dev/null)
    
    if [[ -n "$table_count" && "$table_count" -gt 0 ]]; then
        success "Database has $table_count tables (data imported)"
    else
        warning "Database appears empty (no tables found)"
        log "You may need to import your database dump"
    fi
}

###############################################################################
# Test 5: PostgreSQL Network Configuration
###############################################################################
test_postgresql_network() {
    section "Test 5: PostgreSQL Network Configuration"
    
    # Check listening ports
    local listening=$(ssh "$SQL_HOST" "sudo ss -tlnp | grep postgres" 2>/dev/null)
    
    if echo "$listening" | grep -q "127.0.0.1:5432"; then
        success "PostgreSQL is listening on localhost:5432"
    else
        warning "PostgreSQL might not be listening on expected port"
    fi
    
    # Check pg_hba.conf for local connections
    log "Checking PostgreSQL authentication configuration..."
    if ssh "$SQL_HOST" "sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v '^#' | grep -q 'local.*all.*all.*peer'" 2>/dev/null; then
        success "Local peer authentication configured"
    fi
    
    if ssh "$SQL_HOST" "sudo cat /etc/postgresql/*/main/pg_hba.conf | grep -v '^#' | grep -q 'host.*all.*all.*127.0.0.1'" 2>/dev/null; then
        success "Localhost TCP authentication configured"
    fi
}

###############################################################################
# Test 6: Node.js & PM2 Installation
###############################################################################
test_nodejs_pm2() {
    section "Test 6: Node.js & PM2 Installation"
    
    # Check Node.js
    if ssh "$SQL_HOST" "which node" > /dev/null 2>&1; then
        local node_version=$(ssh "$SQL_HOST" "node --version" 2>/dev/null)
        success "Node.js is installed: $node_version"
    else
        error "Node.js not found"
        return 1
    fi
    
    # Check PM2
    if ssh "$SQL_HOST" "which pm2" > /dev/null 2>&1; then
        success "PM2 is installed"
        
        # Check PM2 status
        local pm2_status=$(ssh "$SQL_HOST" "pm2 status" 2>/dev/null || echo "no processes")
        log "PM2 Status: $pm2_status"
    else
        error "PM2 not found"
        return 1
    fi
}

###############################################################################
# Test 7: Strapi Application Files
###############################################################################
test_strapi_files() {
    section "Test 7: Strapi Application Files"
    
    local app_dir="/home/ubuntu/detox-near-me-strapi"
    
    # Check if application directory exists
    if ssh "$SQL_HOST" "test -d $app_dir" 2>/dev/null; then
        success "Application directory exists: $app_dir"
        
        # Check for key files
        if ssh "$SQL_HOST" "test -f $app_dir/package.json" 2>/dev/null; then
            success "package.json found"
        else
            warning "package.json not found - Strapi app may not be deployed"
        fi
        
        if ssh "$SQL_HOST" "test -d $app_dir/node_modules" 2>/dev/null; then
            success "node_modules directory exists"
        else
            warning "node_modules not found - run 'npm install'"
        fi
        
        if ssh "$SQL_HOST" "test -f $app_dir/.env" 2>/dev/null; then
            success ".env configuration file exists"
            
            # Check for key environment variables (without exposing values)
            local env_vars=$(ssh "$SQL_HOST" "grep -E '^(DATABASE_|HOST=|PORT=|NODE_ENV=)' $app_dir/.env | cut -d= -f1" 2>/dev/null)
            if [[ -n "$env_vars" ]]; then
                log "Found environment variables:"
                echo "$env_vars" | while read var; do
                    log "  - $var"
                done
            fi
        else
            error ".env configuration file not found"
        fi
    else
        error "Application directory not found: $app_dir"
        log "Deploy your Strapi application to this directory"
    fi
}

###############################################################################
# Test 8: NGINX Installation & Configuration
###############################################################################
test_nginx_config() {
    section "Test 8: NGINX Installation & Configuration"
    
    # Check if NGINX is installed
    if ssh "$SQL_HOST" "which nginx" > /dev/null 2>&1; then
        success "NGINX is installed"
        
        local nginx_version=$(ssh "$SQL_HOST" "nginx -v 2>&1" | cut -d'/' -f2)
        log "Version: $nginx_version"
    else
        error "NGINX not found"
        return 1
    fi
    
    # Check service status
    if ssh "$SQL_HOST" "sudo systemctl is-active nginx" > /dev/null 2>&1; then
        success "NGINX service is running"
    else
        error "NGINX service is not running"
        return 1
    fi
    
    # Check configuration syntax
    if ssh "$SQL_HOST" "sudo nginx -t" > /dev/null 2>&1; then
        success "NGINX configuration syntax is valid"
    else
        error "NGINX configuration has syntax errors"
    fi
    
    # Check if site configuration exists
    if ssh "$SQL_HOST" "test -f /etc/nginx/sites-available/$DOMAIN.conf" 2>/dev/null; then
        success "Site configuration exists: $DOMAIN.conf"
        
        if ssh "$SQL_HOST" "test -L /etc/nginx/sites-enabled/$DOMAIN.conf" 2>/dev/null; then
            success "Site is enabled (symlink exists)"
        else
            warning "Site configuration not enabled"
        fi
    elif ssh "$SQL_HOST" "test -f /etc/nginx/sites-available/cms.detoxnearme.com.conf" 2>/dev/null; then
        success "Site configuration exists: cms.detoxnearme.com.conf (serves $DOMAIN)"
        
        if ssh "$SQL_HOST" "test -L /etc/nginx/sites-enabled/cms.detoxnearme.com.conf" 2>/dev/null; then
            success "Site is enabled (symlink exists)"
        else
            warning "Site configuration not enabled"
        fi
    else
        warning "Site configuration not found for $DOMAIN"
    fi
}

###############################################################################
# Test 9: SSL/HTTPS Configuration
###############################################################################
test_ssl_config() {
    section "Test 9: SSL/HTTPS Configuration"
    
    log "Checking SSL setup (Cloudflare proxy mode expected)..."
    
    # Check for SSL certificates from production server
    if ssh "$SQL_HOST" "test -f /etc/ssl/cert.pem && test -f /etc/ssl/key.pem" 2>/dev/null; then
        success "SSL certificate files found in /etc/ssl/"
        
        # Check certificate expiry
        local cert_info=$(ssh "$SQL_HOST" "sudo openssl x509 -in /etc/ssl/cert.pem -noout -dates" 2>/dev/null)
        log "Certificate dates:"
        echo "$cert_info" | sed 's/^/    /'
        
        # Check if cert is valid
        if ssh "$SQL_HOST" "sudo openssl x509 -in /etc/ssl/cert.pem -noout -checkend 86400" > /dev/null 2>&1; then
            success "Certificate is valid (expires in >24 hours)"
        else
            error "Certificate is expired or expiring soon"
        fi
        
        # Verify cert matches production server
        log "Certificates should match $PROD_SERVER for Cloudflare proxy"
    else
        warning "SSL certificate files not found in /etc/ssl/"
        log "Copy certificates from $PROD_SERVER:"
        log "  scp $PROD_SERVER:/etc/ssl/cert.pem /tmp/ && scp /tmp/cert.pem $SQL_HOST:/tmp/"
        log "  scp $PROD_SERVER:/etc/ssl/key.pem /tmp/ && scp /tmp/key.pem $SQL_HOST:/tmp/"
        log "  ssh $SQL_HOST 'sudo mv /tmp/{cert,key}.pem /etc/ssl/ && sudo chmod 644 /etc/ssl/cert.pem && sudo chmod 600 /etc/ssl/key.pem'"
    fi
    
    # Check NGINX SSL configuration
    local nginx_conf_file=""
    if ssh "$SQL_HOST" "test -f /etc/nginx/sites-available/$DOMAIN.conf" 2>/dev/null; then
        nginx_conf_file="/etc/nginx/sites-available/$DOMAIN.conf"
    elif ssh "$SQL_HOST" "test -f /etc/nginx/sites-available/cms.detoxnearme.com.conf" 2>/dev/null; then
        nginx_conf_file="/etc/nginx/sites-available/cms.detoxnearme.com.conf"
    fi
    
    if [[ -n "$nginx_conf_file" ]]; then
        if ssh "$SQL_HOST" "sudo grep -q 'listen.*443 ssl' $nginx_conf_file" 2>/dev/null; then
            success "NGINX configured to listen on port 443 (HTTPS)"
        elif ssh "$SQL_HOST" "sudo grep -q '#.*listen.*443 ssl' $nginx_conf_file" 2>/dev/null; then
            warning "NGINX HTTPS configuration is commented out"
            log "Uncomment SSL section in $nginx_conf_file after adding certificates"
        else
            warning "NGINX not configured for HTTPS"
        fi
    else
        warning "Cannot find NGINX configuration file"
    fi
}

###############################################################################
# Test 10: Firewall & Port Configuration
###############################################################################
test_firewall_ports() {
    section "Test 10: Firewall & Port Configuration"
    
    # Check if UFW is installed and active
    if ssh "$SQL_HOST" "which ufw" > /dev/null 2>&1; then
        success "UFW firewall is installed"
        
        if ssh "$SQL_HOST" "sudo ufw status | grep -q 'Status: active'" 2>/dev/null; then
            success "UFW is active"
            
            # Check specific ports
            local ufw_status=$(ssh "$SQL_HOST" "sudo ufw status" 2>/dev/null)
            
            if echo "$ufw_status" | grep -q "22"; then
                success "Port 22 (SSH) is allowed"
            else
                warning "Port 22 (SSH) may not be explicitly allowed"
            fi
            
            if echo "$ufw_status" | grep -q "80"; then
                success "Port 80 (HTTP) is allowed"
            else
                warning "Port 80 (HTTP) not allowed in firewall"
            fi
            
            if echo "$ufw_status" | grep -q "443"; then
                success "Port 443 (HTTPS) is allowed"
            else
                warning "Port 443 (HTTPS) not allowed in firewall"
            fi
        else
            warning "UFW is installed but not active"
        fi
    else
        warning "UFW firewall not found"
    fi
}

###############################################################################
# Test 11: HTTP/HTTPS Connectivity Tests
###############################################################################
test_http_connectivity() {
    section "Test 11: HTTP/HTTPS Connectivity Tests"
    
    # Test local Strapi port
    log "Testing local Strapi server on port $STRAPI_PORT..."
    if ssh "$SQL_HOST" "curl -f -s http://localhost:$STRAPI_PORT > /dev/null" 2>/dev/null; then
        success "Strapi is responding on port $STRAPI_PORT"
    else
        warning "Strapi not responding on port $STRAPI_PORT - may not be running"
        log "Start with: pm2 start npm --name strapi -- start"
    fi
    
    # Test NGINX proxy
    log "Testing NGINX proxy to Strapi..."
    if ssh "$SQL_HOST" "curl -f -s http://localhost > /dev/null" 2>/dev/null; then
        success "NGINX is serving content on port 80"
    else
        warning "NGINX not responding on port 80"
    fi
    
    # Test external HTTP access (if domain resolves)
    log "Testing external HTTP access..."
    if curl -f -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" 2>/dev/null | grep -q "200\|301\|302"; then
        success "Domain $DOMAIN is accessible via HTTP"
    else
        warning "Domain $DOMAIN not accessible from external network"
        log "Check DNS records and firewall rules"
    fi
    
    # Test HTTPS (if SSL configured)
    log "Testing HTTPS access..."
    if curl -f -s -k -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null | grep -q "200"; then
        success "Domain $DOMAIN is accessible via HTTPS"
    else
        warning "Domain $DOMAIN not accessible via HTTPS"
        log "SSL may not be configured yet"
    fi
}

###############################################################################
# Test 12: PM2 Process Status
###############################################################################
test_pm2_process() {
    section "Test 12: PM2 Process Status"
    
    # Check if Strapi is running under PM2
    local pm2_list=$(ssh "$SQL_HOST" "pm2 jlist" 2>/dev/null)
    
    if echo "$pm2_list" | grep -q "strapi"; then
        success "Strapi process found in PM2"
        
        # Get process details
        local status=$(ssh "$SQL_HOST" "pm2 jlist | jq -r '.[] | select(.name==\"strapi\") | .pm2_env.status'" 2>/dev/null)
        local uptime=$(ssh "$SQL_HOST" "pm2 jlist | jq -r '.[] | select(.name==\"strapi\") | .pm2_env.pm_uptime'" 2>/dev/null)
        local restarts=$(ssh "$SQL_HOST" "pm2 jlist | jq -r '.[] | select(.name==\"strapi\") | .pm2_env.restart_time'" 2>/dev/null)
        
        if [[ "$status" == "online" ]]; then
            success "Strapi status: online"
        else
            error "Strapi status: $status"
        fi
        
        if [[ -n "$restarts" ]]; then
            log "Process restarts: $restarts"
        fi
    else
        warning "No Strapi process found in PM2"
        log "Start with: pm2 start ecosystem.config.js --env production"
        log "Or: cd /home/ubuntu/detox-near-me-strapi && pm2 start npm --name strapi -- start"
    fi
    
    # Check PM2 startup configuration
    if ssh "$SQL_HOST" "systemctl is-enabled pm2-ubuntu" > /dev/null 2>&1; then
        success "PM2 configured to start on boot"
    else
        warning "PM2 not configured for startup"
        log "Configure with: pm2 startup systemd && pm2 save"
    fi
}

###############################################################################
# Test Summary
###############################################################################
print_summary() {
    section "Test Summary"
    
    local total=$((PASSED_TESTS + FAILED_TESTS + WARNING_TESTS))
    
    echo ""
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "Total: $total"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        success "All critical tests passed! ✨"
        echo ""
        if [[ $WARNING_TESTS -gt 0 ]]; then
            warning "There are $WARNING_TESTS warnings to address"
        fi
    else
        error "$FAILED_TESTS critical test(s) failed"
        echo ""
        echo "Review the failures above and fix before deploying to production."
        return 1
    fi
}

###############################################################################
# Next Steps Recommendations
###############################################################################
print_next_steps() {
    section "Recommended Next Steps"
    
    echo ""
    echo "1. 📦 Deploy Strapi Application (if not done):"
    echo "   cd /path/to/local/detox-near-me-strapi"
    echo "   tar -czf detox-strapi.tar.gz ."
    echo "   scp detox-strapi.tar.gz $SQL_HOST:/home/ubuntu/"
    echo "   ssh $SQL_HOST 'cd /home/ubuntu/detox-near-me-strapi && tar -xzf ../detox-strapi.tar.gz'"
    echo ""
    echo "2. 🔧 Install Dependencies:"
    echo "   ssh $SQL_HOST 'cd /home/ubuntu/detox-near-me-strapi && npm install --production'"
    echo ""
    echo "3. 🗄️ Import Database (if needed):"
    echo "   scp conf/detoxnearme-strapi/db/detoxnearme_pgsql.dump $SQL_HOST:/tmp/"
    echo "   ssh $SQL_HOST 'sudo -u postgres psql -d detoxnearme < /tmp/detoxnearme_pgsql.dump'"
    echo ""
    echo "4. 🔐 Copy SSL certificates from production:"
    echo "   scp $PROD_SERVER:/etc/ssl/cert.pem /tmp/ && scp /tmp/cert.pem $SQL_HOST:/tmp/"
    echo "   scp $PROD_SERVER:/etc/ssl/key.pem /tmp/ && scp /tmp/key.pem $SQL_HOST:/tmp/"
    echo "   ssh $SQL_HOST 'sudo mv /tmp/{cert,key}.pem /etc/ssl/ && sudo nginx -t && sudo systemctl reload nginx'"
    echo ""
    echo "5. 🚀 Start Strapi:"
    echo "   ssh $SQL_HOST 'cd /home/ubuntu/detox-near-me-strapi && pm2 start npm --name strapi -- start'"
    echo "   ssh $SQL_HOST 'pm2 save && pm2 startup'"
    echo ""
    echo "6. 🔍 Monitor Logs:"
    echo "   ssh $SQL_HOST 'pm2 logs strapi'"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################
main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║      Strapi PostgreSQL & HTTPS/SSL Test Suite            ║${NC}"
    echo -e "${CYAN}║      Testing: $SQL_HOST                                   ║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run all tests
    test_ssh_connectivity || true
    test_postgresql_service || true
    test_database_config || true
    test_database_connection || true
    test_postgresql_network || true
    test_nodejs_pm2 || true
    test_strapi_files || true
    test_nginx_config || true
    test_ssl_config || true
    test_firewall_ports || true
    test_http_connectivity || true
    test_pm2_process || true
    
    # Print results
    print_summary
    print_next_steps
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main
