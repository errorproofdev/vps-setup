#!/bin/bash
# NextJS Deployment Functions
# Copy and paste these into services.sh before the "SERVICE=$1" line

# ============================================================
# NextJS DEPLOYMENT FUNCTIONS
# ============================================================

# NVM Installation (Node Version Manager)
install_nvm() {
    log "Installing NVM (Node Version Manager)..."
    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        warning "NVM already installed"
        return 0
    fi
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    success "NVM installed successfully"
}

# Load Node version from .nvmrc
load_nvm_and_node() {
    local app_path="$1"
    if [[ ! -d "$app_path" ]]; then
        warning "App path does not exist: $app_path"
        return 1
    fi
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    if [[ -f "$app_path/.nvmrc" ]]; then
        log "Found .nvmrc in $app_path"
        cd "$app_path"
        nvm install || return 1
        nvm use || return 1
        log "Node version: $(node --version)"
    else
        log "No .nvmrc found in $app_path, using system Node.js"
        log "Current Node version: $(node --version)"
    fi
    return 0
}

# Optimize NGINX global configuration for Node.js/NextJS
optimize_nginx_global() {
    log "Optimizing NGINX global configuration..."
    [[ ! -f /etc/nginx/nginx.conf.backup ]] && cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    cat > /etc/nginx/nginx.conf << 'NGINX_CONF_EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    use epoll;
    worker_connections 16384;
    multi_accept on;
}

http {
    client_body_timeout 60s;
    client_header_timeout 60s;
    send_timeout 60s;
    keepalive_timeout 65s;
    keepalive_requests 100;
    server_tokens off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    client_max_body_size 20M;
    large_client_header_buffers 4 128k;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    map_hash_max_size 4096;
    map_hash_bucket_size 128;
    proxy_buffering on;
    proxy_buffers 16 32k;
    proxy_buffer_size 32k;
    proxy_busy_buffers_size 96k;
    limit_conn_zone $binary_remote_addr zone=perip:10m;
    limit_conn perip 30;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305';
    ssl_prefer_server_ciphers off;
    ssl_ecdh_curve X25519:P-256:P-384:P-521;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 1.0.0.1 valid=300s;
    resolver_timeout 5s;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;

    gzip on;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript application/vnd.ms-fontobject application/x-font-ttf font/opentype image/svg+xml image/x-icon;

    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 2400:cb00::/32;
    set_real_ip_from 2606:4700::/32;
    set_real_ip_from 2803:f800::/32;
    set_real_ip_from 2405:b500::/32;
    set_real_ip_from 2405:8100::/32;
    set_real_ip_from 2a06:98c0::/29;
    set_real_ip_from 2c0f:f248::/32;
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGINX_CONF_EOF
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        success "NGINX global configuration optimized"
    else
        warning "NGINX configuration validation failed, reverting backup"
        cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf
        nginx -t
        return 1
    fi
}

# Install Cloudflare SSL certificates
install_cloudflare_ssl_certs() {
    log "Installing Cloudflare SSL certificates..."
    local cert_source="${CERT_SOURCE:-./conf/www.theedgetreatment.com/ssl/cloudflare-origin-fullchain.pem}"
    local key_source="${KEY_SOURCE:-./conf/www.theedgetreatment.com/ssl/key.pem}"
    local cert_dest="/etc/ssl/certs/cloudflare-origin-fullchain.pem"
    local key_dest="/etc/ssl/private/ssl-cert.key"
    mkdir -p /etc/ssl/certs /etc/ssl/private
    if [[ -f "$cert_source" ]]; then
        cp "$cert_source" "$cert_dest"
        chmod 644 "$cert_dest"
        log "Installed certificate: $cert_dest"
    else
        warning "Certificate source not found: $cert_source"
        return 1
    fi
    if [[ -f "$key_source" ]]; then
        cp "$key_source" "$key_dest"
        chmod 600 "$key_dest"
        log "Installed private key: $key_dest"
    else
        warning "Private key source not found: $key_source"
        return 1
    fi
    if openssl x509 -in "$cert_dest" -text -noout >/dev/null 2>&1; then
        success "SSL certificates installed and validated"
    else
        warning "SSL certificate validation failed"
        return 1
    fi
}

# Create NGINX site config for NextJS app
create_nginx_nextjs_site() {
    local domain="$1"
    local port="$2"
    local app_name="$3"
    local ssl_cert="${4:-/etc/ssl/certs/cloudflare-origin-fullchain.pem}"
    local ssl_key="${5:-/etc/ssl/private/ssl-cert.key}"
    
    if [[ -z "$domain" || -z "$port" || -z "$app_name" ]]; then
        warning "Usage: create_nginx_nextjs_site <domain> <port> <app_name> [ssl_cert] [ssl_key]"
        return 1
    fi
    
    log "Creating NGINX config for $app_name ($domain:$port)..."
    local root_domain="${domain#www.}"
    
    cat > /etc/nginx/sites-available/"${app_name}" << 'NGINX_SITE_EOF'
upstream APP_NAME_VAR {
    server 127.0.0.1:APP_PORT_VAR;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name ROOT_DOMAIN_VAR;
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    location / {
        return 301 https://www.${server_name}${request_uri};
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name www.FULL_DOMAIN_VAR;
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    location / {
        return 301 https://${server_name}${request_uri};
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ROOT_DOMAIN_VAR;
    ssl_certificate SSL_CERT_VAR;
    ssl_certificate_key SSL_KEY_VAR;
    location / {
        return 301 https://www.FULL_DOMAIN_VAR${request_uri};
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.FULL_DOMAIN_VAR;
    ssl_certificate SSL_CERT_VAR;
    ssl_certificate_key SSL_KEY_VAR;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    root /var/www/apps/APP_NAME_VAR/public;
    location / {
        try_files $uri @nextjs;
    }
    location @nextjs {
        proxy_pass http://APP_NAME_VAR;
        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location ~* ^/_next/static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_SITE_EOF

    sed -i "s/APP_NAME_VAR/${app_name}/g" /etc/nginx/sites-available/"${app_name}"
    sed -i "s/APP_PORT_VAR/${port}/g" /etc/nginx/sites-available/"${app_name}"
    sed -i "s|FULL_DOMAIN_VAR|${domain}|g" /etc/nginx/sites-available/"${app_name}"
    sed -i "s|ROOT_DOMAIN_VAR|${root_domain}|g" /etc/nginx/sites-available/"${app_name}"
    sed -i "s|SSL_CERT_VAR|${ssl_cert}|g" /etc/nginx/sites-available/"${app_name}"
    sed -i "s|SSL_KEY_VAR|${ssl_key}|g" /etc/nginx/sites-available/"${app_name}"
    
    ln -sf /etc/nginx/sites-available/"${app_name}" /etc/nginx/sites-enabled/"${app_name}"
    
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        success "NGINX site config created for ${app_name}"
    else
        warning "NGINX config test failed for ${app_name}"
        rm -f /etc/nginx/sites-enabled/"${app_name}"
        return 1
    fi
}

# Deploy NextJS application from EC2 to VPS
deploy_nextjs_app() {
    local app_name="$1"
    local domain="$2"
    local port="$3"
    local ssh_host="${4:-edge-prod}"
    local remote_path="${5:-/home/ubuntu/current}"
    
    if [[ -z "$app_name" || -z "$domain" || -z "$port" ]]; then
        warning "Usage: deploy_nextjs_app <app_name> <domain> <port> [ssh_host] [remote_path]"
        return 1
    fi
    
    log "Starting NextJS deployment for ${app_name}..."
    local local_path="/var/www/apps/${app_name}"
    
    log "1/12: Creating app directory..."
    mkdir -p "$local_path"
    
    log "2/12: Transferring app files from EC2..."
    rsync -avz --progress --exclude='node_modules' --exclude='.git' --exclude='.next' --exclude='dist' \
        "${ssh_host}:${remote_path}/" "${local_path}/" || return 1
    
    log "3/12: Transferring environment file..."
    scp "${ssh_host}:${remote_path}/.env.local" "${local_path}/.env.local" 2>/dev/null || warning "Could not copy .env.local"
    chmod 600 "${local_path}/.env.local" 2>/dev/null || true
    
    log "4/12: Setting directory ownership..."
    chown -R www-data:www-data "$local_path"
    chmod -R 755 "$local_path"
    
    log "5/12: Loading NVM and installing Node version..."
    if ! load_nvm_and_node "$local_path"; then
        warning "Could not load NVM, continuing with system Node"
    fi
    
    log "6/12: Installing production dependencies..."
    cd "$local_path"
    npm ci --production || return 1
    
    log "7/12: Building NextJS application..."
    NODE_ENV=production npm run build || return 1
    [[ ! -d "$local_path/.next" ]] && warning ".next directory missing after build" && return 1
    
    log "8/12: Creating PM2 ecosystem config..."
    cat > "${local_path}/ecosystem.config.js" << ECOSYSTEM_EOF
module.exports = {
  apps: [{
    name: '${app_name}',
    cwd: '${local_path}',
    script: 'npm',
    args: 'start -- -p ${port}',
    instances: 1,
    exec_mode: 'fork',
    env: { NODE_ENV: 'production', PORT: ${port} },
    error_file: '/var/log/pm2/${app_name}-error.log',
    out_file: '/var/log/pm2/${app_name}-out.log',
    max_memory_restart: '1G',
    autorestart: true
  }]
};
ECOSYSTEM_EOF
    
    log "9/12: Creating PM2 log directory..."
    mkdir -p /var/log/pm2
    chown www-data:www-data /var/log/pm2
    
    log "10/12: Starting app with PM2..."
    pm2 start "${local_path}/ecosystem.config.js" || return 1
    pm2 save
    
    sleep 5
    
    log "11/12: Creating NGINX site config..."
    create_nginx_nextjs_site "$domain" "$port" "$app_name" || return 1
    
    log "12/12: Testing connectivity..."
    curl -f http://localhost:${port} >/dev/null 2>&1 || warning "Port ${port} not responding yet"
    
    success "NextJS app ${app_name} deployed successfully!"
    return 0
}

# Test NextJS application deployment
test_nextjs_deployment() {
    local app_name="$1"
    local port="$2"
    
    if [[ -z "$app_name" || -z "$port" ]]; then
        warning "Usage: test_nextjs_deployment <app_name> <port>"
        return 1
    fi
    
    log "Testing ${app_name} deployment..."
    
    log "[1/5] Checking PM2 process..."
    pm2 list | grep -q "${app_name}" && success "✓ PM2 online" || warning "✗ PM2 issue"
    
    log "[2/5] Checking port ${port}..."
    curl -f http://localhost:${port} >/dev/null 2>&1 && success "✓ Port responding" || warning "✗ Port not responding"
    
    log "[3/5] Validating NGINX..."
    nginx -t 2>/dev/null && success "✓ NGINX valid" || warning "✗ NGINX issue"
    
    log "[4/5] Checking memory..."
    pm2 info "${app_name}" 2>/dev/null | grep -i memory
    
    log "[5/5] Checking for errors..."
    pm2 logs "${app_name}" --err --lines 5 2>/dev/null | grep -q "error" && warning "⚠ Errors found" || success "✓ No errors"
    
    success "Deployment tests completed"
}

# Migrate www.theedgetreatment.com
migrate_edge_treatment() {
    log "Starting edge_nextjs migration..."
    local app_name="edge_nextjs"
    local domain="theedgetreatment.com"
    local port=3000
    
    log "Running pre-flight checks..."
    [[ ! -f "/etc/ssl/certs/cloudflare-origin-fullchain.pem" ]] && install_cloudflare_ssl_certs
    [[ ! -f /etc/nginx/nginx.conf.backup ]] && optimize_nginx_global
    
    deploy_nextjs_app "$app_name" "$domain" "$port" "edge-prod" "/home/ubuntu/current" && \
    test_nextjs_deployment "$app_name" "$port"
}
