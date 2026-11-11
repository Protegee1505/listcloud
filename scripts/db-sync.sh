#!/usr/bin/env bash
# ==============================================================================
# ListCloud — Zero-Credit-Card Cloud Persistence Sync Engine
# Keeps SQLite (data.db) and config.json safe across container rebuilds using:
#   1. Hugging Face Private Dataset (SYNC_MODE=hf)
#   2. Private GitHub Repository (SYNC_MODE=github)
#   3. Any WebDAV Cloud Storage (SYNC_MODE=webdav)
# ==============================================================================
set -e

ACTION="${1:-daemon}"
DATA_DIR="/opt/openlist/data"
BACKUP_DIR="/opt/openlist/backup"
SYNC_MODE="${SYNC_MODE:-none}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"
ARCHIVE_NAME="listcloud-state.tar.gz"

mkdir -p "${BACKUP_DIR}"

pack_state() {
  if [ ! -f "${DATA_DIR}/data.db" ]; then
    return 1
  fi
  # Perform safe online SQLite backup before archiving
  sqlite3 "${DATA_DIR}/data.db" ".backup '${BACKUP_DIR}/data.db.bak'" 2>/dev/null || cp "${DATA_DIR}/data.db" "${BACKUP_DIR}/data.db.bak"
  cp "${DATA_DIR}/config.json" "${BACKUP_DIR}/config.json.bak" 2>/dev/null || true
  tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "${BACKUP_DIR}" data.db.bak config.json.bak 2>/dev/null
}

unpack_state() {
  if [ -f "${BACKUP_DIR}/${ARCHIVE_NAME}" ]; then
    tar -xzf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "${BACKUP_DIR}"
    if [ -f "${BACKUP_DIR}/data.db.bak" ]; then
      mv "${BACKUP_DIR}/data.db.bak" "${DATA_DIR}/data.db"
      echo "[DB-Sync] Restored SQLite database (${DATA_DIR}/data.db)"
    fi
    if [ -f "${BACKUP_DIR}/config.json.bak" ] && [ ! -f "${DATA_DIR}/config.json" ]; then
      mv "${BACKUP_DIR}/config.json.bak" "${DATA_DIR}/config.json"
      echo "[DB-Sync] Restored config.json"
    fi
  fi
}

restore_hf() {
  # Requires HF_TOKEN and HF_DATASET_REPO (e.g. username/listcloud-backup)
  if [ -z "${HF_TOKEN}" ] || [ -z "${HF_DATASET_REPO}" ]; then
    echo "[DB-Sync] HF_TOKEN or HF_DATASET_REPO not set; skipping HF restore."
    return 0
  fi
  echo "[DB-Sync] Checking Hugging Face Dataset (${HF_DATASET_REPO}) for state backup..."
  URL="https://huggingface.co/datasets/${HF_DATASET_REPO}/resolve/main/${ARCHIVE_NAME}"
  if curl -fsSL -H "Authorization: Bearer ${HF_TOKEN}" "${URL}" -o "${BACKUP_DIR}/${ARCHIVE_NAME}" 2>/dev/null; then
    unpack_state
  else
    echo "[DB-Sync] No existing backup found in ${HF_DATASET_REPO} (fresh instance)."
  fi
}

backup_hf() {
  if [ -z "${HF_TOKEN}" ] || [ -z "${HF_DATASET_REPO}" ]; then
    return 0
  fi
  pack_state || return 0
  WORK_REPO="${BACKUP_DIR}/hf-repo"
  rm -rf "${WORK_REPO}"
  if git clone --depth 1 "https://user:${HF_TOKEN}@huggingface.co/datasets/${HF_DATASET_REPO}" "${WORK_REPO}" >/dev/null 2>&1; then
    cp "${BACKUP_DIR}/${ARCHIVE_NAME}" "${WORK_REPO}/${ARCHIVE_NAME}"
    cd "${WORK_REPO}"
    git config user.name "ListCloud Bot"
    git config user.email "bot@listcloud.local"
    git add "${ARCHIVE_NAME}"
    if ! git diff --cached --quiet; then
      git commit -m "chore(backup): sync OpenList state $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >/dev/null 2>&1
      git push origin main >/dev/null 2>&1 && echo "[DB-Sync] Backed up state to HF Dataset ${HF_DATASET_REPO}"
    fi
  fi
}

restore_github() {
  # Requires GITHUB_TOKEN and GITHUB_BACKUP_REPO (e.g. username/listcloud-state)
  if [ -z "${GITHUB_TOKEN}" ] || [ -z "${GITHUB_BACKUP_REPO}" ]; then
    echo "[DB-Sync] GITHUB_TOKEN or GITHUB_BACKUP_REPO not set; skipping GitHub restore."
    return 0
  fi
  echo "[DB-Sync] Restoring state from GitHub repo ${GITHUB_BACKUP_REPO}..."
  WORK_REPO="${BACKUP_DIR}/gh-repo"
  rm -rf "${WORK_REPO}"
  if git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_BACKUP_REPO}.git" "${WORK_REPO}" >/dev/null 2>&1; then
    if [ -f "${WORK_REPO}/${ARCHIVE_NAME}" ]; then
      cp "${WORK_REPO}/${ARCHIVE_NAME}" "${BACKUP_DIR}/${ARCHIVE_NAME}"
      unpack_state
    fi
  fi
}

backup_github() {
  if [ -z "${GITHUB_TOKEN}" ] || [ -z "${GITHUB_BACKUP_REPO}" ]; then
    return 0
  fi
  pack_state || return 0
  WORK_REPO="${BACKUP_DIR}/gh-repo"
  if [ ! -d "${WORK_REPO}/.git" ]; then
    rm -rf "${WORK_REPO}"
    git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_BACKUP_REPO}.git" "${WORK_REPO}" >/dev/null 2>&1 || return 0
  fi
  cp "${BACKUP_DIR}/${ARCHIVE_NAME}" "${WORK_REPO}/${ARCHIVE_NAME}"
  cd "${WORK_REPO}"
  git config user.name "ListCloud Backup"
  git config user.email "backup@listcloud.local"
  git add "${ARCHIVE_NAME}"
  if ! git diff --cached --quiet; then
    git commit -m "chore(state): auto-sync $(date -u +'%Y-%m-%dT%H:%M:%SZ')" >/dev/null 2>&1
    git push origin HEAD >/dev/null 2>&1 && echo "[DB-Sync] State synced to GitHub (${GITHUB_BACKUP_REPO})"
  fi
}

restore_webdav() {
  if [ -z "${WEBDAV_URL}" ] || [ -z "${WEBDAV_USER}" ] || [ -z "${WEBDAV_PASSWORD}" ]; then
    return 0
  fi
  echo "[DB-Sync] Checking WebDAV (${WEBDAV_URL}) for existing backup..."
  TARGET="${WEBDAV_URL%/}/${ARCHIVE_NAME}"
  if curl -fsSL -u "${WEBDAV_USER}:${WEBDAV_PASSWORD}" "${TARGET}" -o "${BACKUP_DIR}/${ARCHIVE_NAME}" 2>/dev/null; then
    unpack_state
  else
    echo "[DB-Sync] No remote WebDAV archive found yet (fresh start)."
  fi
}

backup_webdav() {
  if [ -z "${WEBDAV_URL}" ] || [ -z "${WEBDAV_USER}" ] || [ -z "${WEBDAV_PASSWORD}" ]; then
    return 0
  fi
  pack_state || return 0
  TARGET="${WEBDAV_URL%/}/${ARCHIVE_NAME}"
  if curl -fsSL -u "${WEBDAV_USER}:${WEBDAV_PASSWORD}" -T "${BACKUP_DIR}/${ARCHIVE_NAME}" "${TARGET}" >/dev/null 2>&1; then
    echo "[DB-Sync] State uploaded to WebDAV (${TARGET})"
  fi
}

run_restore() {
  case "${SYNC_MODE}" in
    hf) restore_hf ;;
    github) restore_github ;;
    webdav) restore_webdav ;;
    *) ;;
  esac
}

run_backup() {
  case "${SYNC_MODE}" in
    hf) backup_hf ;;
    github) backup_github ;;
    webdav) backup_webdav ;;
    *) ;;
  esac
}

if [ "${ACTION}" = "restore" ]; then
  run_restore
elif [ "${ACTION}" = "backup" ]; then
  run_backup
elif [ "${ACTION}" = "daemon" ]; then
  # Best-effort final backup when the platform stops the container
  trap 'run_backup || true; exit 0' TERM INT
  LAST_HASH=""
  while true; do
    sleep "${SYNC_INTERVAL}" &
    wait $!
    if [ -f "${DATA_DIR}/data.db" ]; then
      CURRENT_HASH=$(md5sum "${DATA_DIR}/data.db" | awk '{print $1}')
      if [ "${CURRENT_HASH}" != "${LAST_HASH}" ]; then
        run_backup || true
        LAST_HASH="${CURRENT_HASH}"
      fi
    fi
  done
fi
