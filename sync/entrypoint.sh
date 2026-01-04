#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/logs /data/state

# Run once on start (so you don't wait until 2am)
echo "[ledger-sync] Initial sync on startup..."
/app/sync_once.sh >> /data/logs/sync.log 2>&1 || true

echo "[ledger-sync] Starting scheduler..."
exec /usr/local/bin/supercronic /app/crontab
