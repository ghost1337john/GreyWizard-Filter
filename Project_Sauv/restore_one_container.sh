#!/usr/bin/env bash

set -euo pipefail

# Restaure un seul container depuis une archive hub_backup_*.tar.gz.
# Usage:
#   sudo ./restore_one_container.sh <container_name> [archive_path]
# Exemples:
#   sudo ./restore_one_container.sh sonarr
#   sudo ./restore_one_container.sh sonarr /sauvegarde/hub_backup_2026-04-03_03-00-00.tar.gz

if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Ce script doit etre execute en root (sudo)."
  exit 1
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <container_name> [archive_path]"
  exit 1
fi

CONTAINER_NAME="$1"
ARCHIVE_PATH="${2:-}"

if [ -z "$ARCHIVE_PATH" ]; then
  ARCHIVE_PATH="$(ls -t /sauvegarde/hub_backup_*.tar.gz 2>/dev/null | head -n 1 || true)"
fi

if [ -z "$ARCHIVE_PATH" ] || [ ! -f "$ARCHIVE_PATH" ]; then
  echo "[ERROR] Archive introuvable. Donne un chemin valide ou place une archive dans /sauvegarde."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker introuvable."
  exit 1
fi

HAS_RSYNC=false
if command -v rsync >/dev/null 2>&1; then
  HAS_RSYNC=true
else
  echo "[WARN] rsync introuvable: fallback sur cp -a (plus lent)."
fi

TMP_DIR="$(mktemp -d /tmp/restore_one_${CONTAINER_NAME}_XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[INFO] Container cible: $CONTAINER_NAME"
echo "[INFO] Archive: $ARCHIVE_PATH"
echo "[INFO] Dossier temporaire: $TMP_DIR"

# Extrait uniquement le dossier du container pour accelerer la restauration.
if ! tar -tzf "$ARCHIVE_PATH" "app/$CONTAINER_NAME" >/dev/null 2>&1 && \
   ! tar -tzf "$ARCHIVE_PATH" "app/$CONTAINER_NAME/" >/dev/null 2>&1; then
  echo "[ERROR] Dossier app/$CONTAINER_NAME introuvable dans l archive."
  exit 1
fi

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR" "app/$CONTAINER_NAME"

# Arret du container si il existe et tourne.
if docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "[INFO] Arret du container: $CONTAINER_NAME"
  docker stop "$CONTAINER_NAME"
fi

mkdir -p "/app/$CONTAINER_NAME"
echo "[INFO] Restauration de /app/$CONTAINER_NAME"
if [ "$HAS_RSYNC" = true ]; then
  rsync -a --delete "$TMP_DIR/app/$CONTAINER_NAME/" "/app/$CONTAINER_NAME/"
else
  # Equivalent de --delete sans rsync: purge la cible puis recopie complete.
  find "/app/$CONTAINER_NAME" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  cp -a "$TMP_DIR/app/$CONTAINER_NAME/." "/app/$CONTAINER_NAME/"
fi

# Gestion du cas gluetun en priorite.
if [ "$CONTAINER_NAME" = "flaresolverr" ] || [ "$CONTAINER_NAME" = "qbittorrent" ] || [ "$CONTAINER_NAME" = "prowlarr" ]; then
  if docker ps -a --format '{{.Names}}' | grep -qx "gluetun"; then
    echo "[INFO] Demarrage prioritaire de gluetun"
    docker start gluetun >/dev/null || true
    echo "[INFO] Attente 10s que gluetun soit operationnel..."
    sleep 10
  fi
fi

echo "[INFO] Redemarrage du container: $CONTAINER_NAME"
docker start "$CONTAINER_NAME"

echo "[INFO] Verification"
docker ps --filter "name=^/${CONTAINER_NAME}$"

echo "[OK] Restauration terminee pour $CONTAINER_NAME"
