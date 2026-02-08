# DetoxNearMe PM2 Configuration Guide

**Application**: detoxnearme
**Domain**: detoxnearme.com
**Port**: 3001
**Architecture**: NextJS Pages Router
**Mode**: Fork (Single Instance - NOT cluster mode)
**Directory**: `/home/ubuntu/detoxnearme.com/gitlab/`
**Node Version**: v22.9.0

---

## 🎯 Process Overview

DetoxNearMe runs as a **single PM2 process in fork mode**.

**Why fork mode?**

- Single instance is sufficient for current traffic
- Simpler deployment and debugging
- Lower memory footprint
- No need for shared state management across instances

```
┌────┬──────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name         │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼──────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ detoxnearme  │ fork     │ 0    │ online    │ 0.5%     │ 180.0mb  │
└────┴──────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
```

---

## 🚀 PM2 Commands

### Start Application

```bash
# Standard start command (fork mode)
cd /home/ubuntu/detoxnearme.com/gitlab
pm2 start npm --name "detoxnearme" -- run start

# With explicit working directory
pm2 start npm --name "detoxnearme" --cwd /home/ubuntu/detoxnearme.com/gitlab -- run start
```

### Process Management

```bash
# View process status
pm2 list

# Detailed process information
pm2 describe detoxnearme

# Restart application
pm2 restart detoxnearme

# Reload application (graceful restart)
pm2 reload detoxnearme

# Stop application
pm2 stop detoxnearme

# Delete from PM2
pm2 delete detoxnearme

# Save PM2 configuration
pm2 save

# Setup PM2 to start on system boot
pm2 startup systemd
# Then run the command it outputs
```

### Logs Management

```bash
# View real-time logs
pm2 logs detoxnearme

# View last 100 lines
pm2 logs detoxnearme --lines 100

# View error logs only
pm2 logs detoxnearme --err

# View output logs only
pm2 logs detoxnearme --out

# Clear logs
pm2 flush detoxnearme

# Raw log files
tail -f /home/ubuntu/.pm2/logs/detoxnearme-error.log
tail -f /home/ubuntu/.pm2/logs/detoxnearme-out.log
```

### Monitoring

```bash
# Real-time monitoring dashboard
pm2 monit

# Process metrics
pm2 show detoxnearme
```

---

## 📊 Current Process Details

```bash
pm2 describe 0
```

### Process Information

```
┌───────────────────┬─────────────────────────────────────────────────┐
│ status            │ online                                          │
│ name              │ detoxnearme                                     │
│ namespace         │ default                                         │
│ version           │ 0.39.3                                          │
│ restarts          │ 0                                               │
│ uptime            │ 19D                                             │
│ script path       │ /home/ubuntu/.nvm/versions/node/v20.5.1/bin/npm │
│ script args       │ run start                                       │
│ error log path    │ /home/ubuntu/.pm2/logs/detoxnearme-error.log    │
│ out log path      │ /home/ubuntu/.pm2/logs/detoxnearme-out.log      │
│ pid path          │ /home/ubuntu/.pm2/pids/detoxnearme-0.pid        │
│ interpreter       │ node                                            │
│ interpreter args  │ N/A                                             │
│ script id         │ 0                                               │
│ exec cwd          │ /home/ubuntu/gitlab                             │
│ exec mode         │ fork_mode                                       │
│ node.js version   │ 20.5.1                                          │
│ node env          │ N/A                                             │
│ watch & reload    │ ✘                                               │
│ unstable restarts │ 0                                               │
│ created at        │ 2023-11-28T00:12:37.539Z                        │
└───────────────────┴─────────────────────────────────────────────────┘
```

### Performance Metrics

```
┌────────────────────────┬───────────┐
│ Used Heap Size         │ 18.81 MiB │
│ Heap Usage             │ 92.26 %   │
│ Heap Size              │ 20.39 MiB │
│ Event Loop Latency p95 │ 1.10 ms   │
│ Event Loop Latency     │ 0.42 ms   │
│ Active handles         │ 5         │
│ Active requests        │ 0         │
└────────────────────────┴───────────┘
```

---

## 🔄 Deployment Workflow

### Standard Deployment

```bash
# 1. Navigate to application directory
cd /home/ubuntu/detoxnearme.com/gitlab

# 2. Pull latest code (if using git)
git pull origin main

# 3. Install dependencies
npm ci --production

# 4. Build application
npm run build

# 5. Restart PM2 process
pm2 restart detoxnearme

# 6. Verify deployment
pm2 logs detoxnearme --lines 50
curl -I http://localhost:3000
```

### Quick Deployment Script

```bash
#!/bin/bash
# deploy-detoxnearme.sh

set -e

APP_DIR="/home/ubuntu/detoxnearme.com/gitlab"
APP_NAME="detoxnearme"

echo "=== Deploying DetoxNearMe ==="

cd "$APP_DIR"

echo "1. Pulling latest code..."
git pull origin main

echo "2. Installing dependencies..."
npm ci --production

echo "3. Building application..."
npm run build

echo "4. Restarting PM2 process..."
pm2 restart "$APP_NAME"

echo "5. Checking status..."
sleep 2
pm2 list | grep "$APP_NAME"

echo "=== Deployment Complete ==="
pm2 logs "$APP_NAME" --lines 20
```

---

## 📂 File Locations

### Application Files

```
/home/ubuntu/detoxnearme.com/gitlab/
├── .next/                  # NextJS build output
├── pages/                  # NextJS pages (Pages Router)
├── public/                 # Static assets
├── .env.local              # Environment variables
├── .nvmrc                  # Node version (20.5.1)
├── package.json
├── next.config.js
└── ...
```

### PM2 Files

```
/home/ubuntu/.pm2/
├── logs/
│   ├── detoxnearme-error.log
│   └── detoxnearme-out.log
├── pids/
│   └── detoxnearme-0.pid
└── dump.pm2                # Saved PM2 configuration
```

### Configuration Files

```
/etc/nginx/sites-available/detoxnearme.com.conf    # NGINX config
/etc/ssl/detoxnearme/cert.pem                      # SSL certificate
/etc/ssl/detoxnearme/key.pem                       # SSL private key
```

---

## 🔧 Environment Variables

Located at: `/home/ubuntu/detoxnearme.com/gitlab/.env.local`

```env
API_HOST=https://cms.detoxnearme.com
API_KEY=<your-strapi-api-key>
FORMSPREE_DETOX_API_KEY=<your-formspree-api-key>
FORMSPREE_DETOX_PROJECT_ID=<your-formspree-project-id>
GOOGLE_MAPS_API_KEY=<your-google-maps-api-key>
GOOGLE_MAPS_API_SECRET=<your-google-maps-api-secret>
URL_DOMAIN=https://detoxnearme.com
```

**Security**: Ensure `.env.local` has restricted permissions:

```bash
chmod 600 /home/ubuntu/detoxnearme.com/gitlab/.env.local
```

---

## 🐛 Troubleshooting

### Application Won't Start

```bash
# Check logs for errors
pm2 logs detoxnearme --err --lines 50

# Verify Node version
node --version
cat /home/ubuntu/detoxnearme.com/gitlab/.nvmrc

# Check if port 3000 is already in use
lsof -i :3000

# Try starting manually
cd /home/ubuntu/detoxnearme.com/gitlab
npm run start
```

### High Memory Usage

```bash
# Check current memory usage
pm2 describe detoxnearme | grep memory

# Restart process to clear memory
pm2 restart detoxnearme

# If problem persists, check for memory leaks
pm2 logs detoxnearme --lines 200 | grep -i "memory\|heap"
```

### Application Crashes

```bash
# Check restart count
pm2 list | grep detoxnearme

# View error logs
pm2 logs detoxnearme --err --lines 100

# Check system logs
journalctl -u pm2-ubuntu -n 50

# Ensure PM2 startup is configured
pm2 startup systemd
pm2 save
```

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000
ss -tlnp | grep 3000

# Kill the process
kill -9 <PID>

# Restart detoxnearme
pm2 restart detoxnearme
```

### Build Failures

```bash
# Check Node version matches .nvmrc
node --version
cat .nvmrc

# Clear Next.js cache
cd /home/ubuntu/detoxnearme.com/gitlab
rm -rf .next

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install

# Rebuild
npm run build
```

---

## 📊 Performance Monitoring

### Health Checks

```bash
# Test local endpoint
curl -I http://localhost:3000

# Test production endpoint
curl -I https://detoxnearme.com

# Check response time
time curl -s https://detoxnearme.com/ > /dev/null
```

### Resource Usage

```bash
# PM2 monitoring
pm2 monit

# System resources
htop

# Memory details
free -h

# Disk space
df -h /home/ubuntu
```

### Performance Metrics

```bash
# Event loop latency
pm2 describe detoxnearme | grep "Event Loop"

# Memory usage
pm2 describe detoxnearme | grep -E "Heap|Memory"

# Uptime and restarts
pm2 list | grep detoxnearme
```

---

## 🔐 Security Best Practices

### File Permissions

```bash
# Secure environment file
chmod 600 /home/ubuntu/detoxnearme.com/gitlab/.env.local
chown ubuntu:ubuntu /home/ubuntu/detoxnearme.com/gitlab/.env.local

# Secure SSL keys
chmod 644 /etc/ssl/detoxnearme/cert.pem
chmod 600 /etc/ssl/detoxnearme/key.pem
chown root:root /etc/ssl/detoxnearme/*.pem
```

### Regular Maintenance

```bash
# Update dependencies (careful with breaking changes)
cd /home/ubuntu/detoxnearme.com/gitlab
npm outdated
npm update

# Security audit
npm audit
npm audit fix

# Clear old logs (keep last 7 days)
find /home/ubuntu/.pm2/logs -name "*.log" -mtime +7 -delete
```

---

## 📝 PM2 Ecosystem File (Optional)

Create `/home/ubuntu/detoxnearme.com/ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'detoxnearme',
    cwd: '/home/ubuntu/detoxnearme.com/gitlab',
    script: 'npm',
    args: 'run start',
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '500M',
    autorestart: true,
    watch: false,
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/home/ubuntu/.pm2/logs/detoxnearme-error.log',
    out_file: '/home/ubuntu/.pm2/logs/detoxnearme-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true
  }]
};
```

**Start with ecosystem file:**

```bash
cd /home/ubuntu/detoxnearme.com
pm2 start ecosystem.config.js
pm2 save
```

---

## 🔗 Related Files

- **NGINX Config**: `/etc/nginx/sites-available/detoxnearme.com.conf`
- **SSL Certificate**: `/etc/ssl/detoxnearme/cert.pem`
- **SSL Key**: `/etc/ssl/detoxnearme/key.pem`
- **Environment**: `/home/ubuntu/detoxnearme.com/gitlab/.env.local`
- **Application**: `/home/ubuntu/detoxnearme.com/gitlab/`

---

## 📞 Quick Reference

```bash
# Start
pm2 start npm --name detoxnearme --cwd /home/ubuntu/detoxnearme.com/gitlab -- run start

# Status
pm2 list

# Logs
pm2 logs detoxnearme

# Restart
pm2 restart detoxnearme

# Stop
pm2 stop detoxnearme

# Monitor
pm2 monit

# Health Check
curl -I http://localhost:3000
```

---

**Last Updated**: February 8, 2026
**Process Mode**: Fork (Single Instance)
**Node Version**: 22.9.0
**Port**: 3001
**Status**: Production
