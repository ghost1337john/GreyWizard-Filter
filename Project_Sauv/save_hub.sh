#!/usr/bin/env bash

set -euo pipefail

# Script de sauvegarde globale:
# 1) verifie les prerequis (root, verrou, dossier cible)
# 2) collecte les chemins a sauvegarder (/app, fichiers deploy)
# 3) inclut les donnees Portainer (bind mount ou volume Docker)
# 4) exporte les stacks Portainer deployes via l'interface web
# 5) arrete les conteneurs (compose ou docker stop direct)
# 6) cree l'archive tar.gz
# 7) redemarre les conteneurs, puis applique la rotation des sauvegardes

# === CONFIGURATION ===
BACKUP_DIR="/sauvegarde"
DEPLOY_DIR="/home/plex/hub_multimedia"
APP_DIR="/app"
PORTAINER_CONTAINER_NAME="portainer"
PORTAINER_VOLUME_NAME="portainer_data"
MAX_BACKUPS=14
STOP_CONTAINERS=true

DATE="$(date +"%Y-%m-%d_%H-%M-%S")"
ARCHIVE="$BACKUP_DIR/hub_backup_$DATE.tar.gz"
LOCK_FILE="/tmp/save_hub.lock"
TEMP_WORKDIR=""

APP_FOLDERS=(
  "$APP_DIR/bazarr"
  "$APP_DIR/cleanuparr"
  "$APP_DIR/flaresolverr"
  "$APP_DIR/gluetun"
  "$APP_DIR/lidarr"
  "$APP_DIR/plex"
  "$APP_DIR/prowlarr"
  "$APP_DIR/qbittorrent"
  "$APP_DIR/radarr"
  "$APP_DIR/seerr"
  "$APP_DIR/sonarr"
  "$APP_DIR/tautulli"
)

DEPLOY_FILES=(
  "$DEPLOY_DIR/docker-compose.yml"
  "$DEPLOY_DIR/.env"
)
# Note: ces fichiers peuvent etre absents si les stacks sont gerees uniquement
# via Portainer UI. Dans ce cas, les warnings "Ignore (introuvable)" sont normaux.

# Le script doit etre lance en root pour lire/ecrire partout et piloter Docker.
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Ce script doit etre execute en root (sudo)."
  exit 1
fi

# Verrou simple pour eviter 2 sauvegardes en parallele.
if [ -f "$LOCK_FILE" ]; then
  echo "[ERROR] Une sauvegarde semble deja en cours ($LOCK_FILE)."
  exit 1
fi

cleanup() {
  # Nettoie toujours le verrou et les repertoires temporaires meme en cas d'erreur.
  rm -f "$LOCK_FILE"
  if [ -n "$TEMP_WORKDIR" ] && [ -d "$TEMP_WORKDIR" ]; then
    rm -rf "$TEMP_WORKDIR"
  fi
}
trap cleanup EXIT

touch "$LOCK_FILE"
mkdir -p "$BACKUP_DIR"

# Detecte automatiquement la commande compose disponible.
if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_BIN=(docker-compose)
else
  echo "[ERROR] docker compose (ou docker-compose) introuvable."
  exit 1
fi

# Construit la liste des chemins existants a inclure dans l'archive.
TO_BACKUP=()
for path in "${APP_FOLDERS[@]}" "${DEPLOY_FILES[@]}"; do
  if [ -e "$path" ]; then
    TO_BACKUP+=("$path")
  else
    echo "[WARN] Ignore (introuvable): $path"
  fi
done

PORTAINER_DATA_MOUNT=""
PORTAINER_DATA_TYPE=""
PORTAINER_DATA_NAME=""
PORTAINER_DATA_SOURCE=""
# Chemin effectif vers les donnees Portainer (source pour l'export des stacks).
PORTAINER_DATA_DIR=""

# Essaie d'abord de comprendre comment /data est monte dans le conteneur Portainer.
if docker container inspect "$PORTAINER_CONTAINER_NAME" >/dev/null 2>&1; then
  PORTAINER_DATA_MOUNT="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}|{{.Name}}|{{.Source}}{{end}}{{end}}' "$PORTAINER_CONTAINER_NAME")"

  if [ -n "$PORTAINER_DATA_MOUNT" ]; then
    IFS='|' read -r PORTAINER_DATA_TYPE PORTAINER_DATA_NAME PORTAINER_DATA_SOURCE <<< "$PORTAINER_DATA_MOUNT"
  fi
else
  echo "[WARN] Conteneur Portainer introuvable: $PORTAINER_CONTAINER_NAME"
fi

# Initialise le dossier de travail temporaire (utilise pour volume ET export stacks).
TEMP_WORKDIR="/tmp/save_hub_portainer_export"
rm -rf "$TEMP_WORKDIR"
mkdir -p "$TEMP_WORKDIR"
PORTAINER_EXPORT_DIR="$TEMP_WORKDIR/portainer_data"

# Cas 1: Portainer en bind mount => on sauvegarde directement le chemin source.
if [ "$PORTAINER_DATA_TYPE" = "bind" ] && [ -n "$PORTAINER_DATA_SOURCE" ] && [ -d "$PORTAINER_DATA_SOURCE" ]; then
  echo "[INFO] Sauvegarde Portainer via bind mount: $PORTAINER_DATA_SOURCE"
  TO_BACKUP+=("$PORTAINER_DATA_SOURCE")
  PORTAINER_DATA_DIR="$PORTAINER_DATA_SOURCE"
# Cas 2: Portainer en volume => export temporaire du volume vers un dossier.
elif [ "$PORTAINER_DATA_TYPE" = "volume" ] && [ -n "$PORTAINER_DATA_NAME" ]; then
  mkdir -p "$PORTAINER_EXPORT_DIR"
  echo "[INFO] Export du volume Portainer: $PORTAINER_DATA_NAME"
  docker run --rm \
    -v "$PORTAINER_DATA_NAME:/from:ro" \
    -v "$PORTAINER_EXPORT_DIR:/to" \
    busybox sh -c "cd /from && tar -cf - . | tar -xf - -C /to"
  TO_BACKUP+=("$PORTAINER_EXPORT_DIR")
  PORTAINER_DATA_DIR="$PORTAINER_EXPORT_DIR"
# Cas 3: fallback sur un nom de volume attendu si la detection precedente echoue.
elif docker volume inspect "$PORTAINER_VOLUME_NAME" >/dev/null 2>&1; then
  mkdir -p "$PORTAINER_EXPORT_DIR"
  echo "[INFO] Export du volume Portainer (fallback): $PORTAINER_VOLUME_NAME"
  docker run --rm \
    -v "$PORTAINER_VOLUME_NAME:/from:ro" \
    -v "$PORTAINER_EXPORT_DIR:/to" \
    busybox sh -c "cd /from && tar -cf - . | tar -xf - -C /to"
  TO_BACKUP+=("$PORTAINER_EXPORT_DIR")
  PORTAINER_DATA_DIR="$PORTAINER_EXPORT_DIR"
else
  echo "[WARN] Donnees Portainer introuvables (ni bind mount /data, ni volume)."
fi

# Export lisible des stacks Portainer deployes via l'interface web.
# Portainer stocke les YAML dans portainer_data/compose/<id>/docker-compose.yml.
# Ce dossier permet de consulter ou rejouer chaque stack sans avoir a restaurer Portainer.
if [ -n "$PORTAINER_DATA_DIR" ] && [ -d "$PORTAINER_DATA_DIR/compose" ]; then
  PORTAINER_STACKS_DIR="$TEMP_WORKDIR/portainer_stacks"
  mkdir -p "$PORTAINER_STACKS_DIR"
  STACK_COUNT=0
  for stack_dir in "$PORTAINER_DATA_DIR/compose"/*/; do
    [ -d "$stack_dir" ] || continue
    stack_id="$(basename "$stack_dir")"
    if [ -f "$stack_dir/docker-compose.yml" ]; then
      mkdir -p "$PORTAINER_STACKS_DIR/stack_$stack_id"
      cp "$stack_dir/docker-compose.yml" "$PORTAINER_STACKS_DIR/stack_$stack_id/"
      [ -f "$stack_dir/.env" ] && cp "$stack_dir/.env" "$PORTAINER_STACKS_DIR/stack_$stack_id/"
      STACK_COUNT=$((STACK_COUNT + 1))
    fi
  done
  if [ "$STACK_COUNT" -gt 0 ]; then
    TO_BACKUP+=("$PORTAINER_STACKS_DIR")
    echo "[INFO] $STACK_COUNT stack(s) Portainer exportees en YAML lisible: $PORTAINER_STACKS_DIR"
  else
    echo "[WARN] Aucune stack Portainer trouvee dans compose/."
  fi
fi

# Stop si rien de sauvegardable n'a ete trouve.
if [ ${#TO_BACKUP[@]} -eq 0 ]; then
  echo "[ERROR] Aucun dossier/fichier trouve. Rien a sauvegarder."
  exit 1
fi

echo "[INFO] Debut sauvegarde: $DATE"
echo "[INFO] Archive cible: $ARCHIVE"

# Arret propre des conteneurs avant archivage pour garantir la coherence des donnees
# (evite les fichiers SQLite en ecriture, les sockets actifs, les logs en cours).
# - Si un docker-compose.yml est present dans DEPLOY_DIR: utilise "compose down".
# - Sinon (cas typique: toutes les stacks gerees via Portainer UI): arrete chaque
#   conteneur individuellement via "docker stop", en excluant Portainer lui-meme.
CONTAINERS_STOPPED=()
if [ "$STOP_CONTAINERS" = true ]; then
  if [ -f "$DEPLOY_DIR/docker-compose.yml" ]; then
    echo "[INFO] Arret propre des conteneurs via compose..."
    "${COMPOSE_BIN[@]}" -f "$DEPLOY_DIR/docker-compose.yml" down
  else
    echo "[INFO] Arret des conteneurs Docker (hors Portainer)..."
    mapfile -t CONTAINERS_STOPPED < <(docker ps --format '{{.Names}}' | grep -v "^${PORTAINER_CONTAINER_NAME}$")
    if [ ${#CONTAINERS_STOPPED[@]} -gt 0 ]; then
      docker stop "${CONTAINERS_STOPPED[@]}"
      echo "[INFO] Conteneurs arretes: ${CONTAINERS_STOPPED[*]}"
    fi
  fi
fi

echo "[INFO] Creation de l'archive..."
tar -czf "$ARCHIVE" "${TO_BACKUP[@]}"

# Redemarrage des conteneurs apres archivage:
# - compose up -d si un docker-compose.yml local existe.
# - docker start sinon, avec gestion de l'ordre de demarrage:
#   gluetun doit demarrer en premier car flaresolverr, qbittorrent et prowlarr
#   utilisent son namespace reseau (network_mode: service:gluetun).
#   On attend 10s apres gluetun avant de lancer les autres.
if [ "$STOP_CONTAINERS" = true ]; then
  if [ -f "$DEPLOY_DIR/docker-compose.yml" ]; then
    echo "[INFO] Redemarrage des conteneurs via compose..."
    "${COMPOSE_BIN[@]}" -f "$DEPLOY_DIR/docker-compose.yml" up -d
  elif [ ${#CONTAINERS_STOPPED[@]} -gt 0 ]; then
    # Demarre gluetun en premier si il fait partie des conteneurs arretes.
    OTHERS=()
    for c in "${CONTAINERS_STOPPED[@]}"; do
      if [ "$c" = "gluetun" ]; then
        echo "[INFO] Demarrage prioritaire: gluetun"
        docker start gluetun
        echo "[INFO] Attente 10s que gluetun soit operationnel..."
        sleep 10
      else
        OTHERS+=("$c")
      fi
    done
    # Demarre tous les autres conteneurs.
    if [ ${#OTHERS[@]} -gt 0 ]; then
      echo "[INFO] Redemarrage des conteneurs restants..."
      docker start "${OTHERS[@]}"
      echo "[INFO] Conteneurs redemarres: ${OTHERS[*]}"
    fi
  fi
fi

# Retention: conserve uniquement les N sauvegardes les plus recentes.
echo "[INFO] Rotation des sauvegardes (garde: $MAX_BACKUPS)"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'hub_backup_*.tar.gz' -printf '%T@ %p\n' \
  | sort -nr \
  | tail -n +$((MAX_BACKUPS + 1)) \
  | cut -d' ' -f2- \
  | xargs -r rm -f

ARCHIVE_SIZE="$(du -h "$ARCHIVE" | awk '{print $1}')"
echo "[OK] Sauvegarde terminee: $ARCHIVE ($ARCHIVE_SIZE)"
