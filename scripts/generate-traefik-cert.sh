#!/usr/bin/env bash
# Génère un certificat auto-signé pour Traefik (local)
# Usage : ./scripts/generate-traefik-cert.sh [domaine1 [domaine2 ...]]

set -euo pipefail

CERT_DIR="$(dirname "$0")/../traefik_certs"
mkdir -p "$CERT_DIR"


# Charger la variable DOMAIN du .env si présente
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# Domaines par défaut
DOMAINS=("localhost")

# Ajouter le domaine du .env si présent
if [ -n "${DOMAIN:-}" ]; then
  DOMAINS+=("traefik.$DOMAIN")
fi

# Ajouter les arguments passés en ligne de commande
if [ "$#" -gt 0 ]; then
  DOMAINS=("$@")
fi

# Construction de la liste SAN
SAN="DNS:${DOMAINS[0]}"
for d in "${DOMAINS[@]:1}"; do
  SAN=",DNS:$d$SAN"
done

openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout "$CERT_DIR/local.key" -out "$CERT_DIR/local.crt" \
  -subj "/CN=${DOMAINS[0]}" \
  -addext "subjectAltName=${SAN}"

echo "Certificat généré dans $CERT_DIR : local.crt et local.key"
