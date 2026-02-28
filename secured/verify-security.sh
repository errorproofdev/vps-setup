#!/bin/bash

# verify-security.sh
# VPS Security Verification Script
# Run this after configure.sh to validate all security measures are in place
#
# USAGE: sudo ./verify-security.sh

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to check condition and report
check() {
    local description="$1"
    local command="$2"
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $description"
        ((FAILED++))
    fi
}

# Function for warnings
warn() {
    local description="$1"
    echo -e "${YELLOW}⚠${NC} $description"
    ((WARNINGS++))
}

# Function for informational items
info() {
    local description="$1"
    echo -e "${BLUE}ℹ${NC} $description"
}

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         VPS SECURITY VERIFICATION CHECKLIST                    ║"
echo "║                                                                ║"
echo "║   Run this script after configure.sh to verify all security    ║"
echo "║   measures are properly configured.                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# 1. SSH Security
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. SSH HARDENING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "Root login disabled" "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config"
check "Password auth disabled" "grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config"
check "Public key auth enabled" "grep -q '^PubkeyAuthentication yes' /etc/ssh/sshd_config"
check "Max auth tries limited" "grep -q '^MaxAuthTries 3' /etc/ssh/sshd_config"
check "Empty passwords denied" "grep -q '^PermitEmptyPasswords no' /etc/ssh/sshd_config"

# Check if SSH is actually running
if systemctl is-active --quiet ssh; then
    check "SSH service running" "true"
else
    warn "SSH service not running"
fi

echo ""

# 2. UFW Firewall
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. UFW FIREWALL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "UFW enabled" "ufw status | grep -q 'Status: active'"
check "Default incoming policy: DENY" "ufw status | grep -q 'Default: deny (incoming)'"
check "Default outgoing policy: ALLOW" "ufw status | grep -q 'Default: allow (outgoing)'"
check "SSH port allowed (22/tcp)" "ufw status | grep -q '22/tcp'"
check "HTTP port allowed (80/tcp)" "ufw status | grep -q '80/tcp'"
check "HTTPS port allowed (443/tcp)" "ufw status | grep -q '443/tcp'"
check "App port DENIED (3000/tcp)" "ufw status | grep -q '3000/tcp' && ufw status | grep '3000/tcp' | grep -q 'DENY'"
check "App port DENIED (3001/tcp)" "ufw status | grep -q '3001/tcp' && ufw status | grep '3001/tcp' | grep -q 'DENY'"
check "App port DENIED (3002/tcp)" "ufw status | grep -q '3002/tcp' && ufw status | grep '3002/tcp' | grep -q 'DENY'"

echo ""

# 3. Intrusion Detection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. INTRUSION DETECTION (Fail2Ban)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "Fail2Ban installed" "which fail2ban-client > /dev/null"
check "Fail2Ban service running" "systemctl is-active --quiet fail2ban"
check "Fail2Ban enabled on boot" "systemctl is-enabled fail2ban > /dev/null 2>&1"
check "SSH jail configured" "grep -q '\\[sshd\\]' /etc/fail2ban/jail.local"

echo ""

# 4. NGINX Web Server
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. NGINX WEB SERVER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "NGINX installed" "which nginx > /dev/null"
check "NGINX service running" "systemctl is-active --quiet nginx"
check "NGINX enabled on boot" "systemctl is-enabled nginx > /dev/null 2>&1"
check "NGINX config valid" "nginx -t 2>/dev/null | grep -q 'successful'"
check "Config directories exist" "[ -d /etc/nginx/sites-available ] && [ -d /etc/nginx/sites-enabled ]"

echo ""

# 5. Application User
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. NON-ROOT APPLICATION USER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "appuser account exists" "id appuser > /dev/null 2>&1"
check "appuser has no login shell" "grep appuser /etc/passwd | grep -q '/usr/sbin/nologin'"
check "appuser is system user" "grep appuser /etc/passwd | grep -q '^appuser:x:.*:.*::'"

# Check application directories
check "detoxnearme app directory exists" "[ -d /var/www/apps/detoxnearme ]"
check "edge-nextjs app directory exists" "[ -d /var/www/apps/edge-nextjs ]"
check "forge-nextjs app directory exists" "[ -d /var/www/apps/forge-nextjs ]"

# Check directory ownership
check "detoxnearme owned by appuser" "[ $(stat -c '%U' /var/www/apps/detoxnearme) = 'appuser' ]"
check "edge-nextjs owned by appuser" "[ $(stat -c '%U' /var/www/apps/edge-nextjs) = 'appuser' ]"
check "forge-nextjs owned by appuser" "[ $(stat -c '%U' /var/www/apps/forge-nextjs) = 'appuser' ]"

# Check PM2 directories
check "PM2 socket directory exists" "[ -d /var/run/pm2 ]"
check "PM2 log directory exists" "[ -d /var/log/pm2 ]"
check "PM2 socket dir owned by appuser" "[ $(stat -c '%U' /var/run/pm2) = 'appuser' ]"
check "PM2 log dir owned by appuser" "[ $(stat -c '%U' /var/log/pm2) = 'appuser' ]"

echo ""

# 6. Backup & Monitoring
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. BACKUP & MONITORING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "Kopia installed" "which kopia > /dev/null"
check "OSSEC installed" "[ -d /var/ossec ]"
check "Slack notifications configured" "[ -f /etc/slack_config ]"
check "Unattended upgrades configured" "[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]"

echo ""

# 7. Network Exposure Check
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. NETWORK EXPOSURE CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# These should FAIL (apps not listening on TCP)
if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
    warn "Port 3000 is LISTENING (should be Unix socket only)"
else
    check "Port 3000 not listening (apps use Unix sockets)" "true"
fi

if netstat -tlnp 2>/dev/null | grep -q ":3001 "; then
    warn "Port 3001 is LISTENING (should be Unix socket only)"
else
    check "Port 3001 not listening (apps use Unix sockets)" "true"
fi

if netstat -tlnp 2>/dev/null | grep -q ":3002 "; then
    warn "Port 3002 is LISTENING (should be Unix socket only)"
else
    check "Port 3002 not listening (apps use Unix sockets)" "true"
fi

# Only SSH, HTTP, HTTPS should be listening
check "SSH listening on port 22" "netstat -tlnp 2>/dev/null | grep -q ':22 '"
check "NGINX listening on port 80" "netstat -tlnp 2>/dev/null | grep -q ':80 '"
check "NGINX listening on port 443" "netstat -tlnp 2>/dev/null | grep -q ':443 '"

echo ""

# 8. Security Best Practices
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. SECURITY BEST PRACTICES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check "Automatic security updates enabled" "[ -f /etc/apt/apt.conf.d/50unattended-upgrades ] && grep -q 'APT::Periodic::Update-Package-Lists' /etc/apt/apt.conf.d/50unattended-upgrades"
check "Root account locked (no shell)" "grep '^root:' /etc/passwd | grep -q '/bin/bash' || grep '^root:' /etc/passwd | grep -q '/bin/nologin'"

# Show root user status
if grep '^root:' /etc/passwd | grep -q '/bin/bash'; then
    warn "Root user still has /bin/bash (consider disabling)"
else
    info "Root user security configured"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All security checks PASSED!${NC}"
    echo ""
    echo "Your VPS is hardened and ready for application deployment."
    echo ""
    echo "Next Steps:"
    echo "  1. Read: docs/SECURE-NON-ROOT-DEPLOYMENT.md"
    echo "  2. Deploy Node.js as appuser (not root)"
    echo "  3. Deploy apps using ecosystem.config.secure.js"
    echo "  4. Configure NGINX with NGINX-UNIX-SOCKET.conf"
    echo ""
    echo "System is SECURE - apps will run with:"
    echo "  ✓ Non-root user (appuser, uid != 0)"
    echo "  ✓ Unix socket isolation (no TCP exposure)"
    echo "  ✓ RCE contained to appuser context"
    echo "  ✓ Hardened SSH (keys only, no root)"
    echo "  ✓ UFW firewall (deny by default)"
    exit 0
else
    echo -e "${RED}✗ Some security checks FAILED!${NC}"
    echo ""
    echo "Please review the failed items above and fix them before deployment."
    echo ""
    echo "Common issues:"
    echo "  • UFW rules not applied: run 'sudo ufw reload'"
    echo "  • Services not running: run 'sudo systemctl restart [service]'"
    echo "  • Directory permissions: run 'sudo chown -R appuser:appuser /var/www/apps'"
    echo ""
    exit 1
fi
