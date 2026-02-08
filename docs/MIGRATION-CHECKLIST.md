# NextJS Migration Checklist & Action Items

Complete this checklist step-by-step to migrate your NextJS applications from EC2 to the new VPS.

## Pre-Migration Setup (1 hour)

### Step 1: Prepare VPS Base System

- [ ] SSH into VPS as root
- [ ] Run `chmod +x scripts/*.sh`
- [ ] Run `sudo ./scripts/vps-setup.sh` (takes ~5 minutes)
  - Creates ubuntu user with sudo access
  - Hardens SSH configuration
  - Sets up UFW firewall (ports 22, 80, 443)
  - Installs base packages (nginx, curl, wget, git, etc.)
  - Installs fail2ban

**Verify:**

```bash
systemctl status nginx          # Should be active
systemctl status fail2ban      # Should be active
ufw status                      # Should show ports 22,80,443 allowed
```

### Step 2: Verify NextJS Functions in scripts/services.sh

- [ ] Confirm NextJS functions are present in `scripts/services.sh`
- [ ] Verify file integrity: `bash -n scripts/services.sh` (should output nothing)

**Verification:**

```bash
# Check functions are present
grep -c "install_nvm\|optimize_nginx\|deploy_nextjs" scripts/services.sh
# Should show: 3
```

### Step 3: Prepare SSL Certificates

- [ ] Copy Cloudflare origin certificates to VPS
  - Source: `conf/www.theedgetreatment.com/ssl/cloudflare-origin-fullchain.pem`
  - Source: `conf/www.theedgetreatment.com/ssl/key.pem`
  - Destination: `/Users/josephvore/CODE/vps-setup/conf/www.theedgetreatment.com/ssl/`
  - Command: `scp -r conf/ ubuntu@VPS_IP:/home/ubuntu/vps-setup/conf/`
- [ ] Verify certificates exist locally

  ```bash
  ls -la /Users/josephvore/CODE/vps-setup/conf/www.theedgetreatment.com/ssl/
  ```

### Step 4: Set up SSH Config Alias

- [ ] Add SSH alias for EC2 in `~/.ssh/config`

  ```bash
  Host edge-prod
      HostName ec2-instance-ip.compute.amazonaws.com
      User ubuntu
      IdentityFile ~/.ssh/ec2-key.pem
      StrictHostKeyChecking no
  ```

- [ ] Test SSH connection: `ssh edge-prod 'echo OK'`
  - Should return "OK"

**Verify:**

```bash
ssh edge-prod 'ls -la /home/ubuntu/current/.nvmrc'
# Should show .nvmrc file
```

## First App Migration: <www.theedgetreatment.com> (30 minutes)

### Step 5: Install Node Version Manager (NVM)

```bash
ssh ubuntu@VPS_IP
sudo ./scripts/services.sh nvm
```

**Verify:**

```bash
bash -ic 'source ~/.nvm/nvm.sh && nvm list'
# Should show Node.js versions available
```

### Step 6: Optimize NGINX Configuration

```bash
sudo ./scripts/services.sh nextjs-nginx
```

**Verify:**

```bash
sudo nginx -t
# Should output: "nginx: configuration file test is successful"

systemctl status nginx
# Should be active and running
```

### Step 7: Install Cloudflare SSL Certificates

```bash
# Ensure certs are in place locally first
ls conf/www.theedgetreatment.com/ssl/
# Should show: cloudflare-origin-fullchain.pem, key.pem

sudo ./scripts/services.sh nextjs-ssl
```

**Verify:**

```bash
ls -la /etc/ssl/certs/cloudflare-origin-fullchain.pem
ls -la /etc/ssl/private/ssl-cert.key

openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -noout -dates
# Should show valid dates
```

### Step 8: Deploy Edge Treatment App

```bash
sudo ./scripts/services.sh edge-migrate
```

This will:

1. Check disk space (need 10GB)
2. Verify NVM is available
3. Verify NGINX is running
4. Verify PM2 is installed
5. Verify SSL certs are in place
6. Run full deployment (12 steps):
   - Create app directory
   - Transfer files from EC2
   - Transfer .env.local
   - Set permissions
   - Load NVM/.nvmrc
   - Install dependencies
   - Build app
   - Create PM2 config
   - Start with PM2
   - Create NGINX site config
   - Test connectivity

**Verify Deployment Success:**

```bash
# Check PM2 status
pm2 list
# Should show: edge_nextjs | 1 | fork | online

# Check app is running
curl http://localhost:3000

# Check NGINX config
sudo nginx -t
ls -la /etc/nginx/sites-enabled/ | grep edge_nextjs

# Check logs
pm2 logs edge_nextjs
# Should show: [Edge Treatment] listening on port 3000

# Check HTTPS access
curl -k https://www.theedgetreatment.com
# Should return HTML content
```

### Step 9: Test Full Deployment

```bash
sudo ./scripts/services.sh nextjs-test edge_nextjs 3000
```

This runs 5 tests:

1. PM2 process status (should be online)
2. Port connectivity (should respond)
3. NGINX validation (should be valid)
4. Memory usage (should show usage)
5. Error logs (should be clean)

**Success Criteria:**

- All 5 tests pass
- PM2 shows edge_nextjs online
- `curl https://www.theedgetreatment.com` returns 200 OK
- Logs show no errors

### Step 10: Update DNS (When Ready)

Once verified working, update Cloudflare DNS:

- [ ] Log into Cloudflare dashboard
- [ ] Go to DNS settings for theedgetreatment.com
- [ ] Change A record from `old-ec2-ip` to `new-vps-ip`
- [ ] TTL: 5 minutes (for quick rollback if needed)
- [ ] Wait 5-10 minutes for propagation
- [ ] Test: `dig theedgetreatment.com` should show new IP

**Verify:**

```bash
nslookup www.theedgetreatment.com
# Should return VPS IP

curl -I https://www.theedgetreatment.com
# Should return 200 OK
```

## Additional Apps Deployment (10 min each)

### The Forge Recovery (theforgerecovery.com)

```bash
sudo ./scripts/services.sh nextjs-deploy forge_nextjs theforgerecovery.com 3001 edge-prod /home/ubuntu/current
sudo ./scripts/services.sh nextjs-test forge_nextjs 3001
```

**Configuration:**

- App Name: `forge_nextjs`
- Domain: `theforgerecovery.com`
- Port: `3001`
- SSH Host: `edge-prod`
- Remote Path: `/home/ubuntu/current`

**Verify:**

```bash
pm2 list | grep forge_nextjs
curl http://localhost:3001
curl -k https://www.theforgerecovery.com
```

### DetoxNearMe (detoxnearme.com)

```bash
sudo ./scripts/services.sh nextjs-deploy detoxnearme detoxnearme.com 3002 edge-prod /home/ubuntu/current
sudo ./scripts/services.sh nextjs-test detoxnearme 3002
```

**Configuration:**

- App Name: `detoxnearme`
- Domain: `detoxnearme.com`
- Port: `3002`
- SSH Host: `edge-prod`
- Remote Path: `/home/ubuntu/current`
- Note: Uses Redis (10.0.35.126:6379) + PostgreSQL

**Verify:**

```bash
pm2 list | grep detoxnearme
curl http://localhost:3002
curl -k https://www.detoxnearme.com
```

## Post-Migration Monitoring (Ongoing)

### Daily Checks

```bash
# Check all apps are running
pm2 list

# Check disk usage
df -h /var/www

# Check NGINX status
systemctl status nginx

# Check system logs
sudo journalctl -n 50 -u nginx
```

### Weekly Maintenance

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Clear old PM2 logs
pm2 flush

# Verify SSL certificates (check expiration dates)
openssl x509 -in /etc/ssl/certs/cloudflare-origin-fullchain.pem -noout -dates
```

### Monitor Application Logs

```bash
# Real-time logs for all apps
pm2 logs

# Specific app logs
pm2 logs edge_nextjs
pm2 logs forge_nextjs
pm2 logs detoxnearme

# Error logs only
pm2 logs --err

# Save logs to file
pm2 save
pm2 logs > /tmp/pm2-logs.txt
```

## Rollback Procedure (If Issues Occur)

If something goes wrong after DNS cutover:

### Quick Rollback (< 5 min)

```bash
# In Cloudflare DNS:
# Change A record back to EC2 IP
# Wait 5-10 minutes for propagation

# Verify old app still running on EC2:
ssh ubuntu@old-ec2-ip
pm2 status
```

### Investigate VPS Issue

```bash
# Check app status
pm2 list

# Check logs for errors
pm2 logs edge_nextjs --err | head -20

# Check NGINX config
sudo nginx -t
cat /etc/nginx/sites-enabled/edge_nextjs

# Check disk space
df -h

# Check system resources
free -h
```

### Restart Application

```bash
# Restart specific app
pm2 restart edge_nextjs

# Or full restart
pm2 kill
pm2 start /var/www/apps/edge_nextjs/ecosystem.config.js
pm2 save
```

### Rerun Deployment Tests

```bash
sudo ./scripts/services.sh nextjs-test edge_nextjs 3000
```

## Important Notes

### Deployment Defaults

- Apps installed in: `/var/www/apps/{app_name}/`
- PM2 logs in: `/var/log/pm2/{app_name}-{error,out}.log`
- NGINX configs in: `/etc/nginx/sites-available/{app_name}`
- SSL certs from: `/etc/ssl/certs/cloudflare-origin-fullchain.pem`
- SSH alias: `edge-prod` (must be in ~/.ssh/config)

### Network & Performance

- 4-core VPS can handle all 3 NextJS apps simultaneously
- Each app limited to 1GB memory (auto-restart if exceeded)
- PostgreSQL/Redis on separate servers for isolation
- Rate limiting: 30 connections per IP (configurable)

### Environment Variables

- `.env.local` transferred securely via scp
- Stored with 600 permissions (ubuntu user only)
- Includes: API keys, database credentials, Redis URL, etc.
- To update: copy new .env.local to VPS or edit directly

### SSL & Security

- Cloudflare origin certificates (not Let's Encrypt)
- TLSv1.2 minimum (TLSv1.3 supported)
- HSTS enabled (max-age 2 years)
- Gzip compression enabled (level 6)
- Real IP from Cloudflare (30 IP ranges)

### Monitoring & Logs

- PM2 process manager: `pm2 list`, `pm2 logs`
- NGINX error logs: `/var/log/nginx/error.log`
- System logs: `journalctl -u nginx`
- App logs: `/var/log/pm2/{app_name}-{error,out}.log`

## Success Metrics

✅ **All three apps successfully migrated when:**

1. All apps show `online` in `pm2 list`
2. All HTTPS domains respond with 200 OK
3. All logs are clean (no errors for 24 hours)
4. DNS is pointing to VPS IP
5. SSL certificates are valid
6. Database connections work
7. Cache/Redis connections work
8. All environment variables loaded correctly

## Support & Troubleshooting

See [NEXTJS-DEPLOYMENT.md](NEXTJS-DEPLOYMENT.md) for detailed troubleshooting:

- App won't build
- Port not responding
- NGINX config issues
- SSL certificate issues
- PM2 process respawn issues

## Timeline Summary

- **Pre-migration setup:** ~1 hour
- **Edge Treatment migration:** ~30 minutes
- **The Forge migration:** ~10 minutes
- **DetoxNearMe migration:** ~10 minutes
- **DNS cutover:** 5-10 minutes (propagation)
- **Post-migration verification:** ~15 minutes

**Total time: ~2 hours for all 3 apps**
