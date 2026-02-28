<!-- markdownlint-disable MD022 MD031 MD032 MD046 -->

               # Node-Steelgem Quick Reference Card

**Server**: node-steelgem | **OS**: Ubuntu 24.04 | **CPU**: 4 cores | **Role**: NextJS Hosting

---

## 🚀 Quick Commands

> **Security context:** all Node.js processes run as the non-root user
> `appuser`. They listen on localhost-only TCP ports; NGINX proxies external
> traffic over Unix sockets. Consult
> `docs/SECURE-NON-ROOT-DEPLOYMENT.md` for deployment and hardening steps.

### Check All Applications

```bash
pm2 list              # View all processes
pm2 monit             # Real-time monitoring
pm2 logs              # View all logs
pm2 logs --err        # Errors only
```

### Application Status

```bash
# Individual app status
pm2 describe detoxnearme
pm2 describe edge_nextjs
pm2 describe forge_nextjs

# Check ports
ss -tlnp | grep -E ':(3000|3001|3002)'

# Test local endpoints
curl -I http://localhost:3000  # DetoxNearMe
curl -I http://localhost:3001  # Edge Treatment
curl -I http://localhost:3002  # Forge Recovery
```

### Restart Applications

```bash
# Graceful restart (zero-downtime)
pm2 reload detoxnearme
pm2 reload edge_nextjs
pm2 reload forge_nextjs

# Restart all
pm2 reload all

# Hard restart (if needed)
pm2 restart detoxnearme
```

### NGINX Commands

```bash
# Test configuration
nginx -t

# Reload NGINX
systemctl reload nginx

# Check status
systemctl status nginx

# View error logs
tail -f /var/log/nginx/error.log
```

---

## 📊 Application Overview

| Application | Domain | Port | Architecture | PM2 Name |
|------------|--------|------|--------------|----------|
| DetoxNearMe | <www.detoxnearme.com> | 3000 | Pages Router | detoxnearme |
| Edge Treatment | <www.theedgetreatment.com> | 3001 | App Router v14-v15 | edge_nextjs |
| Forge Recovery | <www.theforgerecovery.com> | 3002 | App Router v14-v15 | forge_nextjs |

**Total PM2 Processes**: 6 (2 instances per app in cluster mode)

---

## 🔍 Troubleshooting Quick Fixes

### Application Won't Start

```bash
# Check logs for errors
pm2 logs <app_name> --err --lines 50

# Verify Node version
node --version
cat /var/www/apps/<app_name>/.nvmrc

# Check if port is in use
lsof -i :<port>

# Restart from ecosystem file
cd /var/www/apps
pm2 delete <app_name>
pm2 start ecosystem.config.js --only <app_name>
```

### 502 Bad Gateway (NGINX)

```bash
# Check if PM2 process is running
pm2 list

# Check application port
ss -tlnp | grep <port>

# View NGINX error logs
tail -50 /var/log/nginx/error.log

# Restart services
pm2 restart <app_name>
systemctl restart nginx
```

### High Memory Usage

```bash
# Check memory per instance
pm2 describe <app_name>

# Reduce instance count temporarily
pm2 scale <app_name> 1

# Restart high-memory process
pm2 restart <app_name>
```

### Database Connection Issues (DetoxNearMe only)

```bash
# Test database connectivity
nc -zv sql-steelgem 5432

# Check environment variables
cat /var/www/apps/detoxnearme/.env.local | grep DATABASE_URL

# View database-related errors
pm2 logs detoxnearme --err | grep -i "database\|postgres"
```

---

## 📁 Important Locations

### Application Directories

```
/var/www/apps/detoxnearme/      # DetoxNearMe
/var/www/apps/edge_nextjs/      # Edge Treatment
/var/www/apps/forge_nextjs/     # Forge Recovery
```

### Configuration Files

```
/var/www/apps/ecosystem.config.js              # PM2 ecosystem
/etc/nginx/sites-available/detoxnearme         # DetoxNearMe NGINX
/etc/nginx/sites-available/edge_nextjs         # Edge NGINX
/etc/nginx/sites-available/forge_nextjs        # Forge NGINX
/etc/nginx/nginx.conf                          # Global NGINX
```

### SSL Certificates

```
/etc/ssl/certs/cloudflare-origin-fullchain.pem
/etc/ssl/private/ssl-cert.key
```

### Logs

```
/var/log/pm2/detoxnearme-*.log   # DetoxNearMe logs
/var/log/pm2/edge-*.log          # Edge Treatment logs
/var/log/pm2/forge-*.log         # Forge Recovery logs
/var/log/nginx/error.log         # NGINX errors
/var/log/nginx/access.log        # NGINX access
```

### Environment Files

```
/var/www/apps/detoxnearme/.env.local
/var/www/apps/edge_nextjs/.env.local
/var/www/apps/forge_nextjs/.env.local
```

---

## 🔄 Common Operations

### Deploy Application Update

```bash
# 1. Navigate to app directory
cd /var/www/apps/<app_name>

# 2. Pull latest code (if using git)
git pull origin main

# 3. Install dependencies
npm ci --production

# 4. Build application
npm run build

# 5. Reload PM2 (zero-downtime)
pm2 reload <app_name>

# 6. Verify deployment
pm2 logs <app_name> --lines 50
curl -I https://www.<domain>
```

### Scale Application

```bash
# Increase instances
pm2 scale detoxnearme 3

# Decrease instances
pm2 scale detoxnearme 1

# Save new configuration
pm2 save
```

### View Real-Time Logs

```bash
# All applications
pm2 logs

# Specific application
pm2 logs detoxnearme

# Errors only
pm2 logs detoxnearme --err

# Last 100 lines
pm2 logs detoxnearme --lines 100

# Raw log files
tail -f /var/log/pm2/detoxnearme-out.log
tail -f /var/log/pm2/detoxnearme-error.log
```

### Revalidate Content (Edge + Forge)

```bash
# Edge Treatment - Revalidate specific path
curl -X POST https://www.theedgetreatment.com/api/revalidate \
  -H "Content-Type: application/json" \
  -d '{"secret": "your_secret", "path": "/about"}'

# Forge Recovery - Revalidate specific path
curl -X POST https://www.theforgerecovery.com/api/revalidate \
  -H "Content-Type: application/json" \
  -d '{"secret": "your_secret", "path": "/programs"}'
```

---

## 📈 Monitoring Commands

### System Resources

```bash
# CPU and memory
htop

# Disk space
df -h

# Memory details
free -h

# Active connections
netstat -an | grep -E ':(80|443)' | wc -l
```

### PM2 Metrics

```bash
# Process list with metrics
pm2 list

# Real-time monitoring
pm2 monit

# Detailed info
pm2 describe <app_name>

# Environment variables
pm2 env <app_name>
```

### Run System Monitor Script

```bash
/root/monitor-node-steelgem.sh
```

---

## 🚨 Emergency Procedures

### All Applications Down

```bash
# 1. Check PM2 status
pm2 list

# 2. Resurrect PM2 processes
pm2 resurrect

# 3. If that fails, restart from ecosystem
cd /var/www/apps
pm2 start ecosystem.config.js

# 4. Verify NGINX is running
systemctl status nginx
systemctl restart nginx

# 5. Check for errors
pm2 logs --err --lines 50
tail -50 /var/log/nginx/error.log
```

### Server Reboot Recovery

```bash
# PM2 should auto-start via systemd
# If not, start manually:
pm2 resurrect

# Or from ecosystem file:
cd /var/www/apps
pm2 start ecosystem.config.js

# Verify all services
pm2 list
systemctl status nginx
```

### Rollback Deployment

```bash
# 1. Navigate to app directory
cd /var/www/apps/<app_name>

# 2. Checkout previous version
git checkout <previous_commit_hash>

# 3. Rebuild
npm ci --production
npm run build

# 4. Reload PM2
pm2 reload <app_name>

# 5. Verify
curl -I https://www.<domain>
```

---

## 📞 Support Contacts

### Documentation

- **Setup Guide**: `docs/NODE-STEELGEM-SETUP.md`
- **Implementation**: `docs/NODE-STEELGEM-IMPLEMENTATION.md`
- **Configuration**: `conf/node-steelgem/README.md`
- **PM2 Guides**: `conf/node-steelgem/*/pm2.md`

### Health Checks

```bash
# Run health check script
/root/health-check.sh

# View health check log
tail -50 /var/log/health-check.log
```

---

## ⚡ Performance Tips

- **Normal CPU**: 30-60% avg
- **Normal Memory**: 2-3GB total (6 processes × 300-500MB)
- **Response Time**: < 200ms typical
- **Concurrent Users**: 1500-2000 capacity

### If Performance Degrades

1. Check `pm2 monit` for resource usage
2. Scale down if memory high: `pm2 scale <app> 1`
3. Check for memory leaks in logs
4. Review NGINX access logs for traffic spikes
5. Consider restarting services during low-traffic period

---

## 🔐 Security Checklist

- [ ] `.env.local` files have 600 permissions
- [ ] SSL certificates are valid (check with `openssl x509 -dates`)
- [ ] Firewall is active (`ufw status`)
- [ ] Only ports 22, 80, 443 exposed
- [ ] No sensitive data in logs
- [ ] Regular system updates (`apt update && apt upgrade`)

---

**Last Updated**: February 7, 2026
**Version**: 1.0
**For**: Operations Team

---

**Quick Help**: For detailed troubleshooting, see `docs/NODE-STEELGEM-SETUP.md` sections:

- 🐛 Troubleshooting (Common Issues)
- 📊 Resource Monitoring
- 🔄 Deployment Workflow
- 📝 Maintenance Tasks
