#!/bin/bash

# configure.sh
# VPS Hardening and Configuration Script
# This script implements the hardening steps described in the README
# 
# USAGE: sudo ./configure.sh
# 
# This script will pause at critical checkpoints for verification.
# At each pause, verify security measures before continuing.

# Exit immediately if a command exits with a non-zero status
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored section headers
print_section() {
    echo ""
    echo "===================================="
    echo -e "${BLUE}$1${NC}"
    echo "===================================="
    echo ""
}

# Function to print verification checkpoints
verify_checkpoint() {
    local checkpoint_name="$1"
    echo ""
    echo -e "${YELLOW}⏸️  CHECKPOINT: $checkpoint_name${NC}"
    echo -e "${YELLOW}Verify the measures above before continuing...${NC}"
    echo ""
    read -p "Press ENTER to continue (or Ctrl+C to abort): " -r
}

# Function to print section headers
print_section() {
    echo "===================================="
    echo "$1"
    echo "===================================="
}

# Function to check if a package is installed
is_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Function to install a package if it's not already installed
install_if_not_exists() {
    if ! is_installed "$1"; then
        echo "Installing $1..."
        apt install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Pre-flight checks
print_section "Pre-Flight Security Checklist"
echo ""
echo "This script will:"
echo "  ✓ Harden SSH (disable root login, key-only auth)"
echo "  ✓ Configure UFW firewall (deny by default, allow 22/80/443)"
echo "  ✓ Install Fail2Ban (intrusion detection)"
echo "  ✓ Configure automatic security updates"
echo "  ✓ Install OSSEC (file integrity monitoring)"
echo "  ✓ Install NGINX (reverse proxy)"
echo "  ✓ Create appuser (non-root application user)"
echo "  ✓ Create empty app directories"
echo "  ✓ Configure backup system (Kopia + Backblaze B2)"
echo ""
echo "🔐 SECURITY FEATURES:"
echo "  • UFW will DENY ports 3000-3002 (no direct app access)"
echo "  • Apps will run as appuser, not root"
echo "  • All app ports use Unix sockets, not TCP"
echo "  • SSH keys required (no password auth)"
echo "  • Root login disabled"
echo ""
verify_checkpoint "Pre-Flight - Ready to harden system?"

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if config file exists
CONFIG_FILE="vps_config.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found. Please create it from the template."
    exit 1
fi

# Copy the config file to /etc/vps_config.env
cp "$CONFIG_FILE" /etc/vps_config.env
chmod 600 /etc/vps_config.env

# Source the configuration file
source "$CONFIG_FILE"

# Validate required variables
required_vars=("TIMEZONE" "SLACK_WEBHOOK_URL" "B2_BUCKET_NAME" "B2_KEY_ID" "B2_APPLICATION_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in the configuration file."
        exit 1
    fi
done

# Function to connect to Kopia repository
connect_kopia_repository() {
    if ! kopia repository status &>/dev/null; then
        echo "Connecting to Kopia repository..."
        kopia repository connect b2 --bucket="$B2_BUCKET_NAME" --key-id="$B2_KEY_ID" --key="$B2_APPLICATION_KEY" --password="$KOPIA_REPOSITORY_PASSPHRASE"
    fi
}

# 1. Find the fastest mirror and update sources.list
print_section "Finding the fastest mirror"

# Backup the current sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Find the fastest mirror
echo "Finding the fastest mirror. This may take a moment..."
fastest_mirror=$(curl -s http://mirrors.ubuntu.com/mirrors.txt | xargs -I {} sh -c 'echo $(curl -r 0-102400 -s -w %{speed_download} -o /dev/null {}/ls-lR.gz) {}' | sort -g -r | head -1 | awk '{ print $2 }')

echo "Fastest mirror found: $fastest_mirror"

# Update sources.list with the fastest mirror, including country-specific mirrors
if [ -f "/etc/apt/sources.list" ]; then
    sed -i.bak -E "s@http://([a-z]{2}\.)?archive\.ubuntu\.com/ubuntu/?@$fastest_mirror@g" /etc/apt/sources.list
    sed -i -E "s@http://security\.ubuntu\.com/ubuntu/?@$fastest_mirror@g" /etc/apt/sources.list
fi

# Update ubuntu.sources with the fastest mirror
if [ -f "/etc/apt/sources.list.d/ubuntu.sources" ]; then
    sed -i.bak -E "s@http://([a-z]{2}\.)?archive\.ubuntu\.com/ubuntu/?@$fastest_mirror@g" /etc/apt/sources.list.d/ubuntu.sources
    sed -i -E "s@http://security\.ubuntu\.com/ubuntu/?@$fastest_mirror@g" /etc/apt/sources.list.d/ubuntu.sources
fi

# 2. Update and Upgrade
print_section "Updating and Upgrading System"
apt update
apt upgrade -y

# 3. Set server timezone
print_section "Setting Server Timezone"
if timedatectl set-timezone "$TIMEZONE"; then
    echo "Timezone set to $TIMEZONE"
else
    echo "Failed to set timezone. Please check if the entered timezone is correct."
    exit 1
fi
echo "Current server time:"
date

# 4. Install essential tools
print_section "Installing essential tools"
install_if_not_exists curl

# 5. Install Docker
print_section "Installing Docker"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
    rm get-docker.sh
else
    echo "Docker is already installed."
fi

# 6. Install and Configure UFW
print_section "Installing and Configuring UFW"
install_if_not_exists ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow in on lo to any port 53
ufw allow in on lo to any port 61209
echo "y" | ufw enable
ufw reload

# Verification
echo ""
echo "✓ UFW Firewall Rules:"
ufw status verbose

verify_checkpoint "UFW Firewall - Verify rules are correct (22/80/443 allowed, others denied)"

# 7. SSH Hardening
print_section "Hardening SSH"

# Safety check: ensure ubuntu user has SSH keys before disabling root login
if [ -z "${SUDO_USER:-}" ]; then
    echo "Error: SUDO_USER is not set. Run this script via sudo from a non-root user."
    exit 1
fi

ubuntu_authorized_keys="/home/${SUDO_USER}/.ssh/authorized_keys"
if [ ! -s "$ubuntu_authorized_keys" ]; then
    echo "Error: No SSH keys found for ${SUDO_USER}."
    echo "Add your public key to: $ubuntu_authorized_keys"
    echo "Then re-run this script to safely disable root login."
    exit 1
fi

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*LoginGraceTime .*/LoginGraceTime 30/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^#*MaxAuthTries .*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/^#*StrictModes .*/StrictModes yes/' /etc/ssh/sshd_config
echo "AllowUsers $SUDO_USER" >> /etc/ssh/sshd_config
systemctl restart ssh

# Verification
echo ""
echo "✓ SSH Hardening Applied:"
grep "^PermitRootLogin" /etc/ssh/sshd_config
grep "^PasswordAuthentication" /etc/ssh/sshd_config
grep "^PubkeyAuthentication" /etc/ssh/sshd_config
grep "^AllowUsers" /etc/ssh/sshd_config

verify_checkpoint "SSH Hardening - Verify above settings are correct"

# 8. Install and Configure Fail2Ban
print_section "Installing and Configuring Fail2Ban"
echo "Installing fail2ban. This may take a few minutes..."
DEBIAN_FRONTEND=noninteractive apt install -y fail2ban

echo "Configuring fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1d
EOF

echo "Starting and enabling fail2ban service..."
systemctl start fail2ban
systemctl enable fail2ban

echo "Checking fail2ban status..."
systemctl is-active --quiet fail2ban && echo "fail2ban is running" || echo "fail2ban failed to start"

# Verification
echo ""
echo "✓ Fail2Ban Configuration:"
echo "  Ban time: 1 hour (default), 1 day (SSH)"
echo "  Max retries: 5 (default), 3 (SSH)"
echo "  Log file: /var/log/auth.log"
systemctl status fail2ban | grep "Active:" || echo "Status check skipped"

verify_checkpoint "Fail2Ban - Verify intrusion detection is running"

# 9. Configure Automatic Security Updates
print_section "Configuring Automatic Security Updates"
install_if_not_exists unattended-upgrades
echo 'Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";' > /etc/apt/apt.conf.d/50unattended-upgrades

# 10. Install and Configure OSSEC
print_section "Installing and Configuring OSSEC"
if [ ! -d "/var/ossec" ]; then
    echo "OSSEC is not installed. Installing now..."
    apt install -y build-essential make gcc libevent-dev libpcre2-dev libssl-dev zlib1g-dev libsystemd-dev
    wget https://github.com/ossec/ossec-hids/archive/3.7.0.tar.gz
    tar -xvzf 3.7.0.tar.gz
    cd ossec-hids-3.7.0

    # Use a here-document to provide input to the install script
    ./install.sh << EOF
en

local

n
y
y
n
n
EOF

    cd ..
    rm -rf ossec-hids-3.7.0 3.7.0.tar.gz
else
    echo "OSSEC is already installed."
fi

# Start OSSEC if it's not already running
if [ -f "/var/ossec/bin/ossec-control" ]; then
    /var/ossec/bin/ossec-control start
fi

# 11. Install Logwatch and disable Postfix
print_section "Installing Logwatch and configuring Postfix"

# Pre-configure Postfix to avoid prompts
echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections

# Install Postfix and Logwatch non-interactively
DEBIAN_FRONTEND=noninteractive apt-get install -y postfix logwatch

# Disable Postfix
systemctl stop postfix
systemctl disable postfix

# Configure Logwatch to use Slack
cat << EOF > /etc/cron.daily/00logwatch
#!/bin/bash
# Run logwatch and pipe to a file first
/usr/sbin/logwatch --output stdout --format text --detail high > /tmp/logwatch_output.txt

# Process the file in chunks to avoid Slack message size limits
cat /tmp/logwatch_output.txt | /usr/local/bin/slack-notify.sh

# Clean up
rm /tmp/logwatch_output.txt
EOF

chmod +x /etc/cron.daily/00logwatch

# 12. Set up Glances with Slack Notifications
print_section "Setting up Glances with Slack Notifications"
install_if_not_exists glances

cat << 'EOF' > /usr/local/bin/glances-to-slack.sh
#!/bin/bash

source /etc/slack_config

while true; do
    # Get Glances output
    output=$(glances --stdout-csv cpu.user,mem,load,network_total)

    # Truncate if too long (3000 char limit for Slack)
    if [ ${#output} -gt 2900 ]; then
        output="${output:0:2900}...(truncated)"
    fi

    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"Glances Report:\n$output\"}" "$SLACK_WEBHOOK_URL"
    sleep 3600  # Send report every hour
done
EOF

chmod +x /usr/local/bin/glances-to-slack.sh

# Create a systemd service for Glances to Slack reporting
cat << EOF > /etc/systemd/system/glances-slack.service
[Unit]
Description=Glances to Slack Reporter
After=network.target

[Service]
ExecStart=/usr/local/bin/glances-to-slack.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable glances-slack.service
systemctl start glances-slack.service

# 13. Install Lynis
print_section "Installing Lynis"
install_if_not_exists lynis

# 14. Set up Slack Notifications
print_section "Setting up Slack Notifications"
echo "SLACK_WEBHOOK_URL=\"$SLACK_WEBHOOK_URL\"" > /etc/slack_config
chmod 600 /etc/slack_config

cat << 'EOF' > /usr/local/bin/slack-notify.sh
#!/bin/bash
source /etc/slack_config

MAX_LENGTH=2900  # Slack has ~3000 char limit for text

if [ -p /dev/stdin ]; then
    # If data is piped in, read it
    message=$(cat)
else
    # Otherwise, use the first argument
    message="$1"
fi

# Check if message is too long and truncate if necessary
if [ ${#message} -gt $MAX_LENGTH ]; then
    # Split into multiple messages if too long
    while [ ${#message} -gt 0 ]; do
        chunk="${message:0:$MAX_LENGTH}"
        remaining="${message:$MAX_LENGTH}"

        # Send chunk
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$chunk\"}" "$SLACK_WEBHOOK_URL"

        # If there's more to send, add a continuation message
        if [ ${#remaining} -gt 0 ]; then
            sleep 1  # Brief pause between messages
        fi

        message="$remaining"
    done
else
    # Send as a single message
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL"
fi
EOF
chmod +x /usr/local/bin/slack-notify.sh

# 15. Set up Kopia with Backblaze B2
print_section "Setting up Kopia with Backblaze B2"
if ! command -v kopia &> /dev/null; then
    curl -s https://kopia.io/signing-key | gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | tee /etc/apt/sources.list.d/kopia.list
    apt update
    apt install kopia -y
else
    echo "Kopia is already installed."
fi

if ! kopia repository status &>/dev/null; then
    echo "Creating Kopia repository..."
    kopia repository create b2 \
        --bucket="$B2_BUCKET_NAME" \
        --key-id="$B2_KEY_ID" \
        --key="$B2_APPLICATION_KEY" \
        --password="$KOPIA_REPOSITORY_PASSPHRASE"
else
    echo "Kopia repository already exists. Connecting..."
    connect_kopia_repository
fi

kopia policy set --global --compression=zstd --keep-latest 30 --keep-hourly 24 --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --keep-annual 3

cat << 'EOF' > /usr/local/bin/kopia-backup.sh
#!/bin/bash

# Source the configuration file
source /etc/vps_config.env

# Function to connect to Kopia repository
connect_kopia_repository() {
    if ! kopia repository status &>/dev/null; then
        echo "Connecting to Kopia repository..."
        kopia repository connect b2 --bucket="$B2_BUCKET_NAME" --key-id="$B2_KEY_ID" --key="$B2_APPLICATION_KEY" --password="$KOPIA_REPOSITORY_PASSPHRASE"
    fi
}

# Ensure connection to Kopia repository
connect_kopia_repository

# Define directories to backup
if [ -d "/etc/easypanel" ]; then
    # If Easypanel is installed, use this specific set of directories
    echo "Easypanel detected, using Easypanel-specific backup paths"
    directories=(
        "/etc"
        "/home"
        "/etc/docker"
        "/root/.docker"
        "/opt"
        "/var/log"
        "/etc/easypanel"
    )
else
    # Standard backup directories when Easypanel is not installed
    echo "Using standard backup paths"
    directories=(
        "/etc"
        "/home"
        "/etc/docker"
        "/root/.docker"
        "/opt"
        "/var/log"
        "/var/lib/docker/volumes"
        "/opt/docker-compose"
    )
fi

backup_status="Kopia backup summary:\n"
failed=0

for dir in "${directories[@]}"; do
    if [ -d "$dir" ] || [ -f "$dir" ]; then
        echo "Backing up $dir..."
        if kopia snapshot create "$dir"; then
            backup_status+="✅ $dir: Success\n"
        else
            backup_status+="❌ $dir: Failed\n"
            failed=1
        fi
    else
        echo "Directory or file not found: $dir. Skipping backup."
        backup_status+="⚠️ $dir: Not found, skipped\n"
    fi
done

# Backup package list
echo "Backing up package list..."
dpkg --get-selections > /root/package_list.txt
if kopia snapshot create /root/package_list.txt; then
    backup_status+="✅ Package list: Success\n"
else
    backup_status+="❌ Package list: Failed\n"
    failed=1
fi

if [ $failed -eq 0 ]; then
    backup_status+="✅ Overall: Kopia backup to Backblaze B2 completed successfully"
else
    backup_status+="❌ Overall: Kopia backup to Backblaze B2 had failures"
fi

echo -e "$backup_status" | /usr/local/bin/slack-notify.sh
EOF

chmod +x /usr/local/bin/kopia-backup.sh

# Schedule daily Kopia backup
print_section "Scheduling Daily Kopia Backup"

# Create a temporary file for the cron job
CRON_FILE=$(mktemp)

# Add the cron job to the temporary file
echo "# Daily Kopia backup at 2 AM
0 2 * * * /usr/local/bin/kopia-backup.sh 2>&1 | tee -a /var/log/kopia-backup.log" > "$CRON_FILE"

# Install the new crontab
crontab "$CRON_FILE"

# Remove the temporary file
rm "$CRON_FILE"

echo "Kopia backup scheduled to run daily at 2 AM as root, with output logged to /var/log/kopia-backup.log"

# 16. Create Dedicated Non-Root Application User
print_section "Creating Dedicated Non-Root Application User"

# Create appuser account with no login shell (security best practice)
if ! id "appuser" &>/dev/null; then
    echo "Creating appuser account (non-root, no shell)..."
    useradd -r -m -s /usr/sbin/nologin appuser
    echo "appuser created successfully"
else
    echo "appuser account already exists"
fi

# Verify appuser creation
echo "Verifying appuser account:"
id appuser

# Create application directories with correct ownership
echo "Creating application deployment directories..."
mkdir -p /var/www/apps/detoxnearme
mkdir -p /var/www/apps/edge-nextjs
mkdir -p /var/www/apps/forge-nextjs
mkdir -p /var/run/pm2
mkdir -p /var/log/pm2

# Set ownership to appuser
chown -R appuser:appuser /var/www/apps
chown appuser:appuser /var/run/pm2
chown appuser:appuser /var/log/pm2

# Set permissions
chmod 755 /var/www/apps/detoxnearme
chmod 755 /var/www/apps/edge-nextjs
chmod 755 /var/www/apps/forge-nextjs
chmod 755 /var/run/pm2
chmod 755 /var/log/pm2

echo "Application directories created with appuser ownership"
echo ""
echo "✓ Directory Structure Created:"
ls -la /var/www/apps/
echo ""
echo "✓ PM2 Directories:"
ls -la /var/run/pm2 2>/dev/null || echo "  (will be created when PM2 starts)"
echo ""
echo "✓ appuser Account:"
id appuser

verify_checkpoint "Application Directories - Verify structure and ownership (appuser:appuser)"
echo ""
echo "⚠️  IMPORTANT: Node.js/NVM installation"
echo "   NVM and Node.js should be installed as appuser (non-root), NOT as root."
echo "   Follow the 12-step guide in docs/SECURE-NON-ROOT-DEPLOYMENT.md"
echo "   Step 3: Install Node.js for appuser"

# 17. Install and Configure NGINX (Reverse Proxy)
print_section "Installing and Configuring NGINX"

# Install NGINX if not already installed
if ! command -v nginx &> /dev/null; then
    echo "Installing NGINX..."
    apt install -y nginx
else
    echo "NGINX is already installed."
fi

# Create necessary directories for NGINX configuration
echo "Creating NGINX configuration directories..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/conf.d
mkdir -p /var/www/html
mkdir -p /etc/ssl/certs
mkdir -p /etc/ssl/private

# Set proper permissions
chmod 755 /var/www/html
chmod 700 /etc/ssl/private

# Test NGINX syntax
echo "Testing NGINX configuration..."
if nginx -t; then
    echo "NGINX configuration is valid"
else
    echo "NGINX configuration has errors. Please review."
    exit 1
fi

# Enable and start NGINX
systemctl enable nginx
systemctl start nginx

# Update UFW to allow HTTP and HTTPS (already done in section 6, but verify)
echo "Verifying UFW rules for NGINX..."
ufw allow 80/tcp
ufw allow 443/tcp
echo "UFW firewall configured for NGINX (HTTP/HTTPS)"

# Explicitly deny app ports (defense in depth)
echo "Adding firewall rules to deny direct app port access..."
ufw deny 3000/tcp
ufw deny 3001/tcp
ufw deny 3002/tcp
ufw reload

echo "NGINX installed and configured successfully"
echo "Configuration directory: /etc/nginx"
echo "Sites available: /etc/nginx/sites-available"
echo "Sites enabled: /etc/nginx/sites-enabled"
echo ""
echo "✓ NGINX Status:"
systemctl status nginx | grep "Active:" || echo "Status check"
nginx -v

verify_checkpoint "NGINX Installation - Verify web server is running"
echo ""
echo "⚠️  IMPORTANT: NGINX configuration for apps"
echo "   Site configs should proxy to Unix sockets (not TCP ports)."
echo "   Use the config in: conf/node-steelgem/NGINX-UNIX-SOCKET.conf"
echo "   Deploy to: /etc/nginx/conf.d/nextjs-apps.conf"

# 18. Application Deployment Instructions
print_section "Application Deployment (Non-Root)"

echo "⚠️  SECURITY NOTICE: Applications run as non-root appuser, NOT as root"
echo ""
echo "For secure deployment of Node.js applications:"
echo ""
echo "1. READ: docs/SECURE-NON-ROOT-DEPLOYMENT.md"
echo "   Complete 12-step deployment guide (non-root, Unix sockets)"
echo ""
echo "2. COPY CONFIGURATION:"
echo "   sudo cp conf/node-steelgem/ecosystem.config.secure.js /home/appuser/ecosystem.config.js"
echo "   sudo chown appuser:appuser /home/appuser/ecosystem.config.js"
echo ""
echo "3. DEPLOY NGINX CONFIG:"
echo "   sudo cp conf/node-steelgem/NGINX-UNIX-SOCKET.conf /etc/nginx/conf.d/nextjs-apps.conf"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "4. INSTALL NODE.JS AS APPUSER:"
echo "   sudo -u appuser bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'"
echo "   sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && nvm install v20.19.5'"
echo ""
echo "5. START PM2 AS APPUSER:"
echo "   sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && pm2 start /home/appuser/ecosystem.config.js'"
echo ""
echo "Key Security Features:"
echo "  ✓ Apps run as appuser (non-root)"
echo "  ✓ Unix sockets, not TCP ports (no network exposure)"
echo "  ✓ RCE contained to appuser context"
echo "  ✓ UFW denies ports 3000-3002 (defense in depth)"
echo "  ✓ NGINX proxies via Unix socket (file permissions)"
echo ""
echo "Security Comparison:"
echo "  See: docs/SECURITY-ROOT-VS-NONROOT.md"
echo "  See: docs/QUICK-REFERENCE-SECURITY.md"

print_section "VPS Hardening Complete"

# Summary
echo "✓ System Hardening Completed:"
echo "  ✓ UFW firewall configured (22/80/443 allowed, 3000-3002 denied)"
echo "  ✓ SSH hardened (no root login, key-only auth)"
echo "  ✓ Fail2Ban intrusion detection enabled"
echo "  ✓ Automatic security updates configured"
echo "  ✓ OSSEC monitoring installed"
echo "  ✓ Kopia backups to Backblaze B2 scheduled"
echo "  ✓ Slack notifications configured"
echo "  ✓ NGINX installed (reverse proxy)"
echo "  ✓ appuser created (non-root app deployment user)"
echo ""

# Final security verification
print_section "Final Security Verification"
echo ""
echo "🔐 SSH Configuration:"
grep "^PermitRootLogin" /etc/ssh/sshd_config
grep "^PasswordAuthentication" /etc/ssh/sshd_config
grep "^PubkeyAuthentication" /etc/ssh/sshd_config
echo ""
echo "🔐 SSH Key Check:"
if [ -s "$ubuntu_authorized_keys" ]; then
    echo "  ✓ SSH key present for ${SUDO_USER} ($ubuntu_authorized_keys)"
else
    echo "  ✗ No SSH key found for ${SUDO_USER} ($ubuntu_authorized_keys)"
fi
echo ""

echo "🔐 UFW Firewall:"
ufw status verbose | head -15
echo ""

echo "🔐 Fail2Ban Protection:"
systemctl is-active fail2ban && echo "  ✓ Fail2Ban is RUNNING" || echo "  ✗ Fail2Ban WARNING"
echo ""

echo "🔐 Web Server:"
systemctl is-active nginx && echo "  ✓ NGINX is RUNNING" || echo "  ✗ NGINX WARNING"
echo ""

echo "🔐 Directory Ownership:"
echo "  App user:"
id appuser
echo ""
echo "  Application directories:"
ls -ld /var/www/apps/* 2>/dev/null | awk '{print "    "$NF": "$1" ("$3":"$4")"}'
echo ""

# Verification checkpoint
verify_checkpoint "Final Security Review - Verify all security measures are in place"

echo ""
echo "⚠️  Next Steps - Application Deployment (Non-Root):"
echo "  1. Read: docs/SECURE-NON-ROOT-DEPLOYMENT.md"
echo "     (Complete 12-step guide for secure app deployment)"
echo ""
echo "  2. Install Node.js as appuser:"
echo "     sudo -u appuser bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'"
echo ""
echo "  3. Deploy apps using ecosystem.config.secure.js:"
echo "     conf/node-steelgem/ecosystem.config.secure.js"
echo ""
echo "  4. Configure NGINX to proxy Unix sockets:"
echo "     conf/node-steelgem/NGINX-UNIX-SOCKET.conf"
echo ""

echo "📚 Security Documentation:"
echo "  • SECURE-NON-ROOT-DEPLOYMENT.md  - 12-step deployment guide"
echo "  • SECURITY-ROOT-VS-NONROOT.md    - Detailed security analysis"
echo "  • QUICK-REFERENCE-SECURITY.md    - Visual security guide"
echo "  • ecosystem.config.secure.js     - PM2 config (3 apps, Unix sockets)"
echo "  • NGINX-UNIX-SOCKET.conf         - Reverse proxy config"
echo ""

echo "🔐 Security Model:"
echo "  ✓ Apps run as appuser (non-root)"
echo "  ✓ Unix sockets only (zero TCP port exposure)"
echo "  ✓ RCE contained to appuser context"
echo "  ✓ UFW denies 3000-3002"
echo "  ✓ NGINX proxies via socket (file permissions)"
echo ""

echo "***"
echo "Enable ESM Apps to receive additional future security updates."
echo "See https://ubuntu.com/esm or run: sudo pro status"
echo "***"
echo ""
echo "Please review the changes and reboot your system for all changes to take effect."
