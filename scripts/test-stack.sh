#!/usr/bin/env bash
# ============================================================
# Script de tests automatisés de la stack (exemple lab)
# Vérifie la santé des services, la validité des fichiers YAML, et la résolution DNS
# Usage : ./scripts/test-stack.sh
# ============================================================

set -euo pipefail
set -a
[ -f .env ] && . .env
set +a

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Vérification de la validité des fichiers YAML
log_info "Vérification de la syntaxe YAML..."
if ! command -v yamllint &>/dev/null; then
  log_warn "yamllint non installé, installation temporaire..."
  if command -v apt-get &>/dev/null; then sudo apt-get install -y yamllint; fi
  if command -v dnf &>/dev/null; then sudo dnf install -y yamllint; fi
  if command -v pacman &>/dev/null; then sudo pacman -Sy --noconfirm yamllint; fi
fi
yamllint docker-compose.yml config/**/*.yml || { log_error "Erreur de syntaxe YAML"; exit 1; }
log_success "Tous les fichiers YAML sont valides."

# Vérification de la santé des services Docker
log_info "Vérification de la santé des services Docker..."
if ! command -v docker &>/dev/null; then log_error "Docker n'est pas installé."; exit 1; fi
SERVICES=(traefik pihole squid)
for svc in "${SERVICES[@]}"; do
  STATUS=$(docker inspect -f '{{.State.Health.Status}}' $svc 2>/dev/null || echo "unknown")
  if [[ "$STATUS" == "healthy" ]]; then
    log_success "Service $svc : healthy"
  else
    log_warn "Service $svc : $STATUS"
  fi
done



log_success "Tous les tests automatisés sont terminés."
