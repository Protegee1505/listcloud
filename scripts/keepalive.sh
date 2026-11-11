#!/usr/bin/env bash
# ==============================================================================
# ListCloud — 24/7 Keep-Alive & Watchdog Service
# Pings external URL and local /ping endpoint to prevent cloud container sleep
# ==============================================================================

INTERVAL="${KEEPALIVE_INTERVAL:-480}"
PORT="${PORT:-${HTTP_PORT:-7860}}"

while true; do
  sleep "${INTERVAL}"

  # 1. Local heartbeat check
  curl -fsS "http://127.0.0.1:${PORT}/ping" >/dev/null 2>&1 || true

  # 2. External public URL keep-alive (wakes up Render / Koyeb / HF Spaces routers)
  if [ -n "${KEEPALIVE_URL}" ]; then
    PING_TARGET="${KEEPALIVE_URL%/}/ping"
    curl -fsSL -A "ListCloud-KeepAlive/1.0" "${PING_TARGET}" >/dev/null 2>&1 || true
  elif [ -n "${SITE_URL}" ] && [[ "${SITE_URL}" == http* ]]; then
    PING_TARGET="${SITE_URL%/}/ping"
    curl -fsSL -A "ListCloud-KeepAlive/1.0" "${PING_TARGET}" >/dev/null 2>&1 || true
  elif [ -n "${SPACE_HOST}" ]; then
    # Hugging Face Spaces automatic public hostname variable
    curl -fsSL -A "ListCloud-KeepAlive/1.0" "https://${SPACE_HOST}/ping" >/dev/null 2>&1 || true
  elif [ -n "${RENDER_EXTERNAL_URL}" ]; then
    # Render automatic external URL variable
    curl -fsSL -A "ListCloud-KeepAlive/1.0" "${RENDER_EXTERNAL_URL%/}/ping" >/dev/null 2>&1 || true
  elif [ -n "${KOYEB_PUBLIC_DOMAIN}" ]; then
    # Koyeb automatic public domain variable
    curl -fsSL -A "ListCloud-KeepAlive/1.0" "https://${KOYEB_PUBLIC_DOMAIN}/ping" >/dev/null 2>&1 || true
  fi
done
