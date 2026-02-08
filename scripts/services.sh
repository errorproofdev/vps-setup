#!/bin/bash

# Service-specific installation modules for VPS Setup
# This file contains optional services that can be installed

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

# Load environment variables from .env if present
load_env() {
    if [[ -f "${ENV_FILE}" ]]; then
        log "Loading environment from ${ENV_FILE}"
        set -a
        # shellcheck source=/dev/null
        . "${ENV_FILE}"
        set +a
    fi
}

load_env

# Create global alias command for services.sh
install_services_alias() {
    log "Installing services.sh alias..."
    local alias_path="/usr/local/bin/vps-services"
    local script_path="/root/vps-setup/scripts/services.sh"

    cat > "$alias_path" << EOF
#!/bin/bash
exec "$script_path" "\$@"
EOF

    chmod +x "$alias_path"
    success "Alias installed: vps-services"
    log "Usage: vps-services <service_name>"
}

# Tailscale Installation (recommended: TS_AUTHKEY for non-interactive)
install_tailscale() {
    log "Installing Tailscale..."

    if ! command -v tailscale >/dev/null 2>&1; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi

    systemctl enable --now tailscaled

    # Bring up Tailscale (interactive unless TS_AUTHKEY is set)
    TS_HOSTNAME="${TS_HOSTNAME:-wp-steelgem}"
    if [[ -n "${TS_AUTHKEY:-}" ]]; then
        tailscale up --ssh --hostname "${TS_HOSTNAME}" --authkey "${TS_AUTHKEY}" || true
    else
        tailscale up --ssh --hostname "${TS_HOSTNAME}" || true
    fi

    success "Tailscale installed (and 'tailscale up' attempted)"
    log "Check status with: tailscale status"
}

# MySQL Installation
install_mysql() {
    log "Installing MySQL..."
    
    # Install MySQL server and client
    apt-get install -y mysql-server mysql-client
    
    # Enable and start MySQL
    systemctl enable mysql
    systemctl start mysql
    
    log "Run 'mysql_secure_installation' to harden MySQL interactively (recommended)."
    log "For WordPress, prefer creating an app DB/user instead of using root."
    
    success "MySQL installed and secured"
}

# PostgreSQL Installation
install_postgresql() {
    log "Installing PostgreSQL..."
    
    # Install PostgreSQL
    apt-get install -y postgresql postgresql-contrib
    
    # Enable and start PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql
    
    if [[ -n "${POSTGRES_ADMIN_USER:-}" && -n "${POSTGRES_ADMIN_PASSWORD:-}" ]]; then
        sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_ADMIN_USER}'" | grep -q 1 \
            || sudo -u postgres psql -c "CREATE USER ${POSTGRES_ADMIN_USER} WITH PASSWORD '${POSTGRES_ADMIN_PASSWORD}' CREATEDB;"
        success "PostgreSQL admin user ensured: ${POSTGRES_ADMIN_USER}"
    else
        log "No POSTGRES_ADMIN_USER/POSTGRES_ADMIN_PASSWORD provided; skipping admin user creation."
    fi
    
    success "PostgreSQL installed successfully"
    log "Connect with: sudo -u postgres psql"
}

# PHP Installation
install_php() {
    log "Installing PHP..."
    
    # Install software-properties-common for add-apt-repository
    apt-get install -y software-properties-common

    # Add PHP PPA for latest version
    add-apt-repository -y ppa:ondrej/php
    apt-get update -y
    
    # Install PHP and common extensions
    apt-get install -y php8.2 php8.2-fpm php8.2-cli php8.2-common \
        php8.2-mysql php8.2-pgsql php8.2-xml php8.2-curl php8.2-zip \
        php8.2-mbstring php8.2-gd php8.2-intl php8.2-bcmath php8.2-json
    
    # Configure PHP-FPM
    sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.2/fpm/php.ini
    sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.2/fpm/php.ini
    
    # Enable and start PHP-FPM
    systemctl enable php8.2-fpm
    systemctl restart php8.2-fpm
    
    success "PHP 8.2 installed successfully"
}

# Redis Installation
install_redis() {
    log "Installing Redis..."
    
    # Install Redis server
    apt-get install -y redis-server
    
    # Configure Redis
    sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
    
    # Enable and start Redis
    systemctl enable redis-server
    systemctl restart redis-server
    
    success "Redis installed successfully"
}

# Docker Installation
install_docker() {
    log "Installing Docker..."
    
    # Install prerequisites
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add current user to docker group (and ubuntu user)
    usermod -aG docker "$USER" || true
    usermod -aG docker ubuntu || true
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    success "Docker installed successfully"
}

# GitLab Runner Installation
install_gitlab_runner() {
    log "Installing GitLab Runner..."
    
    # Add GitLab repository
    curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
    
    # Install GitLab Runner
    apt-get install -y gitlab-runner
    
    # Add ubuntu user to gitlab-runner group
    usermod -aG docker gitlab-runner || true
    usermod -aG docker ubuntu || true
    
    success "GitLab Runner installed successfully"
    log "Register runner with: sudo gitlab-runner register"
}

# Monitoring Stack (Prometheus + Grafana)
install_monitoring() {
    log "Installing monitoring stack..."
    
    # Create monitoring directories
    mkdir -p /opt/monitoring/{prometheus,grafana}
    
    # Install Prometheus
    PROMETHEUS_VERSION="2.45.0"
    cd /tmp
    wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
    cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
    cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /opt/monitoring/prometheus/
    cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /opt/monitoring/prometheus/
    
    # Create Prometheus config
    cat > /opt/monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
    
    # Create Prometheus service
    cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file /opt/monitoring/prometheus/prometheus.yml \\
    --storage.tsdb.path /opt/monitoring/prometheus/data \\
    --web.console.templates=/opt/monitoring/prometheus/consoles \\
    --web.console.libraries=/opt/monitoring/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
    
    # Install Grafana
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update -y
    apt-get install -y grafana
    
    # Enable and start services
    systemctl enable prometheus
    systemctl start prometheus
    systemctl enable grafana-server
    systemctl start grafana-server
    
    success "Monitoring stack installed successfully"
    log "Prometheus: http://localhost:9090"
    log "Grafana: http://localhost:3000 (admin/admin)"
}

# Backup Script Installation
install_backup_script() {
    log "Installing backup script..."
    
    # Create backup directory
    mkdir -p /opt/backups
    
    # Create backup script
    cat > /opt/backups/backup.sh << 'EOF'
#!/bin/bash

# Backup Script
# Configure this script according to your needs

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Backup directories
DIRECTORIES_TO_BACKUP=("/etc" "/home" "/var/www" "/opt")

# Backup databases (uncomment what you need)
# mysqldump -u root -p --all-databases > "$BACKUP_DIR/mysql_$DATE.sql"
# pg_dumpall -U postgres > "$BACKUP_DIR/postgres_$DATE.sql"

# Create backup archive
for dir in "${DIRECTORIES_TO_BACKUP[@]}"; do
    if [[ -d "$dir" ]]; then
        tar -czf "$BACKUP_DIR/$(basename $dir)_$DATE.tar.gz" "$dir"
    fi
done

# Clean old backups
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
EOF
    
    chmod +x /opt/backups/backup.sh
    
    # Create cron job for daily backups at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/backups/backup.sh >> /var/log/backup.log 2>&1") | crontab -
    
    success "Backup script installed successfully"
    log "Backup runs daily at 2 AM"
    log "Backup directory: /opt/backups"
}

# SSL Certificate Setup (Let's Encrypt) - non-interactive via env
install_ssl_cert() {
    log "Installing SSL certificates..."

    # Install Certbot
    apt-get install -y certbot python3-certbot-nginx

    DOMAIN="${DOMAIN:-}"
    LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"

    if [[ -z "${DOMAIN}" || -z "${LETSENCRYPT_EMAIL}" ]]; then
        warning "DOMAIN and LETSENCRYPT_EMAIL env vars are required for non-interactive cert issuance."
        warning "Example: DOMAIN=example.com LETSENCRYPT_EMAIL=admin@example.com ./services.sh ssl"
        return 0
    fi

    # Issue/Install certificate
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "${LETSENCRYPT_EMAIL}" || {
        warning "SSL certificate installation failed. Run manually: certbot --nginx -d ${DOMAIN}"
        return 0
    }

    # Prefer systemd timer over crontab when available
    systemctl enable --now certbot.timer >/dev/null 2>&1 || true

    success "SSL certificate installed for ${DOMAIN}"
}

# Log rotation setup
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/vps-logs << 'EOF'
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data adm
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 `cat /var/run/nginx.pid`
        fi
    endscript
}

/var/log/mysql/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 mysql adm
    postrotate
        if test -x /usr/bin/mysqladmin; then
            /usr/bin/mysqladmin --defaults-file=/etc/mysql/debian.cnf flush-logs
        fi
    endscript
}
EOF
    
    success "Log rotation configured"
}

# Function to install all services
install_all_services() {
    install_mysql
    install_postgresql
    install_php
    install_nvm
    install_redis
    install_docker
    install_gitlab_runner
    install_monitoring
    install_backup_script
    install_ssl_cert
    setup_log_rotation
}

# ============================================================
# NextJS DEPLOYMENT FUNCTIONS
# ============================================================

# NVM Installation (Node Version Manager)
install_nvm() {
    log "Installing NVM (Node Version Manager)..."
    if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    else
        warning "NVM already installed"
    fi

    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

    # Ensure NVM is sourced in both interactive and login shells
    local nvm_source='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    # Add to .bashrc if not already present (interactive shells)
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'NVM_DIR' "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "$nvm_source" >> "$HOME/.bashrc"
        log "Added NVM sourcing to .bashrc"
    fi

    # Add to .profile for login shells (SSH sessions)
    if [[ -f "$HOME/.profile" ]] && ! grep -q 'NVM_DIR' "$HOME/.profile"; then
        echo "" >> "$HOME/.profile"
        echo "$nvm_source" >> "$HOME/.profile"
        log "Added NVM sourcing to .profile"
    elif [[ ! -f "$HOME/.profile" ]]; then
        echo "$nvm_source" > "$HOME/.profile"
        log "Created .profile with NVM sourcing"
    fi

    if ! command -v nvm >/dev/null 2>&1; then
        warning "NVM not available after installation"
        return 1
    fi

    log "Installing Node.js LTS via NVM"
    nvm install --lts
    nvm use --lts
    log "Node version (LTS): $(node --version)"

    # Install global packages
    npm install -g npm@latest pm2 yarn

    success "NVM and Node.js LTS installed successfully"
    success "NVM is now available in both interactive and login shells"
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
        log "No .nvmrc found in $app_path"
        if command -v nvm >/dev/null 2>&1; then
            log "Installing/using latest LTS via NVM"
            nvm install --lts || return 1
            nvm use --lts || return 1
            log "Node version (LTS): $(node --version)"
        else
            log "NVM not available, using system Node.js"
            log "Current Node version: $(node --version)"
        fi
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
    limit_conn_zone \$binary_remote_addr zone=perip:10m;
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

# Install or upgrade to NGINX mainline (>= 1.29.2)
install_nginx_latest() {
    log "Installing NGINX mainline (>= 1.29.2)..."
    local min_version="${NGINX_MIN_VERSION:-1.29.2}"

    apt-get update -y
    apt-get install -y curl gnupg2 ca-certificates lsb-release

    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" \
        > /etc/apt/sources.list.d/nginx.list

    apt-get update -y
    apt-get install -y nginx

    if ! command -v nginx >/dev/null 2>&1; then
        warning "NGINX install failed"
        return 1
    fi

    local current_version
    current_version=$(nginx -v 2>&1 | sed -E 's/^nginx\///')
    if ! printf '%s\n%s\n' "$min_version" "$current_version" | sort -V -C; then
        warning "NGINX version ${current_version} is below ${min_version}"
        warning "Please upgrade NGINX to ${min_version} or later"
        return 1
    fi

    systemctl enable nginx
    systemctl restart nginx
    success "NGINX installed: ${current_version}"
}

# Install Cloudflare SSL certificates
install_cloudflare_ssl_certs() {
    log "Installing Cloudflare SSL certificates..."
    local cert_source="${CERT_SOURCE:-./conf/www.theedgetreatment.com/ssl/cloudflare-origin-fullchain.pem}"
    local key_source="${KEY_SOURCE:-./conf/www.theedgetreatment.com/ssl/key.pem}"
    local cert_dest="/etc/ssl/certs/cloudflare-origin-fullchain.pem"
    local key_dest="/etc/ssl/key.pem"
    mkdir -p /etc/ssl/certs /etc/ssl
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
    local ssl_key="${5:-/etc/ssl/key.pem}"
    
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

# Install NGINX site config from a repo file
install_nginx_site_from_conf() {
    local conf_source="$1"
    local site_name="$2"

    if [[ -z "$conf_source" || -z "$site_name" ]]; then
        warning "Usage: install_nginx_site_from_conf <conf_source> <site_name>"
        return 1
    fi

    site_name="$(basename "$site_name")"
    if [[ "$site_name" == */* ]]; then
        warning "Invalid site name: $site_name"
        return 1
    fi

    if [[ ! -f "$conf_source" ]]; then
        warning "NGINX config source not found: $conf_source"
        return 1
    fi

    log "Installing NGINX site config: $site_name"
    if [[ -f "/etc/nginx/sites-available/${site_name}" ]]; then
        cp "/etc/nginx/sites-available/${site_name}" "/etc/nginx/sites-available/${site_name}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    cp "$conf_source" "/etc/nginx/sites-available/${site_name}"
    if [[ -d "/etc/nginx/sites-enabled/sites-available" ]]; then
        rm -rf "/etc/nginx/sites-enabled/sites-available"
    fi
    ln -sf "/etc/nginx/sites-available/${site_name}" "/etc/nginx/sites-enabled/${site_name}"

    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        success "NGINX site config installed for ${site_name}"
    else
        warning "NGINX config test failed for ${site_name}"
        rm -f "/etc/nginx/sites-enabled/${site_name}"
        return 1
    fi
}

# Deploy NextJS application from EC2 to VPS
deploy_nextjs_app() {
    local app_name="$1"
    local domain="$2"
    local port="$3"
    local ssh_host="${4:-}"
    local remote_path="${5:-/home/ubuntu/current}"
    
    if [[ -z "$app_name" || -z "$domain" || -z "$port" ]]; then
        warning "Usage: deploy_nextjs_app <app_name> <domain> <port> [ssh_host] [remote_path]"
        return 1
    fi

    if [[ -z "$ssh_host" ]]; then
        warning "ssh_host is required (direct edge-prod access is disabled)"
        warning "Usage: deploy_nextjs_app <app_name> <domain> <port> <ssh_host> [remote_path]"
        return 1
    fi

    if [[ "$ssh_host" == "edge-prod" && -z "${ALLOW_EDGE_PROD:-}" ]]; then
        warning "Direct edge-prod access is disabled. Set ALLOW_EDGE_PROD=1 to override."
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
    local error_log
    error_log=$(pm2 info "${app_name}" 2>/dev/null | awk -F': ' '/error log path/{print $2}' | head -1)
    if [[ -n "$error_log" && -f "$error_log" ]]; then
        tail -n 20 "$error_log" 2>/dev/null | grep -qi "error" && warning "⚠ Errors found" || success "✓ No errors"
    else
        success "✓ No errors (no error log found)"
    fi
    
    success "Deployment tests completed"
}

# Migrate www.theedgetreatment.com
migrate_edge_treatment() {
    log "Starting edge_nextjs migration..."
    local app_name="edge_nextjs"
    local domain="theedgetreatment.com"
    local port=3000
    local nginx_conf="/root/vps-setup/conf/www.theedgetreatment.com/nginx/www.theedgetreatment.com.conf"
    local site_name="www.theedgetreatment.com.conf"

    log "Running pre-flight checks..."
    [[ ! -f "/etc/ssl/certs/cloudflare-origin-fullchain.pem" ]] && install_cloudflare_ssl_certs
    [[ ! -f /etc/nginx/nginx.conf.backup ]] && optimize_nginx_global
    install_nginx_site_from_conf "$nginx_conf" "$site_name"
    if [[ -f "/etc/nginx/sites-available/${site_name}" && ! -L "/etc/nginx/sites-enabled/${site_name}" ]]; then
        ln -sf "/etc/nginx/sites-available/${site_name}" "/etc/nginx/sites-enabled/${site_name}"
        log "Symlinked ${site_name} into /etc/nginx/sites-enabled"
        nginx -t 2>/dev/null && systemctl reload nginx || warning "NGINX reload failed after symlink"
    fi

    test_nextjs_deployment "$app_name" "$port"
}

# Function to show available services
show_services() {
    echo "Available services to install:"
    echo "1) tailscale    - Tailscale (optional Tailscale SSH)"
    echo "2) mysql        - MySQL Database Server"
    echo "3) postgresql   - PostgreSQL Database Server"
    echo "4) php          - PHP 8.2 with FPM"
    echo "5) redis        - Redis In-Memory Database"
    echo "6) docker       - Docker Container Runtime"
    echo "7) gitlab-runner - GitLab CI/CD Runner"
    echo "8) monitoring   - Prometheus + Grafana"
    echo "9) backup       - Automated Backup Scripts"
    echo "10) ssl         - Let's Encrypt SSL Certificates"
    echo "11) logs        - Log Rotation Setup"
    echo "12) all         - Install all services"
    echo ""
    echo "NextJS Deployment:"
    echo "13) nvm              - Install NVM + Node.js LTS + npm/pm2/yarn"
    echo "14) nginx-latest     - Install NGINX mainline (>= 1.29.2)"
    echo "15) alias            - Install global vps-services command"
    echo "16) nextjs-nginx     - Optimize NGINX for NextJS"
    echo "17) nextjs-ssl       - Install Cloudflare SSL certificates"
    echo "18) nextjs-deploy    - Deploy NextJS app: <app_name> <domain> <port> <ssh_host> [remote_path]"
    echo "19) nextjs-test      - Test NextJS deployment: <app_name> <port>"
    echo "20) edge-migrate     - Migrate www.theedgetreatment.com (full automation)"
    echo ""
    echo "Usage: ./scripts/services.sh [service_name]"
}

# Main execution
if [[ $# -eq 0 ]]; then
    show_services
    exit 0
fi

SERVICE=$1

case $SERVICE in
    "tailscale")
        install_tailscale
        ;;
    "mysql")
        install_mysql
        ;;
    "postgresql")
        install_postgresql
        ;;
    "php")
        install_php
        ;;
    "redis")
        install_redis
        ;;
    "docker")
        install_docker
        ;;
    "gitlab-runner")
        install_gitlab_runner
        ;;
    "monitoring")
        install_monitoring
        ;;
    "backup")
        install_backup_script
        ;;
    "ssl")
        install_ssl_cert
        ;;
    "logs")
        setup_log_rotation
        ;;
    "all")
        install_all_services
        ;;
    "nvm")
        install_nvm
        ;;
    "nginx-latest")
        install_nginx_latest
        ;;
    "alias")
        install_services_alias
        ;;
    "nextjs-nginx")
        optimize_nginx_global
        ;;
    "nextjs-ssl")
        install_cloudflare_ssl_certs
        ;;
    "nextjs-deploy")
        shift
        deploy_nextjs_app "$@"
        ;;
    "nextjs-test")
        shift
        test_nextjs_deployment "$@"
        ;;
    "edge-migrate")
        migrate_edge_treatment
        ;;
    *)
        echo "Unknown service: $SERVICE"
        show_services
        exit 1
        ;;
esac