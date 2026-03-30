#!/usr/bin/env bash
# ============================================================
# Script de déploiement complet
# Hôte : host1.lab.local (192.168.10.10)
#
# Usage : ./scripts/deploy.sh [--check]
#
# --check : mode dry-run, vérifie la configuration sans déployer.
#
# Ce script :
#   1. Vérifie la syntaxe des configs (Traefik, Squid, Pi-hole)
#   2. Contrôle la cohérence du .env
#   3. Déploie ou redémarre seulement les services modifiés
#   4. Effectue des tests de santé post-déploiement
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_check()   { echo -e "${CYAN}[CHECK]${NC} $*"; }

for arg in "$@"; do
  [[ "${arg}" == "--check" ]] && DRY_RUN=true
done

# ── Détection Compose ────────────────────────────────────────
if docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
else
  log_error "Docker Compose introuvable."; exit 1
fi

# ── Vérifications pre-deploy ─────────────────────────────────
preflight_checks() {
  log_info "Vérifications pre-déploiement..."

  # .env présent
  if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
    log_error ".env introuvable. Exécutez d'abord : cp .env.example .env"
    exit 1
  fi
  log_success ".env présent"



  # Hash basicAuth placeholder
  if grep -q 'placeholder_replace_with_real_hash' \
      "${SCRIPT_DIR}/config/traefik/dynamic/middlewares.yml"; then
    log_warn "Le hash basicAuth Traefik est toujours un placeholder."
  fi

  # Validation docker-compose.yml
  log_check "Validation docker-compose.yml..."
  if ${COMPOSE_CMD} -f "${SCRIPT_DIR}/docker-compose.yml" config -q; then
    log_success "docker-compose.yml valide"
  else
    log_error "docker-compose.yml invalide — corrigez avant de déployer."
    exit 1
  fi

  # Vérification syntaxe Squid (si squid disponible)
  if command -v squid &>/dev/null; then
    log_check "Validation squid.conf..."
    squid -k parse -f "${SCRIPT_DIR}/config/squid/squid.conf" 2>&1 | head -5
  fi

  log_success "Vérifications terminées."
}

# ── Déploiement ──────────────────────────────────────────────
deploy() {
  if [[ "${DRY_RUN}" == true ]]; then
    log_warn "Mode --check : déploiement non effectué."
    return
  fi

  log_info "Déploiement de la stack lab.local..."
  cd "${SCRIPT_DIR}"
  ${COMPOSE_CMD} up -d --remove-orphans
  log_success "Stack déployée."
}

# ── Tests de santé post-déploiement ─────────────────────────
health_checks() {
  [[ "${DRY_RUN}" == true ]] && return

  log_info "Tests de santé post-déploiement (attente 10s)..."
  sleep 10

  local all_ok=true

  # Traefik healthcheck
  if curl -sf http://127.0.0.1:80/ping >/dev/null 2>&1; then
    log_success "Traefik : OK"
  else
    log_warn "Traefik : ne répond pas encore (normal au premier démarrage)"
    all_ok=false
  fi


    if dig +short host1.lab.local @127.0.0.1 | grep -q '192.168.10.10'; then
      log_success "DNS lab.local : résolution host1.lab.local → OK"
    else
      log_warn "DNS lab.local : résolution host1.lab.local échouée"
      all_ok=false
    fi
  fi

  echo ""
  if [[ "${all_ok}" == true ]]; then
    log_success "Tous les services sont opérationnels."
  else
    log_warn "Certains services ne sont pas encore prêts — relancez dans quelques secondes."
  fi

  echo ""
  log_info "État des conteneurs :"
  ${COMPOSE_CMD} ps
}

# ── Main ─────────────────────────────────────────────────────
main() {
  cd "${SCRIPT_DIR}"
  preflight_checks
  deploy
  health_checks
}

main "$@"
