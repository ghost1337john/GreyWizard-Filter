
  # Correction des permissions sur les dossiers AdGuard Home
  mkdir -p config/adguardhome/work config/adguardhome/conf
  chown -R 1000:1000 config/adguardhome/work config/adguardhome/conf || true
  chmod 700 config/adguardhome/work config/adguardhome/conf || true
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
  echo "  GreyWizard-Filter – AdGuard Home + Squid + Traefik"
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

  # Charger automatiquement les variables du .env dans l'environnement du script
  set -a
  [ -f .env ] && . .env
  set +a

  # # Vérification du hash auth Traefik
  # if grep -q 'placeholder_replace_with_real_hash' config/traefik/dynamic/middlewares.yml; then
  #   log_warn "Le hash basicAuth Traefik est un placeholder !"
  #   log_warn "Générez-en un via : echo \$(htpasswd -nB admin) | sed -e 's/\\\$/\\\$\\\$/g'"
  #   log_warn "Puis mettez à jour config/traefik/dynamic/middlewares.yml"
  # fi
}

# ── Démarrage de la stack ────────────────────────────────────

start_stack() {
  log_info "Démarrage de la stack lab.local..."
  cd "${SCRIPT_DIR}"
  ${COMPOSE_CMD} pull
  ${COMPOSE_CMD} up -d --remove-orphans
  log_success "Stack démarrée."

  # Pause et documentation pour l'installation web manuelle
  local yaml_path="config/adguardhome/conf/AdGuardHome.yaml"
  if [[ ! -f "$yaml_path" ]]; then
    echo -e "\n${YELLOW}───────────────────────────────────────────────────────────────"
    echo -e "${YELLOW}Première initialisation d'AdGuard Home${NC}"
    echo -e "${YELLOW}Ouvrez votre navigateur sur http://$SERVER_IP:$ADGUARD_PORT${NC}"
    echo -e "${YELLOW}Terminez l'assistant d'installation web (install.html) puis relancez :${NC}"
    echo -e "${YELLOW}    sudo ./install.sh${NC}"
    echo -e "${YELLOW}───────────────────────────────────────────────────────────────\n"
    for i in {30..1}; do
      echo -ne "Attente utilisateur : $i secondes restantes...\r"
      sleep 1
    done
    echo -e "\n"
    exit 0
  fi

  # Attendre la génération du fichier AdGuardHome.yaml (max 30s)
  local yaml_path="config/adguardhome/conf/AdGuardHome.yaml"
  local waited=0
  local timeout=30
  while [[ ! -f "$yaml_path" && $waited -lt $timeout ]]; do
    log_info "En attente de la génération de $yaml_path par AdGuard Home... ($waited/$timeout s)"
    sleep 2
    waited=$((waited+2))
  done
  if [[ ! -f "$yaml_path" ]]; then
    log_error "Le fichier $yaml_path n'a pas été généré après $timeout secondes. Vérifiez les logs du conteneur adguardhome (docker logs adguardhome)."
    exit 1
  fi


}

# ── Résumé ───────────────────────────────────────────────────
print_summary() {
  echo ""
  DOMAIN="${TRAEFIK_DOMAIN:-lab.local}"
  SERVER_IP="${SERVER_IP:-192.168.1.3}"
  echo -e "${CYAN}${BOLD}  ── Services disponibles ──────────────────────────────────${NC}"
  echo -e "  ${GREEN}Traefik dashboard${NC}  →  https://traefik.${DOMAIN}"
  echo -e "  ${GREEN}AdGuard Home${NC}       →  https://adguard.${DOMAIN}  (ou http://$SERVER_IP:$ADGUARD_PORT)"
  echo -e "  ${GREEN}Proxy Squid${NC}        →  $SERVER_IP:3128"
  echo ""
  echo -e "  ${YELLOW}Configurez le DNS de vos clients vers $SERVER_IP${NC}"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────
adapt_adguardhome_config() {
  log_info "Adaptation de la configuration AdGuard Home (port, mot de passe admin)..."
  local yaml_path="config/adguardhome/conf/AdGuardHome.yaml"
  if [[ ! -f "$yaml_path" ]]; then
    log_error "Le fichier $yaml_path n'existe pas après le premier démarrage. Vérifiez que le conteneur AdGuard Home a bien généré sa configuration."
    exit 1
  fi


  # Génération et injection du bloc rewrites YAML sous dns:
  if [[ -f config/adguardhome/conf/lab-machines.env ]]; then
    source config/adguardhome/conf/lab-machines.env
    REWRITES_YAML="config/adguardhome/conf/rewrites.yaml"
    echo "rewrites:" > "$REWRITES_YAML"
    for i in "${!MACHINES_HOST[@]}"; do
      echo "  - domain: ${MACHINES_HOST[$i]}.$TRAEFIK_DOMAIN" >> "$REWRITES_YAML"
      echo "    answer: ${MACHINES_IP[$i]}" >> "$REWRITES_YAML"
      echo "    enabled: true" >> "$REWRITES_YAML"
    done
    log_success "Bloc rewrites YAML généré automatiquement."
    # Injection dans dns: du AdGuardHome.yaml
    if command -v yq >/dev/null 2>&1; then
      yq -i 'del(.dns.rewrites)' "$yaml_path"
      yq -i '(.dns.rewrites) = load("'"$REWRITES_YAML"'").rewrites' "$yaml_path"
      log_success "Bloc rewrites injecté dans dns: via yq."
    else
      # Vérifie si la section dns: existe, sinon l'ajoute à la fin
      if ! grep -q '^dns:' "$yaml_path"; then
        echo -e '\ndns:' >> "$yaml_path"
      fi
      # Supprime tout bloc rewrites existant sous dns:
      sed -i '/^dns:/,/^[^ ]/ {/^  rewrites:/,/^  [^ ]/d}' "$yaml_path"
      # Injecte le bloc rewrites juste après dns: avec la bonne indentation
      awk -v r="$(sed 's/^/  /' "$REWRITES_YAML")" '
        /^dns:/ {print; print r; next} 1
      ' "$yaml_path" > "$yaml_path.tmp" && mv "$yaml_path.tmp" "$yaml_path"
      log_success "Bloc rewrites injecté dans dns: manuellement."
    fi
    # Suppression du fichier temporaire rewrites.yaml après injection
    if [ -f "$REWRITES_YAML" ]; then
      rm -f "$REWRITES_YAML"
      log_info "Fichier temporaire $REWRITES_YAML supprimé."
    fi
  fi

  if command -v yq >/dev/null 2>&1; then
    yq -i '.http.address = "0.0.0.0:" + strenv(ADGUARD_PORT)' "$yaml_path"
  else
    # Remplace la ligne address: ... dans la section http:
    sed -i "/^http:/,/^[^ ]/ s|^\( *address: \).*|\1 0.0.0.0:$ADGUARD_PORT|" "$yaml_path"
  fi

  log_success "Configuration AdGuard Home adaptée (http.address)."

  # Redémarrage du conteneur pour prise en compte
  if docker ps | grep -q adguardhome; then
    log_info "Redémarrage du conteneur adguardhome pour prise en compte de la configuration..."
    ${COMPOSE_CMD} restart adguardhome
    log_success "Conteneur adguardhome redémarré."
  fi
}

main() {
  print_banner
  check_prerequisites
  check_ports
  prepare_environment
  start_stack
  adapt_adguardhome_config
  print_summary
}

main "$@"
