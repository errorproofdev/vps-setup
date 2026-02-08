#!/bin/bash
################################################################################
# BASTION DEPLOYMENT ORCHESTRATOR
# 
# Runs on LOCAL MACHINE and orchestrates deployment:
# 1. Pulls code from SOURCE_HOST (source)
# 2. Pushes to DESTINATION_HOST (destination)
# 3. Triggers build/start on DESTINATION_HOST
#
# Configuration Methods:
#   1. Environment variables: SOURCE_HOST, DESTINATION_HOST, SOURCE_PATH, DESTINATION_PATH
#   2. .env file
#   3. Command line: SOURCE_HOST="ip" DESTINATION_HOST="ip" ./deploy-bastion.sh ...
#
# Usage: 
#   ./deploy-bastion.sh <app_name> <domain> <port>
#
# Examples:
#   # Using environment variables
#   SOURCE_HOST="192.168.1.100" DESTINATION_HOST="192.168.1.101" \
#   ./deploy-bastion.sh edge_nextjs theedgetreatment.com 3000
#
#   # Using .env file
#   cp .env.example .env
#   # Edit .env with SOURCE_HOST and DESTINATION_HOST
#   ./deploy-bastion.sh edge_nextjs theedgetreatment.com 3000
#
#   # Using SSH hostnames (with ~/.ssh/config entries)
#   SOURCE_HOST="edge-prod" DESTINATION_HOST="node-steelgem" \
#   ./deploy-bastion.sh edge_nextjs theedgetreatment.com 3000
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-${SCRIPT_DIR}/.env}"

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ $1${NC}"
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

# Function to resolve SSH connection details
# Supports: IP addresses, hostnames, user@host:port format
resolve_ssh_connection() {
    local host_spec="$1"
    local default_user="${2:-ubuntu}"
    local default_port="${3:-22}"
    
    local user="$default_user"
    local host="$host_spec"
    local port="$default_port"
    
    # Parse user@host:port format
    if [[ "$host_spec" == *"@"* ]]; then
        user="${host_spec%@*}"
        host_spec="${host_spec#*@}"
    fi
    
    if [[ "$host_spec" == *":"* ]]; then
        host="${host_spec%:*}"
        port="${host_spec##*:}"
    else
        host="$host_spec"
    fi
    
    echo "$user@$host:$port"
}

# Configuration
SOURCE_HOST="${SOURCE_HOST:-edge-prod}"
DESTINATION_HOST="${DESTINATION_HOST:-node-steelgem}"
SOURCE_PATH="${SOURCE_PATH:-/home/ubuntu/current}"
DESTINATION_PATH="${DESTINATION_PATH:-/var/www/apps}"
TEMP_DIR="/tmp/vps-deploy-$$"

# Cleanup
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Validate arguments
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <app_name> <domain> <port>"
    echo ""
    echo "Configuration via environment variables or .env file:"
    echo "  SOURCE_HOST        - Source server (default: edge-prod)"
    echo "  DESTINATION_HOST   - Destination server (default: node-steelgem)"
    echo "  SOURCE_PATH        - Path on source (default: /home/ubuntu/current)"
    echo "  DESTINATION_PATH   - Path on destination (default: /var/www/apps)"
    echo ""
    echo "Examples:"
    echo "  $0 edge_nextjs theedgetreatment.com 3000"
    echo "  SOURCE_HOST=\"192.168.1.100\" DESTINATION_HOST=\"192.168.1.101\" $0 myapp example.com 3000"
    echo "  SOURCE_HOST=\"edge-prod\" DESTINATION_HOST=\"node-steelgem\" $0 myapp example.com 3000"
    exit 1
fi

APP_NAME="$1"
DOMAIN="$2"
PORT="$3"

# Resolve SSH connections
SOURCE_CONN="$(resolve_ssh_connection "$SOURCE_HOST" "ubuntu" "22")"
DESTINATION_CONN="$(resolve_ssh_connection "$DESTINATION_HOST" "ubuntu" "22")"

log "Starting bastion deployment orchestration"
log "App: $APP_NAME | Domain: $DOMAIN | Port: $PORT"
log "Source: $SOURCE_CONN:$SOURCE_PATH"
log "Destination: $DESTINATION_CONN:$DESTINATION_PATH"

# Step 1: Verify connectivity to both servers
log "Step 1/6: Verifying server connectivity..."
if ! ssh $SOURCE_CONN "echo 'Connected'" > /dev/null 2>&1; then
    error "Cannot connect to $SOURCE_CONN"
    exit 1
fi
success "Connected to $SOURCE_CONN"

if ! ssh $DESTINATION_CONN "echo 'Connected'" > /dev/null 2>&1; then
    error "Cannot connect to $DESTINATION_CONN"
    exit 1
fi
success "Connected to $DESTINATION_CONN"

# Step 2: Pull from source
log "Step 2/6: Pulling code from $SOURCE_CONN..."
mkdir -p "$TEMP_DIR"

ssh $SOURCE_CONN "rm -rf /tmp/app-$APP_NAME && mkdir -p /tmp/app-$APP_NAME"
ssh $SOURCE_CONN "rsync -a --delete --exclude=node_modules --exclude=.git $SOURCE_PATH/ /tmp/app-$APP_NAME/ || [[ \$? -eq 24 ]]"
ssh $SOURCE_CONN "cd /tmp/app-$APP_NAME && tar czf /tmp/app-$APP_NAME.tar.gz ."
scp $SOURCE_CONN:/tmp/app-$APP_NAME.tar.gz "$TEMP_DIR/app.tar.gz"
ssh $SOURCE_CONN "rm -rf /tmp/app-$APP_NAME /tmp/app-$APP_NAME.tar.gz"
success "Code pulled from $SOURCE_CONN"

# Step 3: Extract and verify
log "Step 3/6: Verifying app contents..."
tar tzf "$TEMP_DIR/app.tar.gz" | head -20 > /dev/null
success "App archive is valid"

# Step 4: Push to destination
log "Step 4/6: Creating app directory on $DESTINATION_CONN..."
ssh $DESTINATION_CONN "mkdir -p $DESTINATION_PATH/$APP_NAME"
success "Directory created"

log "Pushing code to $DESTINATION_CONN..."
scp "$TEMP_DIR/app.tar.gz" $DESTINATION_CONN:/tmp/app.tar.gz

# Extract on destination
ssh $DESTINATION_CONN "cd $DESTINATION_PATH/$APP_NAME && tar xzf /tmp/app.tar.gz && rm /tmp/app.tar.gz"
success "Code pushed and extracted on $DESTINATION_CONN"

# Step 5: Start on destination
log "Step 5/6: Starting app on $DESTINATION_CONN..."
ssh $DESTINATION_CONN \
    APP_NAME="$APP_NAME" \
    DESTINATION_PATH="$DESTINATION_PATH" \
    PORT="$PORT" \
    DOMAIN="$DOMAIN" \
    PIPELINE_ENV="${PIPELINE_ENV:-}" \
    /bin/bash << 'EOF'
set -euo pipefail

# Note: This assumes a standard Next.js start script (no ecosystem file).
cd "$DESTINATION_PATH/$APP_NAME"

if [[ -f ".nvmrc" ]]; then
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    nvm install || true
    nvm use || true
fi

if [[ -n "${PIPELINE_ENV:-}" ]]; then
    echo "NEXT_PUBLIC_GITLAB_ENV=$PIPELINE_ENV" >> .env.production
fi

echo "Node.js version:" && node --version
echo "npm version:" && npm --version

echo "Installing dependencies..."
if ! npm ci --silent --ignore-scripts; then
    echo ""
    echo "❌ ERROR: npm ci failed"
    echo ""
    echo "Common causes:"
    echo "  1. package-lock.json is out of sync with package.json"
    echo "  2. package-lock.json is missing"
    echo "  3. Incompatible npm/Node.js version"
    echo ""
    echo "To fix lockfile drift:"
    echo "  1. Run 'npm install' locally"
    echo "  2. Verify the changes to package-lock.json"
    echo "  3. Commit both package.json and package-lock.json"
    echo "  4. Push your changes"
    echo ""
    echo "Current environment:"
    echo "  Node: $(node --version)"
    echo "  npm: $(npm --version)"
    echo ""
    exit 1
fi

if [[ ! -d ".next" ]]; then
    echo ""
    echo "❌ ERROR: Missing .next build output"
    echo "This deploy assumes build artifacts are already present."
    echo "Ensure the build output is included in the copy."
    echo ""
    exit 1
fi

if command -v pm2 >/dev/null 2>&1; then
    echo "📋 Checking for existing PM2 process $APP_NAME on port $PORT..."
    OLD_PM2_ID=$(pm2 id "$APP_NAME" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)

    if [[ -n "$OLD_PM2_ID" ]]; then
        echo "🔍 Found existing PM2 process: $APP_NAME (ID: $OLD_PM2_ID)"
        echo "🚀 Starting new instance from updated release..."
        pm2 start npm --name "$APP_NAME" -- run start -- -p "$PORT"
        echo "✅ New instance started"
        echo "🗑️  Deleting old PM2 process entry (ID: $OLD_PM2_ID)..."
        pm2 delete "$OLD_PM2_ID"
        echo "✅ Old process removed from PM2"
        pm2 reload "$APP_NAME" --update-env
        echo "✅ Application reloaded with new environment variables"
    else
        echo "ℹ️  No existing PM2 process found - starting fresh instance"
        pm2 start npm --name "$APP_NAME" -- run start -- -p "$PORT"
        echo "✅ Application started successfully"
    fi

    pm2 save
    echo "✅ PM2 configuration saved"
else
    echo "⚠️ pm2 not found; deployment failed"
    exit 1
fi

if [[ -n "$DOMAIN" ]]; then
    if ! grep -R "server_name" /etc/nginx/sites-enabled 2>/dev/null | grep -q "$DOMAIN"; then
        echo "⚠️  Warning: Nginx server_name for $DOMAIN not found in /etc/nginx/sites-enabled"
    elif ! grep -R "proxy_pass http://127.0.0.1:$PORT" /etc/nginx/sites-enabled 2>/dev/null | grep -q "$DOMAIN"; then
        echo "⚠️  Warning: Nginx config for $DOMAIN may not be proxying to port $PORT"
    fi
fi
EOF
success "Build and start complete on $DESTINATION_CONN"

# Step 6: Verify deployment
log "Step 6/6: Verifying deployment..."
sleep 5

if ssh $DESTINATION_CONN "curl -f http://localhost:$PORT > /dev/null 2>&1"; then
    success "✓ Application is responding on port $PORT"
else
    warning "⚠ Application on port $PORT not responding yet (may still be starting)"
fi

# Show status
log "Final Status:"
ssh $DESTINATION_CONN "pm2 info $APP_NAME 2>/dev/null || echo 'PM2 process not yet available'"

success "═══════════════════════════════════════════════════════════"
success "✓ Deployment Complete!"
success "═══════════════════════════════════════════════════════════"
success ""
success "App:      $APP_NAME"
success "Location: $DESTINATION_CONN:$DESTINATION_PATH/$APP_NAME"
success "Port:     $PORT"
success "URL:      https://$DOMAIN"
success ""
success "Next steps:"
success "  1. Verify in browser: https://$DOMAIN"
success "  2. Check logs: ssh $(echo $DESTINATION_CONN | cut -d: -f1) 'pm2 logs $APP_NAME'"
success "  3. Check status: ssh $(echo $DESTINATION_CONN | cut -d: -f1) 'pm2 status'"
success ""
