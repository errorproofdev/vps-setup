<!-- markdownlint-disable MD022 MD031 MD032 MD046 -->

# Secure Deployment Guide: 3 Next.js Apps on VPS (Non-Root)

**Status**: Production-Ready
**Updated**: February 26, 2026
**Security Model**: Non-root appuser + Unix sockets + UFW hardening

---

## 🔐 Security Model Overview

```
INSECURE (Don't Do This):
┌─────────────────────────────────────────────────────┐
│ SSH as root                                         │
│ └─ NVM in /root/.nvm                               │
│ └─ PM2 runs as root (systemd service)              │
│    ├─ detoxnearme:3000 (TCP - exposed)             │
│    ├─ edge:3001 (TCP - exposed)                    │
│    └─ forge:3002 (TCP - exposed)                   │
│       If RCE → attacker gets ROOT ACCESS          │
└─────────────────────────────────────────────────────┘

SECURE (This Guide):
┌─────────────────────────────────────────────────────┐
│ SSH as ubuntu/deployer (with public key only)      │
│ └─ Sudo for privileged operations                  │
│    └─ App deployment as appuser (non-root)         │
│       └─ NVM in /home/appuser/.nvm                 │
│       └─ PM2 runs as appuser (not root)            │
│          ├─ detoxnearme:localhost:3000 (TCP)       │
│          ├─ edge:localhost:3001 (TCP)              │
│          └─ forge:localhost:3002 (TCP)             │
│             If RCE → attacker gets appuser context │
│             (no /bin/bash, no sudo, limited tools) │
│                                                    │
│ NGINX (Reverse Proxy, Public Facing):              │
│  ├─ /var/run/pm2/detoxnearme.sock → :3000        │
│  ├─ /var/run/pm2/edge-treatment.sock → :3001     │
│  └─ /var/run/pm2/forge-recovery.sock → :3002     │
│                                                    │
│ UFW (Firewall):                                    │
│  ✓ Port 22 (SSH) - limited to public key auth     │
│  ✓ Port 80 (HTTP) - NGINX only                    │
│  ✓ Port 443 (HTTPS) - NGINX only                  │
│  ✗ Ports 3000-3002 - CLOSED (localhost-only)      │
└─────────────────────────────────────────────────────┘
```

---

## ⚀ Prerequisites

- Ubuntu 24.04 LTS VPS with sudo access via non-root user
- SSH key-based authentication (no password)
- Deployed SSL certificates in `/etc/ssl/{app-name}/`
- Application source code cloned to `/var/www/apps/{appname}`

---

## 🚀 Deployment Steps (Non-Root)

### Step 1: Create Dedicated Non-Root App User

```bash
# SSH to VPS as non-root user (e.g., ubuntu)
ssh ubuntu@node-steelgem

# Create appuser with no login shell (security best practice)
sudo useradd -r -m -s /usr/sbin/nologin appuser

# Verify creation
sudo id appuser
# Output should show: uid=xxx(appuser) gid=xxx(appuser) groups=xxx(appuser)

# Check home directory
ls -la /home/appuser
```

### Step 2: Create Directory Structure with Proper Ownership

```bash
# Create app deployment directories
sudo mkdir -p /var/www/apps/{detoxnearme,edge-nextjs,forge-nextjs}

# Create PM2 socket directory
sudo mkdir -p /var/run/pm2

# Create PM2 logging directory
sudo mkdir -p /var/log/pm2

# Set ownership to appuser
sudo chown -R appuser:appuser /var/www/apps
sudo chown appuser:appuser /var/run/pm2
sudo chown appuser:appuser /var/log/pm2

# Set permissions
sudo chmod 755 /var/www/apps/*
sudo chmod 755 /var/run/pm2
sudo chmod 755 /var/log/pm2

# Verify
ls -la /var/www/apps/
ls -la /var/run/pm2
```

### Step 3: Install Node.js (NVM) for appuser

```bash
# Switch to appuser (use bash explicitly since appuser has nologin shell)
sudo -u appuser bash

# Verify you're appuser
whoami  # Should output: appuser

# Install NVM (as appuser, installs to /home/appuser/.nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell configuration
source ~/.nvm/nvm.sh

# Install Node.js v20.19.5
nvm install v20.19.5
nvm alias default v20.19.5
nvm use v20.19.5

# Verify
node --version  # Should output: v20.19.5
npm --version

# Install PM2 globally
npm install -g pm2

# Verify PM2
pm2 --version

# Exit appuser bash shell and set up permanent NVM sourcing
exit

# Update appuser's .bashrc to auto-source NVM on every shell
sudo -u appuser bash -c 'cat >> /home/appuser/.bashrc << EOF

# NVM setup
export NVM_DIR="/home/appuser/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF'

# Verify it auto-loads
sudo -u appuser bash -c 'node --version'
```

### Step 4: Deploy Application Source Code

```bash
# As ubuntu (non-root) user, copy application code
# Option A: From local machine (if you have bastion access)
scp -r ~/projects/detoxnearme ubuntu@node-steelgem:/tmp/
scp -r ~/projects/edge-nextjs ubuntu@node-steelgem:/tmp/
scp -r ~/projects/forge-nextjs ubuntu@node-steelgem:/tmp/

# Option B: Use git (if repositories are private)
sudo -u appuser bash -c '
  cd /var/www/apps/detoxnearme
  git clone https://github.com/your-org/detoxnearme.git .
  npm ci --production
  npm run build
'

# Option C: Deploy from build archive (pre‑built bundle)
# copy the tarball up and extract as appuser; useful for CI/CD or
# when the build process cannot run on the VPS.

# example for Forge Recovery; repeat for other apps by changing names
scp conf/node-steelgem/forge-nextjs/build-archive.tar.gz ubuntu@node-steelgem:/tmp/

sudo -u appuser bash -c '
  mkdir -p /var/www/apps/forge-nextjs
  cd /var/www/apps/forge-nextjs
  tar xzf /tmp/build-archive.tar.gz
  # if dependencies not bundled, install them
  npm ci --production || true
'

# verify unpack
echo "Contents of /var/www/apps/forge-nextjs:" && ls -la /var/www/apps/forge-nextjs

# Verify app installation
ls -la /var/www/apps/detoxnearme/package.json
```

### Step 5: Deploy Secure Ecosystem Configuration

```bash
# Copy the secure ecosystem config to appuser's home
sudo cp ecosystem.config.secure.js /home/appuser/ecosystem.config.js

# Set correct ownership and permissions
sudo chown appuser:appuser /home/appuser/ecosystem.config.js
sudo chmod 644 /home/appuser/ecosystem.config.js

# Verify
sudo -u appuser cat /home/appuser/ecosystem.config.js | head -20
```

### Step 6: Create .env Files for Each App

**IMPORTANT**: Next.js requires `PORT` to be a numeric port, not a socket path. NGINX will handle the Unix socket binding and proxy to these TCP ports.

```bash
# DetoxNearMe environment variables (TCP port 3000)
sudo bash -c 'cat > /var/www/apps/detoxnearme/.env.local << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://detoxnearme_user:SECURE_PASSWORD@sql-steelgem:5432/detoxnearme
NEXT_PUBLIC_API_URL=https://cms.detoxnearme.com
EOF'

sudo chown appuser:appuser /var/www/apps/detoxnearme/.env.local
sudo chmod 600 /var/www/apps/detoxnearme/.env.local

# Edge Treatment environment variables (TCP port 3001)
sudo bash -c 'cat > /var/www/apps/edge-nextjs/.env.local << EOF
NODE_ENV=production
PORT=3001
CONTENTFUL_SPACE_ID=your_space_id
CONTENTFUL_ACCESS_TOKEN=your_access_token
EOF'

sudo chown appuser:appuser /var/www/apps/edge-nextjs/.env.local
sudo chmod 600 /var/www/apps/edge-nextjs/.env.local

# Forge Recovery environment variables (TCP port 3002)
sudo bash -c 'cat > /var/www/apps/forge-nextjs/.env.local << EOF
NODE_ENV=production
PORT=3002
CONTENTFUL_SPACE_ID=your_space_id
CONTENTFUL_ACCESS_TOKEN=your_access_token
EOF'

sudo chown appuser:appuser /var/www/apps/forge-nextjs/.env.local
sudo chmod 600 /var/www/apps/forge-nextjs/.env.local
```

**Network Security Model**:

- Apps listen on **localhost-only TCP ports** (3000, 3001, 3002)
- Not accessible from outside the VPS (UFW blocks these ports)
- NGINX proxies requests from Unix sockets to these TCP ports
- End result: Public access via HTTPS only, no raw app access

### Step 7: Start PM2 as appuser

```bash
# Start all apps from ecosystem config (as appuser)
# Apps will listen on localhost TCP ports (3000, 3001, 3002)
sudo -u appuser bash -c 'source ~/.nvm/nvm.sh && pm2 start /home/appuser/ecosystem.config.js'

# Verify processes started
sudo -u appuser pm2 list

# Check that apps are listening on TCP ports (not sockets)
netstat -tlnp | grep node
# Should show:
# tcp 0 0 127.0.0.1:3000 0.0.0.0:* LISTEN
# tcp 0 0 127.0.0.1:3001 0.0.0.0:* LISTEN
# tcp 0 0 127.0.0.1:3002 0.0.0.0:* LISTEN
```

**Architecture Note**:

- Apps listen on `localhost-only TCP ports` (security: not externally accessible)
- NGINX will bind to Unix sockets and proxy requests to these TCP ports
- External clients only see HTTPS traffic through NGINX sockets
- This provides defense-in-depth security layering

### Step 8: Configure PM2 Autostart (Systemd)

```bash
# Save PM2 process list for appuser
sudo -u appuser pm2 save

# Install PM2 as systemd service for appuser
sudo -u appuser pm2 startup systemd -u appuser --hp /home/appuser

# This will output a command like:
# [PM2] Init system you are using is: systemd
# [PM2] To setup the Startup Script, copy/paste this command:
# sudo env PATH=$PATH:/home/appuser/.nvm/versions/node/v20.19.5/bin \
#   /home/appuser/.nvm/versions/node/v20.19.5/lib/node_modules/pm2/bin/pm2 startup systemd -u appuser --hp /home/appuser

# The command will be auto-executed. Verify:
sudo systemctl status pm2-appuser

# Enable it to start on boot
sudo systemctl enable pm2-appuser
```

### Step 9: Harden UFW Firewall

```bash
# Check current UFW status
sudo ufw status

# Default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (port 22) - restrict to specific IP if possible
sudo ufw allow 22/tcp
# Or restrict to specific IP:
# sudo ufw allow from 203.0.113.0/24 to any port 22 proto tcp

# Allow HTTP (port 80)
sudo ufw allow 80/tcp

# Allow HTTPS (port 443)
sudo ufw allow 443/tcp

# CRITICAL: Do NOT allow ports 3000-3002 (apps use Unix sockets)
# Verify these are NOT allowed:
sudo ufw limit 3000/tcp  # WRONG - but let's deny
sudo ufw deny 3000/tcp
sudo ufw deny 3001/tcp
sudo ufw deny 3002/tcp

# Enable firewall
sudo ufw enable

# Reload rules
sudo ufw reload

# Verify configuration
sudo ufw status verbose

# Expected output:
# 22/tcp                     ALLOW       Anywhere
# 80/tcp                     ALLOW       Anywhere
# 443/tcp                    ALLOW       Anywhere
# 3000/tcp                   DENY        Anywhere
# 3001/tcp                   DENY        Anywhere
# 3002/tcp                   DENY        Anywhere
```

### Step 10: Configure NGINX to Proxy Unix Sockets

```bash
# Copy the Unix socket NGINX config
sudo cp NGINX-UNIX-SOCKET.conf /etc/nginx/conf.d/nextjs-apps.conf

# Test NGINX syntax
sudo nginx -t

# If valid, reload NGINX
sudo systemctl reload nginx

# Verify NGINX can access sockets
sudo -u www-data test -r /var/run/pm2/detoxnearme.sock && echo "✓ NGINX can read detoxnearme socket" || echo "✗ Permission denied"
```

### Step 11: Verify End-to-End Connectivity

```bash
# Test that apps are listening on TCP ports locally
netstat -tlnp | grep node
# Should show ports 3000, 3001, 3002 listening on 127.0.0.1 (localhost-only)

# Test that TCP ports are NOT externally accessible (blocked by UFW)
# From external machine, this should timeout or fail:
# nc -zv node-steelgem.com 3000
# Connection timed out

# Test HTTP → HTTPS redirect (via NGINX)
curl -I http://detoxnearme.com
# Should return: HTTP/1.1 301 Moved Permanently

# Test HTTPS (via NGINX → Unix socket → app)
curl -I https://detoxnearme.com
# Should return: HTTP/1.1 200 OK (or 308 if www redirect)

# View app logs to verify traffic is flowing
sudo -u appuser pm2 logs detoxnearme --lines 50

# Check NGINX sockets exist (created by NGINX config)
ls -la /var/run/pm2/*.sock 2>/dev/null || echo "Sockets will be created when NGINX proxies first request"
```

### Step 12: EVENTUALLY Disable Root SSH

```bash
# ONLY do this after verifying:
# 1. Non-root user can SSH with keys
# 2. Sudo works without password prompts (if needed)
# 3. All apps are running as appuser
# 4. UFW is properly configured

# Backup sshd_config first
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# Disable PermitRootLogin
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable password authentication
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Test syntax before restarting
sudo sshd -t

# Open a NEW SSH connection to verify it works BEFORE restarting
# (don't close existing connection)
# In another terminal:
# ssh ubuntu@node-steelgem "echo 'Success!'"

# If successful, restart SSH
sudo systemctl restart ssh

# Verify
ssh -v ubuntu@node-steelgem "pm2 list"  # Should work
ssh ubuntu@node-steelgem "sudo -l"      # Check installed sudoers rules
```

---

## 🔍 Verification Checklist

Run this verification script after deployment:

```bash
#!/bin/bash
echo "=== SECURITY VERIFICATION ==="

echo ""
echo "1. Check appuser exists and has no shell:"
sudo getent passwd appuser | grep -q "/usr/sbin/nologin" && echo "✓ appuser has no shell" || echo "✗ FAIL: appuser has shell"

echo ""
echo "2. Check PM2 runs as appuser:"
sudo -u appuser pm2 list | head -3

echo ""
echo "3. Check apps are listening on localhost TCP ports:"
netstat -tlnp 2>/dev/null | grep -E '3000|3001|3002' | wc -l
echo "Should show 3 lines (apps listening on 127.0.0.1:3000-3002)"

echo ""
echo "4. Check NGINX can read sockets:"
for socket in /var/run/pm2/*.sock; do
    sudo -u www-data test -r "$socket" && echo "✓ NGINX can read $socket" || echo "✗ Permission denied: $socket"
done

echo ""
echo "5. Check TCP ports are localhost-only (not externally accessible):"
netstat -tlnp 2>/dev/null | grep -E '127.0.0.1:(3000|3001|3002)' && echo "✓ Ports listening on localhost only" || echo "✗ Ports not found or exposed externally"

echo ""
echo "6. Check UFW is configured:"
sudo ufw status | grep -E "22|80|443|3000"

echo ""
echo "7. Check apps are responding:"
curl -I https://detoxnearme.com 2>/dev/null | head -1

echo ""
echo "8. Check root SSH is disabled (if configured):"
sudo grep -q "^PermitRootLogin no" /etc/ssh/sshd_config && echo "✓ Root SSH disabled" || echo "⚠ Root SSH still enabled"

echo ""
echo "=== END VERIFICATION ==="
```

---

## 📋 Monitoring & Maintenance

### View Process Status

```bash
# List all processes
sudo -u appuser pm2 list

# Monitor real-time (like top for PM2)
sudo -u appuser pm2 monit

# View logs for specific app
sudo -u appuser pm2 logs detoxnearme
sudo -u appuser pm2 logs edge
sudo -u appuser pm2 logs forge

# View last 50 error lines
sudo -u appuser pm2 logs detoxnearme --err --lines 50
```

### Restart/Reload without Downtime

```bash
# Restart single app
sudo -u appuser pm2 restart detoxnearme

# Reload (graceful, for cluster mode - not applicable here for fork mode)
sudo -u appuser pm2 reload detoxnearme

# Restart all apps
sudo -u appuser pm2 restart all

# Full restart (stop then start)
sudo -u appuser pm2 stop all
sudo -u appuser pm2 start /home/appuser/ecosystem.config.js
```

### Add More Apps

```bash
# Edit ecosystem config
sudo -u appuser nano /home/appuser/ecosystem.config.js

# Add new app block to the module.exports.apps array

# Restart PM2 with updated config
sudo -u appuser pm2 start /home/appuser/ecosystem.config.js
sudo -u appuser pm2 save
```

---

## 🚨 Troubleshooting

### Issue: "Permission denied" when accessing sockets

```bash
# Check socket ownership
ls -la /var/run/pm2/

# Should show appuser:appuser ownership
# If not, fix ownership:
sudo chown appuser:appuser /var/run/pm2/*.sock

# Check NGINX user can read:
sudo -u www-data test -r /var/run/pm2/detoxnearme.sock && echo "OK" || echo "FAIL"
```

### Issue: PM2 doesn't start on boot

```bash
# Verify systemd service
sudo systemctl status pm2-appuser

# Check service file
sudo cat /etc/systemd/system/pm2-appuser.service

# If missing, regenerate:
sudo -u appuser pm2 startup systemd -u appuser --hp /home/appuser

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable pm2-appuser
sudo systemctl start pm2-appuser
```

### Issue: NGINX returns 502 Bad Gateway

```bash
# Check if apps are running
sudo -u appuser pm2 list

# Check if sockets exist
ls -la /var/run/pm2/

# Check NGINX error log
sudo tail -50 /var/log/nginx/error.log

# Check app logs
sudo -u appuser pm2 logs appname --lines 100
```

---

## 🔐 Security Summary

| Aspect | Secure Approach | Why |
|--------|---|---|
| **Process User** | appuser (non-root) | RCE limited to appuser context |
| **Exposed Ports** | Only 22/80/443 | TCP app ports completely closed |
| **App Access** | Unix sockets | File-based permissions, no network exposure |
| **SSH Auth** | Public keys only | No password-based attacks |
| **Root Access** | Minimal (disabled) | False positive of root compromise |
| **Process Isolation** | Fork mode (single instances) | Simple, predictable, low overhead |
| **Logging** | Centralized to /var/log/pm2 | Audit trail for security analysis |

---

## 📚 References

- [NVM Documentation](https://github.com/nvm-sh/nvm)
- [PM2 Documentation](https://pm2.keymetrics.io)
- [NGINX Unix Socket Proxying](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)
- [Ubuntu UFW Firewall](https://help.ubuntu.com/community/UFW)
- [SSH Security Best Practices](https://stribika.github.io/2015/01/04/safe-ssh.html)
