#!/usr/bin/env bash
# Script de lancement automatique de la stack DNS selon le choix DNS_ENGINE
set -euo pipefail

if [[ ! -f .env ]]; then
  echo "Fichier .env introuvable. Veuillez d'abord générer la configuration."
  exit 1
fi

source .env

if [[ "${DNS_ENGINE:-pi-hole}" == "adguardhome" ]]; then
  echo "[INFO] Lancement de la stack avec AdGuard Home (sans Pi-hole)"
  docker compose -f docker-compose.yml --profile adguardhome up -d
  docker compose -f docker-compose.yml --profile pihole down || true
else
  echo "[INFO] Lancement de la stack avec Pi-hole (sans AdGuard Home)"
  docker compose -f docker-compose.yml --profile pihole up -d
  docker compose -f docker-compose.yml --profile adguardhome down || true
fi
