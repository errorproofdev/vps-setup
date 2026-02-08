# Node-Steelgem Deployment Implementation Plan

**Server**: node-steelgem
**Target**: 3 NextJS Applications (Mixed Architectures)
**Status**: Ready for Implementation
**Created**: February 7, 2026

---

## 📋 Executive Summary

This plan outlines the complete deployment process for transforming the `node-steelgem` VPS into a production-ready NextJS hosting server. The implementation covers:

1. **DetoxNearMe** - Pages Router application (port 3000)
2. **Edge Treatment** - App Router v14-v15 application (port 3001)
3. **Forge Recovery** - App Router v14-v15 application (port 3002)

All three applications will share a single optimized NGINX instance with proper SSL/TLS configuration, resource pooling, and automated process management via PM2.

---

## 🎯 Implementation Goals

### Primary Objectives

- ✅ Deploy 3 NextJS applications on single VPS
- ✅ Support both Pages Router and App Router architectures
- ✅ Maximize 4-core CPU utilization (6 PM2 instances total)
- ✅ Implement zero-downtime deployment capabilities
- ✅ Ensure proper SSL/TLS configuration across all domains
- ✅ Establish monitoring and logging infrastructure

### Performance Targets

| Metric | Target | Method |
|--------|--------|--------|
| Concurrent Users | 1500-2000 | PM2 cluster mode (2 instances × 3 apps) |
| Request Latency | < 200ms | NGINX caching + keepalive |
| Uptime | 99.9% | PM2 auto-restart + health checks |
| Memory Usage | < 3GB total | 1GB limit per app |
| CPU Utilization | 60-80% avg | Optimized for 4 cores |

---

## 📦 Phase 1: Base System Setup

### Step 1.1: Transfer Setup Scripts

```bash
# From local machine (bastion)
scp -r scripts/ root@node-steelgem:/root/vps-setup/
scp -r conf/node-steelgem/ root@node-steelgem:/root/vps-setup/conf/
```

**Expected Outcome**: All deployment scripts available on target server

### Step 1.2: Run Base VPS Setup

```bash
# SSH into server
ssh root@node-steelgem

# Execute base setup
cd /root/vps-setup
chmod +x scripts/*.sh
./scripts/vps-setup.sh
```

**What This Does**:

- Updates system packages
- Installs NGINX
- Configures UFW firewall
- Hardens SSH security
- Sets up basic security policies

**Validation**:

```bash
# Verify services
systemctl status nginx
systemctl status ufw

# Check firewall
ufw status verbose
```

### Step 1.3: Install Node.js Environment

```bash
# Install NVM + Node.js LTS + PM2
./scripts/services.sh nvm
```

**What This Does**:

- Installs NVM (Node Version Manager) v0.39.0
- Installs Node.js LTS (v20.19.5)
- Installs npm, yarn, and PM2 globally
- Configures environment for all users

**Validation**:

```bash
# Verify installations
nvm --version
node --version  # Should be v20.19.5
pm2 --version
```

---

## 🔐 Phase 2: SSL/TLS Configuration

### Step 2.1: Install Cloudflare Origin Certificates

```bash
# Ensure certificates are in conf/ directory
ls -la conf/node-steelgem/*/ssl/

# Install SSL certificates
./scripts/services.sh nextjs-ssl
```

**Certificate Locations**:

- **Source**: `conf/node-steelgem/*/ssl/`
- **Destination**:
  - `/etc/ssl/certs/cloudflare-origin-fullchain.pem` (644)
  - `/etc/ssl/private/ssl-cert.key` (600)

**Validation**:

```bash
# Verify certificate
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -text -noout

# Check expiration
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -noout -dates

# Verify permissions
ls -la /etc/ssl/private/ssl-cert.key  # Should be 600
```

### Step 2.2: Optimize NGINX Global Configuration

```bash
# Apply NextJS-optimized NGINX config
./scripts/services.sh nextjs-nginx
```

**Optimizations Applied**:

- **Worker Processes**: `auto` (matches 4 CPU cores)
- **Worker Connections**: `16,384` per worker
- **Keepalive**: 64 connections to upstream
- **Gzip Compression**: Level 6
- **Cloudflare Real IP**: All ranges configured
- **Rate Limiting**: 30 connections per IP
- **SSL**: TLS 1.2/1.3 with strong ciphers

**Validation**:

```bash
# Test NGINX configuration
nginx -t

# Check worker processes
ps aux | grep nginx | grep worker

# Verify configuration
cat /etc/nginx/nginx.conf
```

---

## 📂 Phase 3: Application Directory Structure

### Step 3.1: Create Application Directories

```bash
# Create base directory
mkdir -p /var/www/apps

# Create application directories
mkdir -p /var/www/apps/detoxnearme
mkdir -p /var/www/apps/edge_nextjs
mkdir -p /var/www/apps/forge_nextjs

# Create log directory
mkdir -p /var/log/pm2

# Set permissions
chown -R root:root /var/www/apps
chmod -R 755 /var/www/apps
```

### Step 3.2: Transfer Application Code

**Option A: From Git Repository**

```bash
# Clone each application
cd /var/www/apps

git clone https://github.com/yourusername/detoxnearme.git detoxnearme
git clone https://github.com/yourusername/edge-nextjs.git edge_nextjs
git clone https://github.com/yourusername/forge-nextjs.git forge_nextjs
```

**Option B: From Source Server (edge-prod)**

```bash
# From local machine (bastion approach)
rsync -avz --exclude 'node_modules' --exclude '.next' \
  edge-prod:/home/ubuntu/current/detoxnearme/ \
  /tmp/detoxnearme/

rsync -avz --exclude 'node_modules' --exclude '.next' \
  edge-prod:/home/ubuntu/current/edge-nextjs/ \
  /tmp/edge_nextjs/

rsync -avz --exclude 'node_modules' --exclude '.next' \
  edge-prod:/home/ubuntu/current/forge-nextjs/ \
  /tmp/forge_nextjs/

# Transfer to node-steelgem
scp -r /tmp/detoxnearme/ root@node-steelgem:/var/www/apps/
scp -r /tmp/edge_nextjs/ root@node-steelgem:/var/www/apps/
scp -r /tmp/forge_nextjs/ root@node-steelgem:/var/www/apps/
```

### Step 3.3: Configure Environment Variables

```bash
# Copy environment templates
cp conf/node-steelgem/detoxnearme/.env.local.example \
   /var/www/apps/detoxnearme/.env.local

cp conf/node-steelgem/edge-nextjs/.env.local.example \
   /var/www/apps/edge_nextjs/.env.local

cp conf/node-steelgem/forge-nextjs/.env.local.example \
   /var/www/apps/forge_nextjs/.env.local

# Edit with actual credentials
nano /var/www/apps/detoxnearme/.env.local
nano /var/www/apps/edge_nextjs/.env.local
nano /var/www/apps/forge_nextjs/.env.local

# Secure permissions
chmod 600 /var/www/apps/*/.env.local
```

**Critical Environment Variables**:

#### DetoxNearMe

```env
DATABASE_URL="postgresql://user:pass@sql-steelgem:5432/detoxnearme"
NEXT_PUBLIC_API_URL="https://cms.detoxnearme.com"
NODE_ENV="production"
```

#### Edge Treatment

```env
CONTENTFUL_SPACE_ID="edge_space_id"
CONTENTFUL_ACCESS_TOKEN="edge_token"
NODE_ENV="production"
```

#### Forge Recovery

```env
CONTENTFUL_SPACE_ID="forge_space_id"
CONTENTFUL_ACCESS_TOKEN="forge_token"
NODE_ENV="production"
```

### Step 3.4: Copy Node Version Files

```bash
# Ensure .nvmrc files are present
cp conf/node-steelgem/detoxnearme/.nvmrc /var/www/apps/detoxnearme/
cp conf/node-steelgem/edge-nextjs/.nvmrc /var/www/apps/edge_nextjs/
cp conf/node-steelgem/forge-nextjs/.nvmrc /var/www/apps/forge_nextjs/
```

---

## 🏗️ Phase 4: Build Applications

### Step 4.1: Build DetoxNearMe (Pages Router)

```bash
cd /var/www/apps/detoxnearme

# Load correct Node version
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use

# Install dependencies
npm ci --production

# Build application
npm run build

# Verify build
ls -la .next/
```

**Expected Output**:

```
.next/
├── static/
├── server/
├── BUILD_ID
└── cache/
```

### Step 4.2: Build Edge Treatment (App Router)

```bash
cd /var/www/apps/edge_nextjs

# Load Node version
nvm use

# Install dependencies
npm ci --production

# Build application
npm run build

# Verify build
ls -la .next/
```

### Step 4.3: Build Forge Recovery (App Router)

```bash
cd /var/www/apps/forge_nextjs

# Load Node version
nvm use

# Install dependencies
npm ci --production

# Build application
npm run build

# Verify build
ls -la .next/
```

**Build Validation Checklist**:

- [ ] `.next/BUILD_ID` file exists
- [ ] `.next/static/` directory contains assets
- [ ] `.next/server/` contains server-side code
- [ ] No build errors in output
- [ ] `package-lock.json` or `yarn.lock` present

---

## 🚀 Phase 5: PM2 Process Management

### Step 5.1: Deploy PM2 Ecosystem Configuration

```bash
# Copy ecosystem file
cp conf/node-steelgem/ecosystem.config.js /var/www/apps/

# Verify configuration
cat /var/www/apps/ecosystem.config.js
```

### Step 5.2: Start All Applications

```bash
cd /var/www/apps

# Start all processes with ecosystem file
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Enable PM2 startup script
pm2 startup systemd
# Follow the printed command to complete setup
```

### Step 5.3: Verify PM2 Processes

```bash
# List all processes
pm2 list

# Expected output:
# ┌────┬─────────────────┬─────────┬─────────┬──────────┬────────┬──────┬───────────┬──────────┬──────────┐
# │ id │ name            │ mode    │ pid     │ uptime   │ ↺      │ status│ cpu      │ mem      │          │
# ├────┼─────────────────┼─────────┼─────────┼──────────┼────────┼───────┼──────────┼──────────┼──────────┤
# │ 0  │ detoxnearme     │ cluster │ 12345   │ 5s       │ 0      │ online│ 0%       │ 150.0mb  │          │
# │ 1  │ detoxnearme     │ cluster │ 12346   │ 5s       │ 0      │ online│ 0%       │ 145.0mb  │          │
# │ 2  │ edge_nextjs     │ cluster │ 12347   │ 5s       │ 0      │ online│ 0%       │ 140.0mb  │          │
# │ 3  │ edge_nextjs     │ cluster │ 12348   │ 5s       │ 0      │ online│ 0%       │ 135.0mb  │          │
# │ 4  │ forge_nextjs    │ cluster │ 12349   │ 5s       │ 0      │ online│ 0%       │ 138.0mb  │          │
# │ 5  │ forge_nextjs    │ cluster │ 12350   │ 5s       │ 0      │ online│ 0%       │ 133.0mb  │          │
# └────┴─────────────────┴─────────┴─────────┴──────────┴────────┴───────┴──────────┴──────────┴──────────┘

# Check individual process details
pm2 describe detoxnearme
pm2 describe edge_nextjs
pm2 describe forge_nextjs

# Monitor logs
pm2 logs --lines 50
```

### Step 5.4: Test Local Endpoints

```bash
# Test each application locally
curl -I http://localhost:3000  # DetoxNearMe
curl -I http://localhost:3001  # Edge Treatment
curl -I http://localhost:3002  # Forge Recovery

# Expected: HTTP/1.1 200 OK or HTTP/1.1 301 (redirect)
```

---

## 🌐 Phase 6: NGINX Site Configuration

### Step 6.1: Deploy NGINX Configurations

```bash
# Copy site configurations
cp conf/node-steelgem/detoxnearme/nginx/detoxnearme.conf \
   /etc/nginx/sites-available/detoxnearme

cp conf/node-steelgem/edge-nextjs/nginx/theedgetreatment.com.conf \
   /etc/nginx/sites-available/edge_nextjs

cp conf/node-steelgem/forge-nextjs/nginx/theforgerecovery.com.conf \
   /etc/nginx/sites-available/forge_nextjs
```

### Step 6.2: Enable Sites

```bash
# Create symbolic links
ln -sf /etc/nginx/sites-available/detoxnearme \
       /etc/nginx/sites-enabled/detoxnearme

ln -sf /etc/nginx/sites-available/edge_nextjs \
       /etc/nginx/sites-enabled/edge_nextjs

ln -sf /etc/nginx/sites-available/forge_nextjs \
       /etc/nginx/sites-enabled/forge_nextjs

# Remove default site if present
rm -f /etc/nginx/sites-enabled/default
```

### Step 6.3: Test and Reload NGINX

```bash
# Test configuration syntax
nginx -t

# Expected output:
# nginx: configuration file /etc/nginx/nginx.conf test is successful

# Reload NGINX
systemctl reload nginx

# Verify NGINX is running
systemctl status nginx
```

---

## 🧪 Phase 7: Testing and Validation

### Step 7.1: Local Health Checks

```bash
# Test HTTP → HTTPS redirects
curl -I http://detoxnearme.com
curl -I http://theedgetreatment.com
curl -I http://theforgerecovery.com

# Expected: 301 Moved Permanently to HTTPS

# Test root → www redirects
curl -I https://detoxnearme.com
curl -I https://theedgetreatment.com
curl -I https://theforgerecovery.com

# Expected: 301 Moved Permanently to www
```

### Step 7.2: SSL/TLS Validation

```bash
# Test SSL connections
openssl s_client -connect www.detoxnearme.com:443 -servername www.detoxnearme.com < /dev/null
openssl s_client -connect www.theedgetreatment.com:443 -servername www.theedgetreatment.com < /dev/null
openssl s_client -connect www.theforgerecovery.com:443 -servername www.theforgerecovery.com < /dev/null

# Check for:
# - Verify return code: 0 (ok)
# - SSL handshake successful
# - Certificate chain valid
```

### Step 7.3: Application Functionality Tests

```bash
# Test main pages load correctly
curl -sL https://www.detoxnearme.com/ | grep -i "<title>"
curl -sL https://www.theedgetreatment.com/ | grep -i "<title>"
curl -sL https://www.theforgerecovery.com/ | grep -i "<title>"

# Test API endpoints (if applicable)
curl -I https://www.detoxnearme.com/api/health
```

### Step 7.4: Performance Benchmarking

```bash
# Install Apache Bench (if not present)
apt-get install -y apache2-utils

# Run performance tests
ab -n 1000 -c 10 https://www.detoxnearme.com/
ab -n 1000 -c 10 https://www.theedgetreatment.com/
ab -n 1000 -c 10 https://www.theforgerecovery.com/

# Review metrics:
# - Requests per second
# - Time per request
# - Failed requests (should be 0)
```

### Step 7.5: Resource Monitoring

```bash
# Monitor PM2 processes
pm2 monit

# Check CPU and memory usage
htop

# View NGINX connections
netstat -an | grep :443 | wc -l

# Check disk space
df -h

# Review logs for errors
pm2 logs --err --lines 100
tail -100 /var/log/nginx/error.log
```

---

## 🔄 Phase 8: DNS Configuration

### Step 8.1: Update DNS Records

**Before DNS changes**, verify the server is fully functional with host file entries or direct IP access.

**DNS Changes Required**:

```
# A Records (or update existing)
detoxnearme.com           A     <node-steelgem-ip>
www.detoxnearme.com       A     <node-steelgem-ip>

theedgetreatment.com      A     <node-steelgem-ip>
www.theedgetreatment.com  A     <node-steelgem-ip>

theforgerecovery.com      A     <node-steelgem-ip>
www.theforgerecovery.com  A     <node-steelgem-ip>
```

**Cloudflare Settings**:

- **Proxy Status**: ☁️ Proxied (Orange Cloud)
- **SSL/TLS Mode**: Full (strict)
- **Always Use HTTPS**: ✅ Enabled
- **Auto Minify**: ✅ Enabled (HTML, CSS, JS)
- **Brotli Compression**: ✅ Enabled

### Step 8.2: Verify DNS Propagation

```bash
# Check DNS resolution
dig +short detoxnearme.com
dig +short www.detoxnearme.com

dig +short theedgetreatment.com
dig +short www.theedgetreatment.com

dig +short theforgerecovery.com
dig +short www.theforgerecovery.com

# Should return node-steelgem IP (or Cloudflare IP if proxied)
```

### Step 8.3: Test From External Network

```bash
# From your local machine (not the server)
curl -I https://www.detoxnearme.com
curl -I https://www.theedgetreatment.com
curl -I https://www.theforgerecovery.com

# All should return 200 OK
```

---

## 📊 Phase 9: Monitoring and Logging Setup

### Step 9.1: Configure Log Rotation

```bash
# Create PM2 log rotation config
cat > /etc/logrotate.d/pm2 << 'EOF'
/var/log/pm2/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Test log rotation
logrotate -f /etc/logrotate.d/pm2
```

### Step 9.2: Setup System Monitoring

```bash
# Install htop (if not present)
apt-get install -y htop

# Install netstat tools
apt-get install -y net-tools

# Create monitoring script
cat > /root/monitor-node-steelgem.sh << 'EOF'
#!/bin/bash
echo "=== Node-Steelgem System Status ==="
echo "Date: $(date)"
echo ""
echo "=== PM2 Processes ==="
pm2 list
echo ""
echo "=== Memory Usage ==="
free -h
echo ""
echo "=== Disk Usage ==="
df -h /var/www/apps
echo ""
echo "=== NGINX Connections ==="
netstat -an | grep -E ':(80|443)' | wc -l
echo ""
echo "=== Recent Errors (last 20) ==="
pm2 logs --err --lines 20 --nostream
EOF

chmod +x /root/monitor-node-steelgem.sh
```

### Step 9.3: Setup Automated Health Checks

```bash
# Create health check script
cat > /root/health-check.sh << 'EOF'
#!/bin/bash

URLS=(
    "https://www.detoxnearme.com"
    "https://www.theedgetreatment.com"
    "https://www.theforgerecovery.com"
)

for url in "${URLS[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$status" != "200" ]; then
        echo "$(date): ERROR - $url returned status $status" >> /var/log/health-check.log
        # Optional: Send alert (email, Slack, etc.)
    else
        echo "$(date): OK - $url" >> /var/log/health-check.log
    fi
done
EOF

chmod +x /root/health-check.sh

# Add to crontab (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/health-check.sh") | crontab -
```

---

## 🔧 Phase 10: Optimization and Tuning

### Step 10.1: PM2 Cluster Optimization

```bash
# Monitor PM2 cluster performance
pm2 monit

# If needed, adjust instance count per application:
pm2 scale detoxnearme 3    # Increase to 3 instances
pm2 scale edge_nextjs 2    # Keep at 2 instances
pm2 scale forge_nextjs 1   # Reduce to 1 instance

# Save new configuration
pm2 save
```

### Step 10.2: NGINX Performance Tuning

```bash
# Edit /etc/nginx/nginx.conf if needed
# Adjust worker_connections based on load

# Reload NGINX after changes
nginx -t && systemctl reload nginx
```

### Step 10.3: System Kernel Tuning

```bash
# Increase file descriptor limits
cat >> /etc/sysctl.conf << 'EOF'
fs.file-max = 100000
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
EOF

# Apply changes
sysctl -p
```

---

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] Base VPS setup completed (`vps-setup.sh`)
- [ ] NVM and Node.js installed (`services.sh nvm`)
- [ ] SSL certificates prepared and available
- [ ] Source code repositories accessible
- [ ] Database connection strings obtained (DetoxNearMe)
- [ ] Contentful credentials obtained (Edge + Forge)
- [ ] DNS access confirmed
- [ ] Firewall rules reviewed

### During Deployment

- [ ] Application directories created (`/var/www/apps/`)
- [ ] Source code transferred or cloned
- [ ] Environment variables configured (`.env.local`)
- [ ] Node version files present (`.nvmrc`)
- [ ] Dependencies installed (`npm ci`)
- [ ] Applications built successfully (`npm run build`)
- [ ] PM2 ecosystem file deployed
- [ ] All PM2 processes started and online
- [ ] NGINX site configurations deployed
- [ ] NGINX sites enabled (symlinks created)
- [ ] NGINX configuration tested (`nginx -t`)
- [ ] NGINX reloaded successfully

### Post-Deployment

- [ ] Local health checks passing (localhost:3000/3001/3002)
- [ ] SSL/TLS certificates valid
- [ ] HTTP → HTTPS redirects working
- [ ] Root → www redirects working
- [ ] DNS records updated
- [ ] External accessibility confirmed
- [ ] Performance benchmarks acceptable
- [ ] Log rotation configured
- [ ] Monitoring scripts deployed
- [ ] Health check cron job active
- [ ] PM2 startup script enabled
- [ ] Documentation updated
- [ ] Team notified of deployment

---

## 🚨 Rollback Plan

### If Deployment Fails

#### Immediate Steps

```bash
# 1. Stop new PM2 processes
pm2 stop all

# 2. Disable NGINX sites
rm /etc/nginx/sites-enabled/detoxnearme
rm /etc/nginx/sites-enabled/edge_nextjs
rm /etc/nginx/sites-enabled/forge_nextjs

# 3. Reload NGINX
systemctl reload nginx

# 4. Restore previous DNS (if changed)
# Update DNS records back to previous server
```

#### Restore Previous State

```bash
# If previous server is still running
# Update DNS to point back to edge-prod

# Investigate issues
pm2 logs --err --lines 100
tail -100 /var/log/nginx/error.log

# Fix issues and retry deployment
```

---

## 📈 Success Criteria

### Technical Metrics

- ✅ All 6 PM2 processes running (2 instances × 3 apps)
- ✅ All applications responding on correct ports
- ✅ HTTP → HTTPS redirects functional
- ✅ Root → www redirects functional
- ✅ SSL/TLS certificates valid
- ✅ Response times < 200ms
- ✅ Memory usage < 3GB total
- ✅ CPU utilization 60-80% under load
- ✅ No error logs at startup

### Functional Validation

- ✅ DetoxNearMe homepage loads correctly
- ✅ DetoxNearMe can query PostgreSQL database
- ✅ Edge Treatment homepage loads correctly
- ✅ Edge Treatment fetches content from Contentful
- ✅ Forge Recovery homepage loads correctly
- ✅ Forge Recovery fetches content from Contentful
- ✅ All static assets loading correctly
- ✅ Images optimized and loading fast

---

## 🛠️ Maintenance Procedures

### Daily Maintenance

```bash
# Run monitoring script
/root/monitor-node-steelgem.sh

# Check for errors
pm2 logs --err --lines 50 --nostream
```

### Weekly Maintenance

```bash
# Review resource usage
pm2 monit

# Check disk space
df -h

# Review NGINX logs
tail -1000 /var/log/nginx/access.log | less
```

### Monthly Maintenance

```bash
# System updates
apt update && apt upgrade -y

# Restart PM2 processes (during low-traffic period)
pm2 restart all

# Clear old logs
find /var/log/pm2 -name "*.log" -mtime +30 -delete

# Review and update dependencies
cd /var/www/apps/detoxnearme && npm audit
cd /var/www/apps/edge_nextjs && npm audit
cd /var/www/apps/forge_nextjs && npm audit
```

---

## 📚 Related Documentation

- **Setup Guide**: [NODE-STEELGEM-SETUP.md](./NODE-STEELGEM-SETUP.md)
- **Configuration**: [conf/node-steelgem/README.md](../conf/node-steelgem/README.md)
- **NextJS Deployment**: [NEXTJS-DEPLOYMENT.md](./NEXTJS-DEPLOYMENT.md)
- **NextJS Quick Start**: [NEXTJS-QUICKSTART.md](./NEXTJS-QUICKSTART.md)
- **Server Context**: [SERVER-CONTEXT.md](./SERVER-CONTEXT.md)
- **Dynamic SSH**: [DYNAMIC-SSH-GUIDE.md](./DYNAMIC-SSH-GUIDE.md)

---

## 🎯 Next Steps After Deployment

1. **Monitor for 24-48 hours** - Watch for errors, memory leaks, high CPU
2. **Performance tuning** - Adjust PM2 instances based on actual load
3. **Setup automated backups** - For application code and configurations
4. **Implement CI/CD** - Automate future deployments
5. **Setup alerting** - Email/Slack notifications for errors
6. **Document runbooks** - For common issues and resolutions
7. **Train team** - On monitoring and troubleshooting procedures

---

**Implementation Status**: ✅ Ready to Execute
**Estimated Time**: 2-3 hours (excluding DNS propagation)
**Risk Level**: Medium (new deployment, proper testing required)
**Reversibility**: High (old server can remain as fallback)

---

**Last Updated**: February 7, 2026
**Document Version**: 1.0
**Maintained By**: DevOps Team
