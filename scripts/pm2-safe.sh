#!/bin/bash
# Purpose: Safely manage PM2 as non-root appuser with correct cwd and environment
set -euo pipefail

APP_USER="${APP_USER:-appuser}"
APP_HOME="${APP_HOME:-/home/appuser}"
PM2_HOME="${PM2_HOME:-/home/appuser/.pm2}"
NVM_DIR="${NVM_DIR:-/home/appuser/.nvm}"
DEFAULT_CONFIG="${DEFAULT_CONFIG:-/home/appuser/ecosystem.config.js}"

log() {
    echo -e "\033[0;34m[$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $*"
}

success() {
    echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] ✓\033[0m $*"
}

warning() {
    echo -e "\033[0;33m[$(date '+%Y-%m-%d %H:%M:%S')] ⚠\033[0m $*"
}

error() {
    echo -e "\033[0;31m[$(date '+%Y-%m-%d %H:%M:%S')] ✗\033[0m $*"
}

usage() {
    cat << 'EOF'
Usage: ./scripts/pm2-safe.sh <action> [target_or_config]

Actions:
  list                      Show PM2 process list
  status                    Alias for list
  resurrect                 Resurrect from PM2 dump
  save                      Save PM2 dump
  start [config]            Start ecosystem config (default: /home/appuser/ecosystem.config.js)
  restart [target]          Restart target (default: all)
  reload [target]           Reload target (default: all)
  stop [target]             Stop target (default: all)
  delete [target]           Delete target (default: all)
  logs [target]             Show logs (default: all)
  describe <target>         Describe one process
  startup                   Configure PM2 systemd startup for appuser
  startup-status            Show pm2-appuser systemd status
  healthcheck               Check PM2 list + ports 3000-3002 + local curl checks

Environment overrides:
  APP_USER, APP_HOME, PM2_HOME, NVM_DIR, DEFAULT_CONFIG

Examples:
  ./scripts/pm2-safe.sh list
  ./scripts/pm2-safe.sh restart all
  ./scripts/pm2-safe.sh start /home/appuser/ecosystem.config.js
  ./scripts/pm2-safe.sh save
EOF
}

run_as_appuser() {
    local cmd="$1"

    sudo -u "$APP_USER" -H bash -lc "
        set -euo pipefail
        cd \"$APP_HOME\"
        export PM2_HOME=\"$PM2_HOME\"
        export NVM_DIR=\"$NVM_DIR\"
        [ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\"
        $cmd
    "
}

run_healthcheck() {
    log "Running PM2 healthcheck with safe context..."
    run_as_appuser "pm2 list"

    log "Checking app listeners on ports 3000-3002..."
    ss -tlnp | grep -E ':3000|:3001|:3002' || warning "No listeners found on 3000-3002"

    log "Checking local reverse-proxy responses..."
    curl -s -o /dev/null -w "detox:%{http_code}\n" https://detoxnearme.com || true
    curl -s -o /dev/null -w "edge:%{http_code}\n" https://www.theedgetreatment.com || true
    curl -s -o /dev/null -w "forge:%{http_code}\n" https://theforgerecovery.com || true

    success "Healthcheck complete"
}

main() {
    local action="${1:-}"
    local arg="${2:-}"

    if [[ -z "$action" ]]; then
        usage
        return 1
    fi

    case "$action" in
        list|status)
            run_as_appuser "pm2 list"
            ;;
        resurrect)
            run_as_appuser "pm2 resurrect"
            ;;
        save)
            run_as_appuser "pm2 save"
            ;;
        start)
            local config="${arg:-$DEFAULT_CONFIG}"
            run_as_appuser "pm2 start \"$config\""
            ;;
        restart|reload|stop|delete|logs)
            local target="${arg:-all}"
            run_as_appuser "pm2 $action \"$target\""
            ;;
        describe)
            if [[ -z "$arg" ]]; then
                error "describe requires a target process name or id"
                return 1
            fi
            run_as_appuser "pm2 describe \"$arg\""
            ;;
        startup)
            run_as_appuser "pm2 startup systemd -u \"$APP_USER\" --hp \"$APP_HOME\""
            warning "If PM2 prints a sudo env PATH command, run it exactly as shown."
            ;;
        startup-status)
            sudo systemctl status "pm2-$APP_USER" --no-pager -n 40 || true
            ;;
        healthcheck)
            run_healthcheck
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            error "Unknown action: $action"
            usage
            return 1
            ;;
    esac
}

main "$@"
