#!/bin/bash
set -euo pipefail

fail() {
    logger -p daemon.err -t node-steelgem-healthcheck "$1"
    echo "$1" >&2
    exit 1
}

ok() {
    logger -p daemon.info -t node-steelgem-healthcheck "$1"
    echo "$1"
}

systemctl is-active --quiet nginx || fail "nginx inactive"
systemctl is-active --quiet pm2-appuser || fail "pm2-appuser inactive"

sudo -u appuser -H bash -lc 'cd /home/appuser && export PM2_HOME=/home/appuser/.pm2 && export NVM_DIR=/home/appuser/.nvm && source /home/appuser/.nvm/nvm.sh && pm2 jlist' >/tmp/pm2-jlist.json || fail "pm2 jlist failed"
grep -q '"status":"online"' /tmp/pm2-jlist.json || fail "no online pm2 processes"
rm -f /tmp/pm2-jlist.json

ss -tln | grep -q ':3000 ' || fail 'port 3000 not listening'
ss -tln | grep -q ':3001 ' || fail 'port 3001 not listening'
ss -tln | grep -q ':3002 ' || fail 'port 3002 not listening'

for url in https://detoxnearme.com https://www.theedgetreatment.com https://theforgerecovery.com; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || true)
    [[ "$code" == "200" ]] || fail "$url unhealthy: $code"
done

ok 'all pm2 apps healthy and returning 200'
