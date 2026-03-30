#!/usr/bin/env bash#
# ============================================================
# Script d'installation de la stack
# Hôte    : host1.lab.local (192.168.10.10)
#
# Usage : sudo ./install.sh
#
# Ce script :
#   1. Vérifie les prérequis (Docker, Docker Compose, curl)
#   2. Contrôle les ports critiques (53, 80, 443, 3128)
#   3. Prépare l'environnement (.env, permissions)
#   4. Démarre la stack complète
#   5. Affiche un résumé des services disponibles
# ============================================================

set -euo pipefail

# ── Couleurs ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Bannière ─────────────────────────────────────────────────
print_banner() {
  DOMAIN="${TRAEFIK_DOMAIN:-lab.local}"
  SERVER_IP="${SERVER_IP:-192.168.1.3}"
  HOSTNAME="${HOSTNAME:-host1}"
  echo "  GreyWizard-Filter – Pi-hole + Squid + Traefik"
  echo "  Hôte : $HOSTNAME.$DOMAIN ($SERVER_IP)"
  echo "  ─────────────────────────────────────────────────────────────────"
  echo ""
}

# ── Vérification des prérequis ───────────────────────────────
check_prerequisites() {
  log_info "Vérification des prérequis..."

  if ! command -v docker &>/dev/null; then
    log_error "Docker n'est pas installé. Consultez : https://docs.docker.com/engine/install/"
    exit 1
  fi
  log_success "Docker $(docker --version | grep -oP '\d+\.\d+' | head -1) détecté"

  if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
    log_success "Docker Compose (plugin) détecté"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
    log_success "Docker Compose (standalone) détecté"
  else
    log_error "Docker Compose n'est pas installé."
    exit 1
  fi

  if ! command -v curl &>/dev/null; then
    log_warn "curl n'est pas installé (recommandé pour les healthchecks)."
  fi
}

# ── Vérification des ports ───────────────────────────────────
check_ports() {
  log_info "Vérification des ports critiques..."

  local ports=(53 80 443 3128)
  for port in "${ports[@]}"; do
    if ss -lnup 2>/dev/null | grep -q ":${port} " || ss -lntp 2>/dev/null | grep -q ":${port} "; then
      log_warn "Port ${port} déjà utilisé — vérifiez qu'aucun service conflictuel ne tourne."
      if [[ "${port}" == "53" ]]; then
        log_warn "Pour libérer le port 53 : sudo systemctl stop systemd-resolved"
        log_warn "                          sudo systemctl disable systemd-resolved"
        log_warn "Pour réactiver le port 53 pour Pi-hole : sudo systemctl mask systemd-resolved && sudo systemctl stop systemd-resolved && sudo systemctl restart networking"
        if systemctl is-active --quiet systemd-resolved; then
          log_info "Arrêt de systemd-resolved pour libérer le port 53..."
          sudo systemctl stop systemd-resolved
          sudo systemctl disable systemd-resolved
          sudo systemctl mask systemd-resolved
          sudo systemctl restart networking
          log_success "Port 53 libéré."
        fi
      fi
    else
      log_success "Port ${port} disponible"
    fi
  done
}

# ── Préparation de l'environnement ───────────────────────────
prepare_environment() {
  log_info "Préparation de l'environnement..."

  cd "${SCRIPT_DIR}"

  # Si .env absent, proposer la génération interactive
  if [[ ! -f ".env" ]]; then
    if [[ -f "scripts/generate-env.sh" ]]; then
      log_info "Aucun fichier .env trouvé. Lancement de la génération interactive."
      bash scripts/generate-env.sh
    elif [[ -f ".env.example" ]]; then
      cp .env.example .env
      log_success "Fichier .env créé depuis .env.example"
      log_warn "Pensez à modifier .env (PIHOLE_WEBPASSWORD en particulier) avant de continuer."
    else
      log_error "Ni .env ni .env.example trouvés dans ${SCRIPT_DIR}"
      exit 1
    fi
  else
    log_success "Fichier .env existant trouvé"
  fi

  # Vérification du mot de passe Pi-hole
  if grep -q '^PIHOLE_WEBPASSWORD=changeme' .env; then
    log_warn "PIHOLE_WEBPASSWORD est toujours sur la valeur par défaut !"
    log_info "Vous devez définir un mot de passe admin Pi-hole."
    read -rsp "Nouveau mot de passe Pi-hole (ne sera pas affiché) : " NEW_PWD
    echo
    if [[ -z "$NEW_PWD" ]]; then
      log_error "Mot de passe vide, annulation."
      exit 1
    fi
    # Remplacement dans .env
    sed -i.bak "s/^PIHOLE_WEBPASSWORD=changeme/PIHOLE_WEBPASSWORD=$NEW_PWD/" .env
    log_success "Mot de passe Pi-hole mis à jour dans .env."
  fi

  # Vérification du hash auth Traefik
  if grep -q 'placeholder_replace_with_real_hash' config/traefik/dynamic/middlewares.yml; then
    log_warn "Le hash basicAuth Traefik est un placeholder !"
    log_warn "Générez-en un via : echo \$(htpasswd -nB admin) | sed -e 's/\\\$/\\\$\\\$/g'"
    log_warn "Puis mettez à jour config/traefik/dynamic/middlewares.yml"
  fi
}

# ── Démarrage de la stack ────────────────────────────────────
start_stack() {
  log_info "Démarrage de la stack lab.local..."
  cd "${SCRIPT_DIR}"

  # Utilise le wrapper compose-up.sh pour gérer le choix DNS_ENGINE et profils
  if [[ -x scripts/compose-up.sh ]]; then
    bash scripts/compose-up.sh
    log_success "Stack démarrée via compose-up.sh."
  else
    log_warn "scripts/compose-up.sh non trouvé ou non exécutable, fallback sur docker compose up -d."
    ${COMPOSE_CMD} pull
    ${COMPOSE_CMD} up -d --remove-orphans
    log_success "Stack démarrée (mode fallback)."
  fi
}

# ── Résumé ───────────────────────────────────────────────────
print_summary() {
  echo ""
  DOMAIN="${TRAEFIK_DOMAIN:-lab.local}"
  SERVER_IP="${SERVER_IP:-192.168.1.3}"
  echo -e "${CYAN}${BOLD}  ── Services disponibles ──────────────────────────────────${NC}"
  echo -e "  ${GREEN}Traefik dashboard${NC}  →  https://traefik.$DOMAIN"
  echo -e "  ${GREEN}Pi-hole admin${NC}      →  https://pihole.$DOMAIN/admin"
  echo -e "  ${GREEN}AdGuard Home${NC}       →  https://adguard.$DOMAIN  (ou http://$SERVER_IP:3000)"
  echo -e "  ${GREEN}Proxy Squid${NC}        →  $SERVER_IP:3128"
  echo -e "  ${GREEN}DNS Pi-hole${NC}        →  $SERVER_IP:53"
  echo ""
  echo -e "  ${YELLOW}Configurez le DNS de vos clients vers $SERVER_IP${NC}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────
main() {
  print_banner
  check_prerequisites
  check_ports
  prepare_environment
  start_stack
  print_summary
}

main "$@"
