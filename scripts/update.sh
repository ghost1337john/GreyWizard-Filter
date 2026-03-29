#!/usr/bin/env bash
# ============================================================
# GreyHaven – Script de mise à jour de la stack
# Hôte : carcharoth.greyhaven (192.168.1.42)
#
# Usage : ./scripts/update.sh
#
# Ce script :
#   1. Télécharge les nouvelles images Docker
#   2. Redémarre les conteneurs impactés
#   3. Nettoie les anciennes images
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }

# ── Détection Compose ────────────────────────────────────────
if docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
else
  echo "Docker Compose introuvable." >&2; exit 1
fi

main() {
  cd "${SCRIPT_DIR}"

  log_info "Téléchargement des dernières images..."
  ${COMPOSE_CMD} pull

  log_info "Redémarrage des conteneurs mis à jour..."
  ${COMPOSE_CMD} up -d --remove-orphans

  log_info "Nettoyage des images obsolètes..."
  docker image prune -f

  log_success "Stack GreyHaven mise à jour avec succès."
  echo ""
  log_info "État des services :"
  ${COMPOSE_CMD} ps
}

main "$@"
