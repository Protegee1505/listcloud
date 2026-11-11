#!/usr/bin/env bash
set -e

umask "${UMASK:-022}"

DATA_DIR="/opt/openlist/data"
CONFIG_FILE="${DATA_DIR}/config.json"
BINARY_PATH="/opt/openlist/openlist"

echo "============================================================"
echo "  ListCloud — Free 24/7 Cloud OpenList Runtime"
echo "============================================================"

mkdir -p "${DATA_DIR}" "${DATA_DIR}/temp" "${DATA_DIR}/log"

# 1. Support Custom OpenList Binary or Fork
if [ -n "${CUSTOM_BINARY_URL}" ]; then
  echo "[ListCloud] Custom OpenList binary URL detected: ${CUSTOM_BINARY_URL}"
  if curl -fsSL "${CUSTOM_BINARY_URL}" -o /tmp/custom_openlist; then
    if file /tmp/custom_openlist 2>/dev/null | grep -qi "gzip\|tar\|archive" || [[ "${CUSTOM_BINARY_URL}" == *.tar.gz ]]; then
      tar -xzf /tmp/custom_openlist -C /opt/openlist
    else
      mv /tmp/custom_openlist "${BINARY_PATH}"
    fi
    chmod +x "${BINARY_PATH}"
    rm -f /tmp/custom_openlist
    echo "[ListCloud] Custom OpenList binary installed successfully."
  else
    echo "[ListCloud] WARNING: Failed to download custom binary; falling back to built-in OpenList."
  fi
fi

# 2. Support Custom Frontend Dist (Custom OpenList UI build)
if [ -n "${CUSTOM_DIST_URL}" ]; then
  echo "[ListCloud] Downloading custom frontend dist from ${CUSTOM_DIST_URL}..."
  mkdir -p /opt/openlist/custom/dist
  if curl -fsSL "${CUSTOM_DIST_URL}" -o /tmp/custom_dist.tar.gz; then
    tar -xzf /tmp/custom_dist.tar.gz -C /opt/openlist/custom/dist
    rm -f /tmp/custom_dist.tar.gz
    export DIST_DIR="/opt/openlist/custom/dist"
    echo "[ListCloud] Custom frontend dist mounted at ${DIST_DIR}"
  fi
fi

# 3. Map Cloud PaaS Dynamic PORT (Hugging Face=7860, Render=10000, Koyeb=8000, Default=7860)
ACTIVE_PORT="${PORT:-${HTTP_PORT:-7860}}"
export HTTP_PORT="${ACTIVE_PORT}"
export ADDR="0.0.0.0"
echo "[ListCloud] Binding HTTP Server on 0.0.0.0:${HTTP_PORT}"

# 4. Auto-parse DATABASE_URL (Neon.tech / Render / Supabase / Aiven Free PostgreSQL or MySQL)
if [ -n "${DATABASE_URL}" ]; then
  echo "[ListCloud] External DATABASE_URL detected — configuring durable cloud database..."
  PROTO=$(echo "${DATABASE_URL}" | sed -e 's,^\(.*://\).*,\1,g')
  case "${PROTO}" in
    postgres://*|postgresql://*)
      export DB_TYPE="postgres"
      export DB_SSL_MODE="${DB_SSL_MODE:-require}"
      ;;
    mysql://*)
      export DB_TYPE="mysql"
      ;;
  esac

  # Parse user, password, host, port, dbname from DATABASE_URL if individual DB_* vars aren't set
  NO_PROTO="${DATABASE_URL#${PROTO}}"
  USERPASS="${NO_PROTO%%@*}"
  HOSTPATH="${NO_PROTO#*@}"
  HOSTPORT="${HOSTPATH%%/*}"
  DBNAME_RAW="${HOSTPATH#*/}"
  DBNAME_CLEAN="${DBNAME_RAW%%\?*}"

  export DB_USER="${DB_USER:-${USERPASS%%:*}}"
  export DB_PASS="${DB_PASS:-${USERPASS#*:}}"
  if [[ "${HOSTPORT}" == *:* ]]; then
    export DB_HOST="${DB_HOST:-${HOSTPORT%%:*}}"
    export DB_PORT="${DB_PORT:-${HOSTPORT#*:}}"
  else
    export DB_HOST="${DB_HOST:-${HOSTPORT}}"
    export DB_PORT="${DB_PORT:-5432}"
  fi
  export DB_NAME="${DB_NAME:-${DBNAME_CLEAN}}"
  echo "[ListCloud] Connected to external ${DB_TYPE} database (${DB_HOST}:${DB_PORT}/${DB_NAME})"
else
  echo "[ListCloud] Using local SQLite database (${DATA_DIR}/data.db)"
  # Restore SQLite backup from cloud storage (HF Dataset / GitHub / WebDAV) if configured
  /opt/openlist/scripts/db-sync.sh restore || true
fi

# 5. Pre-generate or update config.json with cloud port & custom settings
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[ListCloud] Generating initial config.json..."
  cat > "${CONFIG_FILE}" <<EOF
{
  "force": false,
  "site_url": "${SITE_URL:-}",
  "cdn": "${CDN_URL:-}",
  "jwt_secret": "${JWT_SECRET:-$(openssl rand -hex 8)}",
  "token_expires_in": ${TOKEN_EXPIRES_IN:-48},
  "database": {
    "type": "${DB_TYPE:-sqlite3}",
    "host": "${DB_HOST:-}",
    "port": ${DB_PORT:-0},
    "user": "${DB_USER:-}",
    "password": "${DB_PASS:-}",
    "name": "${DB_NAME:-}",
    "db_file": "${DATA_DIR}/data.db",
    "table_prefix": "${DB_TABLE_PREFIX:-x_}",
    "ssl_mode": "${DB_SSL_MODE:-}"
  },
  "scheme": {
    "address": "0.0.0.0",
    "http_port": ${HTTP_PORT},
    "https_port": -1,
    "force_https": false
  },
  "temp_dir": "${DATA_DIR}/temp",
  "bleve_dir": "${DATA_DIR}/bleve",
  "dist_dir": "${DIST_DIR:-}",
  "log": {
    "enable": true,
    "name": "${DATA_DIR}/log/log.log",
    "max_size": 50,
    "max_backups": 5,
    "max_age": 14
  },
  "delayed_start": ${DELAYED_START:-0},
  "max_connections": ${MAX_CONNECTIONS:-0},
  "max_concurrency": ${MAX_CONCURRENCY:-64}
}
EOF
else
  # Ensure http_port in existing config.json matches the cloud provider's $PORT
  TMP_CFG=$(mktemp)
  jq --argjson port "${HTTP_PORT}" '.scheme.http_port = $port' "${CONFIG_FILE}" > "${TMP_CFG}" && mv "${TMP_CFG}" "${CONFIG_FILE}"
fi

# 6. Start Aria2 daemon if enabled
if [ "${ENABLE_ARIA2}" = "true" ] && command -v aria2c >/dev/null 2>&1; then
  echo "[ListCloud] Starting Aria2 RPC service..."
  aria2c --conf-path=/opt/openlist/aria2/aria2.conf \
         --rpc-secret="${ARIA2_SECRET:-listcloud_aria2_secret}" \
         --daemon=true
fi

# 7. Set Admin Password & Custom Branding on First Boot / Env Override
if [ -n "${ADMIN_PASSWORD}" ]; then
  echo "[ListCloud] Applying ADMIN_PASSWORD from environment..."
  "${BINARY_PATH}" admin set "${ADMIN_PASSWORD}" --data "${DATA_DIR}" >/dev/null 2>&1 || true
  echo "[ListCloud] Admin credentials ready -> Username: ${ADMIN_USERNAME:-admin}"
fi

# Apply custom site title, logo, custom CSS/head via SQLite if using local SQLite
if [ "${DB_TYPE:-sqlite3}" = "sqlite3" ] && [ -f "${DATA_DIR}/data.db" ]; then
  if [ -n "${ADMIN_USERNAME}" ] && [ "${ADMIN_USERNAME}" != "admin" ]; then
    sqlite3 "${DATA_DIR}/data.db" "UPDATE x_users SET username='${ADMIN_USERNAME}' WHERE id=1;" 2>/dev/null || true
  fi
  if [ -n "${CUSTOM_TITLE}" ]; then
    sqlite3 "${DATA_DIR}/data.db" "UPDATE x_setting_items SET value='${CUSTOM_TITLE}' WHERE key='site_title';" 2>/dev/null || true
  fi
  if [ -n "${CUSTOM_LOGO}" ]; then
    sqlite3 "${DATA_DIR}/data.db" "UPDATE x_setting_items SET value='${CUSTOM_LOGO}' WHERE key='logo';" 2>/dev/null || true
  fi
  if [ -n "${CUSTOM_CSS}" ]; then
    sqlite3 "${DATA_DIR}/data.db" "UPDATE x_setting_items SET value='${CUSTOM_CSS}' WHERE key='customize_head';" 2>/dev/null || true
  fi
fi

# 8. Start Background Cloud State Sync Daemon (for SQLite -> HF Dataset / Git / WebDAV)
if [ -z "${DATABASE_URL}" ] && [ "${SYNC_MODE:-none}" != "none" ]; then
  echo "[ListCloud] Starting automatic SQLite cloud backup daemon (mode: ${SYNC_MODE})..."
  /opt/openlist/scripts/db-sync.sh daemon &
fi

# 9. Start 24/7 Keep-Alive Watchdog Daemon
/opt/openlist/scripts/keepalive.sh &

echo "[ListCloud] Launching OpenList Server (--no-prefix)..."
exec "${BINARY_PATH}" server --data "${DATA_DIR}" --no-prefix
