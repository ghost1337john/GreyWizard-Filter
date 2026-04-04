#!/usr/bin/env bash

set -euo pipefail

# Script de restauration globale:
# 1) extrait une archive de sauvegarde
# 2) restaure /app et les fichiers de deploiement
# 3) restaure les donnees Portainer selon le mode detecte
# 4) redemarre la stack principale

# === CONFIGURATION ===
TARGET_APP_DIR="/app"
TARGET_DEPLOY_DIR="/home/plex/hub_multimedia"
PORTAINER_CONTAINER_NAME="portainer"
PORTAINER_VOLUME_NAME="portainer_data"
RESTART_CONTAINERS=true

ARCHIVE_PATH="${1:-}"
TEMP_RESTORE_DIR=""

usage() {
  echo "Usage: sudo $0 /chemin/vers/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz"
}

# Le script doit etre lance en root pour restaurer les chemins systeme.
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Ce script doit etre execute en root (sudo)."
  exit 1
fi

# Verifie l'argument obligatoire (archive a restaurer).
if [ -z "$ARCHIVE_PATH" ]; then
  usage
  exit 1
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "[ERROR] Archive introuvable: $ARCHIVE_PATH"
  exit 1
fi

HAS_RSYNC=false
if command -v rsync >/dev/null 2>&1; then
  HAS_RSYNC=true
else
  echo "[WARN] rsync introuvable: fallback sur cp -a (plus lent)."
fi

cleanup() {
  # Nettoie le repertoire temporaire meme si la restauration echoue.
  if [ -n "$TEMP_RESTORE_DIR" ] && [ -d "$TEMP_RESTORE_DIR" ]; then
    rm -rf "$TEMP_RESTORE_DIR"
  fi
}
trap cleanup EXIT

# Detecte automatiquement la commande compose disponible.
if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN=(docker-compose)
else
  COMPOSE_BIN=()
fi

# Extrait l'archive dans un dossier temporaire de travail.
TEMP_RESTORE_DIR="$(mktemp -d /tmp/restore_hub.XXXXXX)"
echo "[INFO] Extraction de l'archive dans $TEMP_RESTORE_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_RESTORE_DIR"

# Arret optionnel de la stack principale pour eviter des ecritures concurrentes.
if [ "$RESTART_CONTAINERS" = true ] && [ -f "$TARGET_DEPLOY_DIR/docker-compose.yml" ] && [ ${#COMPOSE_BIN[@]} -gt 0 ]; then
  echo "[INFO] Arret des conteneurs du compose principal..."
  "${COMPOSE_BIN[@]}" -f "$TARGET_DEPLOY_DIR/docker-compose.yml" down || true
fi

# Restaure les configurations applicatives (Sonarr/Radarr/etc.) sous /app.
if [ -d "$TEMP_RESTORE_DIR/app" ]; then
  echo "[INFO] Restauration des dossiers applicatifs vers $TARGET_APP_DIR"
  mkdir -p "$TARGET_APP_DIR"
  if [ "$HAS_RSYNC" = true ]; then
    rsync -a "$TEMP_RESTORE_DIR/app/" "$TARGET_APP_DIR/"
  else
    cp -a "$TEMP_RESTORE_DIR/app/." "$TARGET_APP_DIR/"
  fi
else
  echo "[WARN] Aucun dossier app trouve dans l'archive."
fi

# Restaure docker-compose.yml et .env avec backup des fichiers existants.
# Compatible avec archives anciennes (/opt/hub_multimedia) et nouvelles (/home/plex/hub_multimedia).
ARCHIVE_DEPLOY_DIR=""
if [ -d "$TEMP_RESTORE_DIR/home/plex/hub_multimedia" ]; then
  ARCHIVE_DEPLOY_DIR="$TEMP_RESTORE_DIR/home/plex/hub_multimedia"
elif [ -d "$TEMP_RESTORE_DIR/opt/hub_multimedia" ]; then
  ARCHIVE_DEPLOY_DIR="$TEMP_RESTORE_DIR/opt/hub_multimedia"
fi

if [ -n "$ARCHIVE_DEPLOY_DIR" ]; then
  echo "[INFO] Restauration des fichiers de deploiement"
  mkdir -p "$TARGET_DEPLOY_DIR"

  if [ -f "$ARCHIVE_DEPLOY_DIR/docker-compose.yml" ]; then
    if [ -f "$TARGET_DEPLOY_DIR/docker-compose.yml" ]; then
      cp "$TARGET_DEPLOY_DIR/docker-compose.yml" "$TARGET_DEPLOY_DIR/docker-compose.yml.bak.$(date +"%Y-%m-%d_%H-%M-%S")"
    fi
    cp "$ARCHIVE_DEPLOY_DIR/docker-compose.yml" "$TARGET_DEPLOY_DIR/docker-compose.yml"
  fi

  if [ -f "$ARCHIVE_DEPLOY_DIR/.env" ]; then
    if [ -f "$TARGET_DEPLOY_DIR/.env" ]; then
      cp "$TARGET_DEPLOY_DIR/.env" "$TARGET_DEPLOY_DIR/.env.bak.$(date +"%Y-%m-%d_%H-%M-%S")"
    fi
    cp "$ARCHIVE_DEPLOY_DIR/.env" "$TARGET_DEPLOY_DIR/.env"
  fi
else
  echo "[WARN] Aucun repertoire de deploiement trouve dans l'archive (home/plex/hub_multimedia ou opt/hub_multimedia)."
fi

PORTAINER_RESTORED=false

# Cas volume exporte par save_hub.sh: restauration vers le volume Portainer.
if [ -d "$TEMP_RESTORE_DIR/tmp/save_hub_portainer_export/portainer_data" ]; then
  echo "[INFO] Restauration Portainer depuis export de volume"
  docker volume create "$PORTAINER_VOLUME_NAME" >/dev/null
  docker run --rm \
    -v "$PORTAINER_VOLUME_NAME:/to" \
    -v "$TEMP_RESTORE_DIR:/from:ro" \
    busybox sh -c "rm -rf /to/* && cd /from && tar -cf - tmp/save_hub_portainer_export/portainer_data | tar -xf - -C /to --strip-components=2"
  PORTAINER_RESTORED=true
fi

# Cas bind mount Portainer: restaure vers le chemin local monte sur /data.
if docker container inspect "$PORTAINER_CONTAINER_NAME" >/dev/null 2>&1; then
  PORTAINER_DATA_MOUNT="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}|{{.Source}}|{{.Name}}{{end}}{{end}}' "$PORTAINER_CONTAINER_NAME")"
  if [ -n "$PORTAINER_DATA_MOUNT" ]; then
    IFS='|' read -r PORTAINER_DATA_TYPE PORTAINER_DATA_SOURCE PORTAINER_DATA_NAME <<< "$PORTAINER_DATA_MOUNT"
    if [ "$PORTAINER_DATA_TYPE" = "bind" ] && [ -d "$TEMP_RESTORE_DIR$PORTAINER_DATA_SOURCE" ]; then
      echo "[INFO] Restauration Portainer vers bind mount: $PORTAINER_DATA_SOURCE"
      mkdir -p "$PORTAINER_DATA_SOURCE"
      if [ "$HAS_RSYNC" = true ]; then
        rsync -a "$TEMP_RESTORE_DIR$PORTAINER_DATA_SOURCE/" "$PORTAINER_DATA_SOURCE/"
      else
        cp -a "$TEMP_RESTORE_DIR$PORTAINER_DATA_SOURCE/." "$PORTAINER_DATA_SOURCE/"
      fi
      PORTAINER_RESTORED=true
    fi
  fi
fi

# Avertit explicitement si aucune restauration Portainer n'a pu etre appliquee.
if [ "$PORTAINER_RESTORED" = false ]; then
  echo "[WARN] Donnees Portainer non restaurees automatiquement (aucune source detectee dans l'archive)."
fi

# Redemarre la stack principale si demande.
if [ "$RESTART_CONTAINERS" = true ] && [ -f "$TARGET_DEPLOY_DIR/docker-compose.yml" ] && [ ${#COMPOSE_BIN[@]} -gt 0 ]; then
  echo "[INFO] Redemarrage des conteneurs du compose principal..."
  "${COMPOSE_BIN[@]}" -f "$TARGET_DEPLOY_DIR/docker-compose.yml" up -d
fi

echo "[OK] Restauration terminee depuis: $ARCHIVE_PATH"
