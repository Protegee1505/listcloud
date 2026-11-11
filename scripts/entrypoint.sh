#!/usr/bin/env bash
set -e

umask "${UMASK:-022}"

DATA_DIR="/opt/openlist/data"
BINARY_PATH="/opt/openlist/openlist"

echo "============================================================"
echo "  ListCloud — Free Cloud OpenList Runtime"
echo "============================================================"

mkdir -p "${DATA_DIR}" "${DATA_DIR}/temp" "${DATA_DIR}/log"

# ------------------------------------------------------------------------------
# 1. Optional: custom OpenList build (fork / patched binary)
# ------------------------------------------------------------------------------
if [ -n "${CUSTOM_BINARY_URL}" ]; then
  echo "[ListCloud] Custom OpenList build requested: ${CUSTOM_BINARY_URL}"
  case "${CUSTOM_BINARY_URL}" in
    *.tar.gz|*.tgz)
      if curl -fsSL "${CUSTOM_BINARY_URL}" -o /tmp/custom-openlist.tar.gz; then
        tar -xzf /tmp/custom-openlist.tar.gz -C /opt/openlist
        chmod +x "${BINARY_PATH}" || true
        rm -f /tmp/custom-openlist.tar.gz
        echo "[ListCloud] Custom OpenList archive extracted."
      else
        echo "[ListCloud] WARNING: custom binary download failed; using bundled OpenList."
      fi
      ;;
    *)
      if curl -fsSL "${CUSTOM_BINARY_URL}" -o "${BINARY_PATH}.tmp"; then
        chmod +x "${BINARY_PATH}.tmp"
        mv "${BINARY_PATH}.tmp" "${BINARY_PATH}"
        echo "[ListCloud] Custom OpenList binary installed."
      else
        echo "[ListCloud] WARNING: custom binary download failed; using bundled OpenList."
      fi
      ;;
  esac
fi

# ------------------------------------------------------------------------------
# 2. Optional: custom frontend dist (custom UI theme / build)
# ------------------------------------------------------------------------------
if [ -n "${CUSTOM_DIST_URL}" ]; then
  echo "[ListCloud] Downloading custom frontend dist..."
  if curl -fsSL "${CUSTOM_DIST_URL}" -o /tmp/custom-dist.tar.gz; then
    rm -rf /opt/openlist/custom/dist
    mkdir -p /opt/openlist/custom/dist
    tar -xzf /tmp/custom-dist.tar.gz -C /opt/openlist/custom/dist
    rm -f /tmp/custom-dist.tar.gz
    if [ -f "${DATA_DIR}/config.json" ]; then
      jq '.dist_dir = "/opt/openlist/custom/dist"' "${DATA_DIR}/config.json" > /tmp/config.json \
        && mv /tmp/config.json "${DATA_DIR}/config.json"
    else
      echo '{"dist_dir":"/opt/openlist/custom/dist"}' > "${DATA_DIR}/config.json"
    fi
    echo "[ListCloud] Custom frontend mounted (dist_dir)."
  else
    echo "[ListCloud] WARNING: custom dist download failed; using bundled UI."
  fi
fi

# ------------------------------------------------------------------------------
# 3. Public port (Render sets PORT, Docker users can set it too)
# ------------------------------------------------------------------------------
export HTTP_PORT="${PORT:-${HTTP_PORT:-10000}}"
export ADDR="0.0.0.0"
echo "[ListCloud] HTTP server will listen on 0.0.0.0:${HTTP_PORT}"

# ------------------------------------------------------------------------------
# 4. Database
#    DATABASE_URL (Postgres) -> passed straight to OpenList as DB_DSN,
#    which avoids parsing passwords with special characters.
# ------------------------------------------------------------------------------
if [ -n "${DATABASE_URL}" ]; then
  case "${DATABASE_URL}" in
    postgres://*|postgresql://*)
      export DB_TYPE="postgres"
      export DB_DSN="${DATABASE_URL}"
      echo "[ListCloud] Using external PostgreSQL database."
      ;;
    *)
      echo "[ListCloud] WARNING: only postgres:// DATABASE_URL is supported; using SQLite."
      unset DATABASE_URL
      ;;
  esac
fi

if [ -z "${DATABASE_URL}" ]; then
  echo "[ListCloud] Using SQLite at ${DATA_DIR}/data.db"
  # Restore last cloud snapshot (if SYNC_MODE is configured)
  /opt/openlist/scripts/db-sync.sh restore || true
fi

# ------------------------------------------------------------------------------
# 5. Optional Aria2 offline downloader (disabled on 512 MB free instances)
# ------------------------------------------------------------------------------
if [ "${ENABLE_ARIA2}" = "true" ] && command -v aria2c >/dev/null 2>&1; then
  echo "[ListCloud] Starting Aria2 RPC service..."
  mkdir -p "${DATA_DIR}/temp/aria2"
  aria2c --conf-path=/opt/openlist/aria2/aria2.conf \
         --rpc-secret="${ARIA2_SECRET:-listcloud_aria2_secret}" \
         --daemon=true || true
fi

# ------------------------------------------------------------------------------
# 6. First-run admin provisioning (optional)
#    If ADMIN_PASSWORD is set, create the admin account + site title through
#    OpenList's public setup API once the server is reachable.
#    If it is empty, the browser shows OpenList's own setup wizard instead.
# ------------------------------------------------------------------------------
provision_admin() {
  for _ in $(seq 1 90); do
    if curl -fsS "http://127.0.0.1:${HTTP_PORT}/ping" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  INIT_JSON=""
  for _ in $(seq 1 30); do
    if INIT_JSON=$(curl -fsS "http://127.0.0.1:${HTTP_PORT}/api/public/init_status" 2>/dev/null); then
      break
    fi
    sleep 2
  done

  INITIALIZED=$(printf '%s' "${INIT_JSON}" | jq -r '.data.initialized // false' 2>/dev/null || echo "false")
  if [ "${INITIALIZED}" = "true" ]; then
    echo "[ListCloud] Instance already initialized; ADMIN_PASSWORD is not re-applied."
    return 0
  fi

  echo "[ListCloud] Creating admin account from environment..."
  BODY=$(jq -n \
    --arg u "${ADMIN_USERNAME:-admin}" \
    --arg p "${ADMIN_PASSWORD}" \
    --arg t "${CUSTOM_TITLE:-}" \
    '{username:$u, password:$p}
     + (if $t != "" then {site_title:$t} else {} end)')

  if curl -fsS -X POST "http://127.0.0.1:${HTTP_PORT}/api/public/init/setup" \
       -H "Content-Type: application/json" -d "${BODY}" >/dev/null 2>&1; then
    echo "[ListCloud] Admin ready. Username: ${ADMIN_USERNAME:-admin}"
  else
    echo "[ListCloud] WARNING: automatic admin setup failed (password must be 4+ characters)."
    echo "[ListCloud] Open the site URL and finish the built-in setup wizard."
  fi
}

if [ -n "${ADMIN_PASSWORD}" ]; then
  provision_admin &
else
  echo "[ListCloud] ADMIN_PASSWORD not set: complete the setup wizard on first visit."
fi

# ------------------------------------------------------------------------------
# 7. Background services
# ------------------------------------------------------------------------------
if [ -z "${DATABASE_URL}" ] && [ "${SYNC_MODE:-none}" != "none" ]; then
  echo "[ListCloud] Starting state backup daemon (SYNC_MODE=${SYNC_MODE})."
  /opt/openlist/scripts/db-sync.sh daemon &
fi

/opt/openlist/scripts/keepalive.sh &

echo "[ListCloud] Starting OpenList..."
exec "${BINARY_PATH}" server --data "${DATA_DIR}" --no-prefix
