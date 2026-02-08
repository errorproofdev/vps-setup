# Detox Near Me Strapi - VPS Setup Complete

## ✅ Server Setup Summary

**Server:** `ssh sql-steelgem` (sql.steelgem.com)
**OS:** Ubuntu 24.04 (6.8.0-54-generic)
**Date:** January 30, 2026

---

## 🎉 What's Been Installed

### System Components

✅ **System Updates** - All packages updated
✅ **Build Tools** - gcc, g++, make, build-essential
✅ **Tailscale** - VPN networking (v1.94.1)
✅ **NVM** - Node Version Manager (v0.39.3)
✅ **Node.js** - v18.17.0 (matching your pm2.md specs)
✅ **PM2** - Process manager configured for systemd
✅ **PostgreSQL** - Version 16 with database configured
✅ **NGINX** - Web server configured and running

### Directories Created

✅ `/home/ubuntu/detox-near-me-strapi` - Application directory

---

## 📦 PostgreSQL Database

### Database Configuration

- **Database Name:** `detoxnearme`
- **User:** `strapi`
- **Password:** `<stored in server .env>`
- **Host:** localhost
- **Port:** 5432

### Connection String

```bash
DATABASE_URL=postgresql://strapi:<password>@localhost:5432/detoxnearme
```

### To Import Your Database Dump

```bash
# Upload the dump file to the server
scp detoxnearme_pgsql.dump sql-steelgem:/tmp/

# Import the dump
ssh sql-steelgem "psql -U strapi -d detoxnearme < /tmp/detoxnearme_pgsql.dump"
```

**Note:** The database user and password will be preserved during import.

---

## 🌐 NGINX Configuration

### Configuration Files

✅ **Main Config:** `/etc/nginx/nginx.conf` (uploaded)
✅ **Site Config:** `/etc/nginx/sites-available/cms.detoxnearme.com.conf`
✅ **Symlink:** `/etc/nginx/sites-enabled/cms.detoxnearme.com.conf`

### Current Configuration

- **HTTP:** Listening on port 80
- **Domain:** cms.detoxnearme.com
- **Proxy:** All requests forwarded to <http://localhost:1337> (Strapi)

### SSL Setup (TODO)

SSL is commented out in the config. To enable HTTPS:

```bash
# Install certbot
ssh sql-steelgem "sudo apt-get install -y certbot python3-certbot-nginx"

# Get SSL certificate
ssh sql-steelgem "sudo certbot --nginx -d cms.detoxnearme.com"

# Certbot will automatically configure NGINX for SSL
```

---

## 🚀 Next Steps: Deploy Your Strapi Application

### Step 1: Upload Strapi Application Files

```bash
# From your local machine, SCP your Strapi application
cd /path/to/your/local/detox-near-me-strapi
tar -czf detox-strapi.tar.gz .
scp detox-strapi.tar.gz sql-steelgem:/home/ubuntu/

# On the server, extract
ssh sql-steelgem "cd /home/ubuntu/detox-near-me-strapi && tar -xzf ../detox-strapi.tar.gz && rm ../detox-strapi.tar.gz"
```

### Step 2: Import Database Dump

```bash
# Upload and import your PostgreSQL dump
scp /path/to/detoxnearme_pgsql.dump sql-steelgem:/tmp/
ssh sql-steelgem "PGPASSWORD='strapi_password_2024' psql -U strapi -d detoxnearme -h localhost < /tmp/detoxnearme_pgsql.dump"
```

### Step 3: Configure Strapi Environment

```bash
# SSH into the server
ssh sql-steelgem

# Create/edit .env file in your Strapi directory
cd /home/ubuntu/detox-near-me-strapi
nano .env
```

Add these environment variables:

```env
# Server
HOST=0.0.0.0
PORT=1337
NODE_ENV=production

# Database
DATABASE_CLIENT=postgres
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=detoxnearme
DATABASE_USERNAME=strapi
DATABASE_PASSWORD=strapi_password_2024
DATABASE_SSL=false

# Admin JWT
ADMIN_JWT_SECRET=your-admin-jwt-secret-here
JWT_SECRET=your-jwt-secret-here
API_TOKEN_SALT=your-api-token-salt-here
APP_KEYS=your-app-keys-here

# Other settings as needed
```

### Step 4: Install Dependencies

```bash
ssh sql-steelgem << 'EOF'
# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Ensure we're using Node 18.17.0
nvm use 18.17.0

# Install dependencies
cd /home/ubuntu/detox-near-me-strapi
npm install --production

# Build Strapi admin panel
npm run build
EOF
```

### Step 5: Start with PM2

```bash
ssh sql-steelgem << 'EOF'
# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Go to app directory
cd /home/ubuntu/detox-near-me-strapi

# Start with PM2 (matching your pm2.md configuration)
pm2 start npm --name "strapi" -- start

# Save PM2 configuration
pm2 save

# Verify it's running
pm2 status
pm2 logs strapi --lines 50
EOF
```

### Step 6: Verify Deployment

```bash
# Check PM2 status
ssh sql-steelgem "pm2 status"

# Check logs
ssh sql-steelgem "pm2 logs strapi --lines 20"

# Test locally on server
ssh sql-steelgem "curl http://localhost:1337"

# Test via NGINX
curl http://cms.detoxnearme.com
```

---

## 📋 Server Configuration Details

### Node.js Version (Matches pm2.md)

- **Version:** v18.17.0
- **NPM:** v9.6.7
- **Installed via:** NVM
- **Location:** `/root/.nvm/versions/node/v18.17.0`

### PM2 Configuration

- **User:** ubuntu
- **Home:** /home/ubuntu/.pm2
- **Startup:** systemd (enabled)
- **Service:** pm2-ubuntu.service
- **Logs:** /home/ubuntu/.pm2/logs/

### PostgreSQL

- **Version:** 16
- **Service:** postgresql.service (enabled)
- **Data:** /var/lib/postgresql/16/main

### NGINX

- **Version:** 1.24.0
- **Config:** /etc/nginx/nginx.conf
- **Sites:** /etc/nginx/sites-available/
- **Logs:** /var/log/nginx/

---

## 🔧 Useful Commands

### PM2 Management

```bash
# View status
ssh sql-steelgem "pm2 status"

# View logs
ssh sql-steelgem "pm2 logs strapi"

# Restart
ssh sql-steelgem "pm2 restart strapi"

# Stop
ssh sql-steelgem "pm2 stop strapi"

# Detailed info (like your pm2.md)
ssh sql-steelgem "pm2 describe strapi"

# Monitor
ssh sql-steelgem "pm2 monit"
```

### Database Management

```bash
# Connect to database (use password from .env)
ssh sql-steelgem "PGPASSWORD='<db-password>' psql -U strapi -d detoxnearme"

# Backup database
ssh sql-steelgem "PGPASSWORD='<db-password>' pg_dump -U strapi -d detoxnearme > /tmp/detoxnearme_backup.sql"

# List tables
ssh sql-steelgem "PGPASSWORD='<db-password>' psql -U strapi -d detoxnearme -c '\\dt'"
```

### NGINX Management

```bash
# Test configuration
ssh sql-steelgem "sudo nginx -t"

# Reload configuration
ssh sql-steelgem "sudo systemctl reload nginx"

# View access logs
ssh sql-steelgem "sudo tail -f /var/log/nginx/access.log"

# View error logs
ssh sql-steelgem "sudo tail -f /var/log/nginx/error.log"
```

### System Management

```bash
# Check services
ssh sql-steelgem "sudo systemctl status postgresql nginx pm2-ubuntu"

# View system info
ssh sql-steelgem "uname -a && df -h && free -h"

# Connect to Tailscale (if needed)
ssh sql-steelgem "sudo tailscale up"
```

---

## 🔐 Security Notes

### Firewall (UFW)

```bash
# Allow HTTP
ssh sql-steelgem "sudo ufw allow 80/tcp"

# Allow HTTPS (for when you setup SSL)
ssh sql-steelgem "sudo ufw allow 443/tcp"

# Allow SSH (should already be allowed)
ssh sql-steelgem "sudo ufw allow 22/tcp"

# Enable firewall
ssh sql-steelgem "sudo ufw enable"

# Check status
ssh sql-steelgem "sudo ufw status"
```

### Change Database Password (Recommended)

```bash
ssh sql-steelgem "sudo -u postgres psql -c \"ALTER USER strapi WITH PASSWORD 'your-new-secure-password';\""
```

Then update your `.env` file in the Strapi application.

---

## 📊 Expected PM2 Output (Matching your pm2.md)

After starting Strapi with PM2, you should see:

```bash
┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name               │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ strapi             │ fork     │ 0    │ online    │ 0%       │ 42.0mb   │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
```

Working directory: `/home/ubuntu/detox-near-me-strapi`
Node.js version: `18.17.0`
Script: `npm start`

---

## 🐛 Troubleshooting

### Strapi Won't Start

```bash
# Check Node version
ssh sql-steelgem "source ~/.bashrc && nvm use 18.17.0 && node --version"

# Check dependencies
ssh sql-steelgem "cd /home/ubuntu/detox-near-me-strapi && npm install"

# Check database connection
ssh sql-steelgem "PGPASSWORD='strapi_password_2024' psql -U strapi -d detoxnearme -c 'SELECT 1;'"

# View full logs
ssh sql-steelgem "pm2 logs strapi --lines 100"
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
ssh sql-steelgem "sudo systemctl status postgresql"

# Check database exists
ssh sql-steelgem "sudo -u postgres psql -l | grep detoxnearme"

# Test connection
ssh sql-steelgem "PGPASSWORD='strapi_password_2024' psql -U strapi -d detoxnearme -c 'SELECT version();'"
```

### NGINX Issues

```bash
# Check NGINX is running
ssh sql-steelgem "sudo systemctl status nginx"

# Test configuration
ssh sql-steelgem "sudo nginx -t"

# Check if port 1337 is open
ssh sql-steelgem "sudo netstat -tlnp | grep 1337"
# or
ssh sql-steelgem "sudo ss -tlnp | grep 1337"

# Check NGINX error logs
ssh sql-steelgem "sudo tail -100 /var/log/nginx/error.log"
```

---

## ✅ Setup Complete

Your VPS is now configured and ready for Strapi deployment. Follow the "Next Steps" section above to:

1. Upload your Strapi application
2. Import the database dump
3. Configure environment variables
4. Install dependencies
5. Start with PM2

**Server Ready:** ✅
**Database Ready:** ✅
**NGINX Ready:** ✅
**PM2 Ready:** ✅

All that's left is uploading your application files and database dump!

---

## 📞 Quick Reference

| Component | Status | Port | User |
|-----------|--------|------|------|
| PostgreSQL | ✅ Running | 5432 | strapi |
| NGINX | ✅ Running | 80 | www-data |
| Node.js | ✅ v18.17.0 | - | ubuntu |
| PM2 | ✅ Configured | - | ubuntu |
| Strapi | ⏳ Ready to deploy | 1337 | ubuntu |

**Server IP:** Check with `ssh sql-steelgem "hostname -I"`
**Domain:** cms.detoxnearme.com → <http://localhost:1337>

---

**Questions?** Check the troubleshooting section or view logs:

```bash
ssh sql-steelgem "pm2 logs strapi"
```
