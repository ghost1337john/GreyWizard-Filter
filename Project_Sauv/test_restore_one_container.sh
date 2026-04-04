#!/usr/bin/env bash

set -euo pipefail

# Simule une panne d un container puis valide la restauration unitaire.
# Usage:
#   sudo ./test_restore_one_container.sh [container_name] [archive_path]
# Exemples:
#   sudo ./test_restore_one_container.sh
#   sudo ./test_restore_one_container.sh tautulli
#   sudo ./test_restore_one_container.sh tautulli /sauvegarde/hub_backup_2026-04-03_03-00-00.tar.gz

if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Ce script doit etre execute en root (sudo)."
  exit 1
fi

CONTAINER_NAME="${1:-tautulli}"
ARCHIVE_PATH="${2:-}"
SAVE_SCRIPT="/home/plex/hub_multimedia/save_hub.sh"
RESTORE_SCRIPT="/home/plex/hub_multimedia/restore_one_container.sh"
TARGET_DIR="/app/$CONTAINER_NAME"
TEST_FILE="$TARGET_DIR/restore_test.txt"

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker introuvable."
  exit 1
fi

if [ ! -f "$SAVE_SCRIPT" ]; then
  echo "[ERROR] Script de sauvegarde introuvable: $SAVE_SCRIPT"
  exit 1
fi

if [ ! -f "$RESTORE_SCRIPT" ]; then
  echo "[ERROR] Script de restauration unitaire introuvable: $RESTORE_SCRIPT"
  exit 1
fi

mkdir -p "$TARGET_DIR"

TOKEN_OK="ETAT_AVANT_BACKUP_$(date +%Y%m%d_%H%M%S)_$$"
TOKEN_BAD="CORROMPU_$(date +%Y%m%d_%H%M%S)_$$"

echo "[TEST] Container cible: $CONTAINER_NAME"
echo "[TEST] Fichier test: $TEST_FILE"

echo "[TEST] Etape 1/6: ecriture etat sain"
echo "$TOKEN_OK" > "$TEST_FILE"

if [ -z "$ARCHIVE_PATH" ]; then
  echo "[TEST] Etape 2/6: creation d une sauvegarde fraiche"
  bash "$SAVE_SCRIPT"
  ARCHIVE_PATH="$(ls -t /sauvegarde/hub_backup_*.tar.gz 2>/dev/null | head -n 1 || true)"
else
  echo "[TEST] Etape 2/6: archive fournie par argument"
fi

if [ -z "$ARCHIVE_PATH" ] || [ ! -f "$ARCHIVE_PATH" ]; then
  echo "[ERROR] Archive introuvable apres sauvegarde."
  exit 1
fi

echo "[TEST] Archive utilisee: $ARCHIVE_PATH"

echo "[TEST] Etape 3/6: simulation de panne (corruption)"
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
echo "$TOKEN_BAD" > "$TEST_FILE"

echo "[TEST] Etape 4/6: restauration unitaire"
bash "$RESTORE_SCRIPT" "$CONTAINER_NAME" "$ARCHIVE_PATH"

echo "[TEST] Etape 5/6: verification des donnees"
CURRENT_CONTENT="$(cat "$TEST_FILE" 2>/dev/null || true)"
if [ "$CURRENT_CONTENT" != "$TOKEN_OK" ]; then
  echo "[FAIL] Contenu inattendu apres restauration."
  echo "[FAIL] Attendu: $TOKEN_OK"
  echo "[FAIL] Obtenu: $CURRENT_CONTENT"
  exit 1
fi

echo "[TEST] Etape 6/6: verification etat container"
if ! docker ps --filter "name=^/${CONTAINER_NAME}$" --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "[FAIL] Le container n est pas en etat running: $CONTAINER_NAME"
  exit 1
fi

echo "[PASS] Test valide: restauration unitaire fonctionnelle pour $CONTAINER_NAME"
echo "[PASS] Le fichier test a retrouve son etat sauvegarde."
