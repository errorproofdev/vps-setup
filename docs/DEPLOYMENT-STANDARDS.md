# Deployment Standards & Best Practices

**Last Updated**: February 8, 2026

This document defines the standards and best practices for all VPS deployments in this repository.

---

## 🔐 SSL Certificate Management

### Critical Standards

1. **ALWAYS use SSL certificates provided in the configuration directories**
   - Location: `conf/[server-name]/[app-name]/nginx/cert.pem` and `key.pem`
   - NEVER use random certificates found on the server
   - NEVER substitute with Cloudflare or Let's Encrypt certs unless explicitly documented

2. **SSL Certificate Deployment Process**

   ```bash
   # Upload certificates
   scp conf/[server]/[app]/nginx/cert.pem [server]:/tmp/
   scp conf/[server]/[app]/nginx/key.pem [server]:/tmp/

   # Create dedicated SSL directory
   ssh [server] "sudo mkdir -p /etc/ssl/[app-name]"
   ssh [server] "sudo mv /tmp/cert.pem /etc/ssl/[app-name]/cert.pem"
   ssh [server] "sudo mv /tmp/key.pem /etc/ssl/[app-name]/key.pem"

   # Set correct permissions
   ssh [server] "sudo chmod 644 /etc/ssl/[app-name]/cert.pem"
   ssh [server] "sudo chmod 600 /etc/ssl/[app-name]/key.pem"
   ```

3. **NGINX SSL Configuration**

   ```nginx
   ssl_certificate /etc/ssl/[app-name]/cert.pem;
   ssl_certificate_key /etc/ssl/[app-name]/key.pem;
   ```

---

## 🎯 Node.js Version Management

### Critical Standards

1. **ALWAYS check .nvmrc file for correct Node version**
   - Location: `conf/[server-name]/[app-name]/.nvmrc`
   - Install the EXACT version specified
   - Do NOT assume or use system Node version

2. **Node Version Installation Process**

   ```bash
   # Read the version from .nvmrc
   cat conf/[server]/[app]/.nvmrc

   # Install on server
   ssh [server] "sudo bash -l -c 'source /root/.nvm/nvm.sh && nvm install [version] && nvm alias default [version]'"

   # Verify
   ssh [server] "sudo bash -l -c 'source /root/.nvm/nvm.sh && node --version'"
   ```

---

## 🚀 Application Deployment

### Port Configuration

1. **Check for port conflicts before deployment**

   ```bash
   ssh [server] "lsof -i :[port]"
   ssh [server] "ss -tlnp | grep [port]"
   ```

2. **Use environment variables for port configuration**

   ```bash
   # Set in .env.local OR
   PORT=[port] pm2 start npm --name [app] -- run start
   ```

3. **Update NGINX upstream to match application port**

   ```nginx
   upstream [app-name] {
       server 127.0.0.1:[port];
       keepalive 64;
   }
   ```

### PM2 Process Management

1. **Single Instance (Fork Mode) - Default**

   ```bash
   cd /home/ubuntu/[app-directory]
   sudo bash -l -c 'source /root/.nvm/nvm.sh && nvm use [version] && PORT=[port] pm2 start npm --name [app-name] -- run start'
   pm2 save
   ```

2. **Document process mode in configuration files**
   - Explicitly state: "fork mode (single instance, NOT cluster)"
   - Document why fork mode vs cluster mode

---

## 📂 Directory Structure Standards

### Application Directory

```
/home/ubuntu/[domain.com]/
├── gitlab/                  # Application code
│   ├── .env.local          # Environment variables (chmod 600)
│   ├── .nvmrc              # Node version
│   ├── package.json
│   ├── next.config.js      # (NextJS apps)
│   └── ...
└── [other directories as needed]
```

### SSL Directory

```
/etc/ssl/[app-name]/
├── cert.pem                # Certificate (chmod 644)
└── key.pem                 # Private key (chmod 600)
```

### NGINX Configuration

```
/etc/nginx/
├── nginx.conf              # Global configuration
├── sites-available/
│   └── [domain.com].conf   # Site-specific config
└── sites-enabled/
    └── [domain.com].conf   # Symlink to sites-available
```

---

## 📝 Configuration Documentation

### Required Documentation for Each Deployment

1. **Server Information**
   - Server hostname
   - IP address
   - OS version

2. **Application Details**
   - Application name and domain
   - Framework and version
   - Node.js version (from .nvmrc)
   - Application port
   - PM2 process mode (fork/cluster)

3. **SSL Configuration**
   - Certificate source
   - Certificate paths on server
   - Expiration dates

4. **Directory Paths**
   - Application directory
   - NGINX config path
   - SSL certificate paths
   - Log file locations

5. **Environment Variables**
   - Location of .env file
   - Required variables (without values!)

---

## ✅ Deployment Checklist

Use this checklist for every deployment:

- [ ] Check .nvmrc for correct Node version
- [ ] Verify SSL certificates are in conf/[server]/[app]/nginx/
- [ ] Check for port conflicts on server
- [ ] Upload SSL certificates to /etc/ssl/[app-name]/
- [ ] Set correct SSL file permissions (644 for cert, 600 for key)
- [ ] Update NGINX config with correct SSL paths
- [ ] Update NGINX upstream with correct port
- [ ] Install correct Node version via NVM
- [ ] Install application dependencies with correct Node version
- [ ] Configure environment variables (.env.local)
- [ ] Start PM2 process with correct port and Node version
- [ ] Test NGINX configuration (nginx -t)
- [ ] Reload NGINX
- [ ] Verify application is running (pm2 list)
- [ ] Check application logs (pm2 logs)
- [ ] Test local application endpoint (curl localhost:[port])
- [ ] Test NGINX proxy (curl -I https://[domain])
- [ ] Save PM2 configuration (pm2 save)
- [ ] Document deployment in appropriate files

---

## 🔍 Verification Commands

### SSL Certificate Verification

```bash
# Check certificate details
openssl x509 -in cert.pem -text -noout

# Verify certificate and key match
openssl x509 -noout -modulus -in cert.pem | openssl md5
openssl rsa -noout -modulus -in key.pem | openssl md5
# MD5 hashes should match
```

### Application Health Check

```bash
# PM2 status
pm2 list
pm2 describe [app-name]
pm2 logs [app-name] --lines 50

# Local application
curl -I http://localhost:[port]

# Through NGINX
curl -I https://[domain]

# SSL certificate check
echo | openssl s_client -connect [domain]:443 -servername [domain] 2>/dev/null | openssl x509 -noout -dates
```

---

## 🚨 Common Mistakes to Avoid

1. ❌ **Using wrong SSL certificates**
   - ✅ Always use certificates from conf/[server]/[app]/nginx/

2. ❌ **Using wrong Node version**
   - ✅ Always check .nvmrc file

3. ❌ **Forgetting to set PORT environment variable**
   - ✅ Set PORT in .env.local or PM2 start command

4. ❌ **Not checking for port conflicts**
   - ✅ Check what's using the port before deployment

5. ❌ **Using system Node instead of NVM version**
   - ✅ Always source NVM and use correct version

6. ❌ **Not testing after deployment**
   - ✅ Always verify with curl and check logs

7. ❌ **Not documenting configuration**
   - ✅ Document everything in appropriate files

---

## 📖 Reference

See also:

- [NODE-STEELGEM-SETUP.md](NODE-STEELGEM-SETUP.md) - Full node-steelgem setup guide
- [NEXTJS-DEPLOYMENT.md](NEXTJS-DEPLOYMENT.md) - NextJS-specific deployment guide
- [SERVER-CONTEXT.md](SERVER-CONTEXT.md) - Server overview and context
- [AGENTS.md](../AGENTS.md) - Guidelines for AI agents working with this codebase

---

**Remember**: When in doubt, check the configuration files in the `conf/` directory. They contain the source of truth for all deployments.
