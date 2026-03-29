#!/usr/bin/env bash
# ============================================================
# Script de désinstallation
# Hôte : host1.lab.local (192.168.10.10)
#
# Usage : sudo ./uninstall.sh [--purge]
#
# --purge : supprime aussi les volumes Docker (données Pi-hole,
#           cache Squid, certificats Traefik). IRRÉVERSIBLE.
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PURGE=false

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

for arg in "$@"; do
  [[ "${arg}" == "--purge" ]] && PURGE=true
done

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

  if [[ "${PURGE}" == true ]]; then
    log_warn "Mode --purge activé : les volumes Docker seront supprimés."
    log_warn "Appuyez sur Ctrl+C dans les 5 secondes pour annuler..."
    sleep 5
    log_info "Arrêt et suppression des conteneurs + volumes..."
    ${COMPOSE_CMD} down --volumes --remove-orphans
    log_success "Conteneurs et volumes supprimés."
  else
    log_info "Arrêt et suppression des conteneurs (volumes conservés)..."
    ${COMPOSE_CMD} down --remove-orphans
    log_success "Conteneurs supprimés. Les données (volumes) sont conservées."
    log_info "Pour tout supprimer : ./uninstall.sh --purge"
  fi

  log_info "Nettoyage des images orphelines..."
  docker image prune -f

  log_success "Stack lab.local désinstallée."
}

main "$@"
