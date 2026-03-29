#!/usr/bin/env bash
# ============================================================
# Script interactif de génération du fichier .env pour un lab générique
# Usage : ./scripts/generate-env.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


echo -e "${BLUE}Génération interactive du fichier .env pour votre lab${NC}"

# Choix du moteur DNS
echo ""
echo "Quel moteur DNS souhaitez-vous utiliser ?"
select DNS_ENGINE in "pi-hole" "adguardhome"; do
  case $DNS_ENGINE in
    "pi-hole"|"adguardhome")
      break
      ;;
    *)
      echo "Choix invalide."
      ;;
  esac
done

read -rp "Fuseau horaire (ex: Europe/Paris) [Europe/Paris] : " TZ
TZ=${TZ:-Europe/Paris}

read -rp "IP du serveur (host1.lab.local) [192.168.10.10] : " SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.10.10}

read -rp "Domaine DNS interne (ex: lab.local, maison) [lab.local] : " TRAEFIK_DOMAIN
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-lab.local}

# Machines clés à déclarer
MACHINES=("passerelle" "hub" "serveur_docker")
MACHINES_LABEL=("Passerelle/Routeur" "Hub multimédia" "Serveur principal (stack Docker)")
MACHINES_HOST=("gw" "media" "host1")
MACHINES_IP=()

for i in ${!MACHINES[@]}; do
  read -rp "Nom d'hôte pour ${MACHINES_LABEL[$i]} [${MACHINES_HOST[$i]}] : " HOST
  HOST=${HOST:-${MACHINES_HOST[$i]}}
  MACHINES_HOST[$i]=$HOST
  read -rp "Adresse IP pour $HOST.$TRAEFIK_DOMAIN [192.168.10.$((10+$i))] : " IP
  IP=${IP:-192.168.10.$((10+$i))}
  MACHINES_IP[$i]=$IP
  if [[ $i -eq 2 ]]; then
    SERVER_IP=$IP
  fi
  echo "  $HOST.$TRAEFIK_DOMAIN → $IP"
done

echo "# ============================================================" > .env
echo "# Lab Example – Variables d'environnement" >> .env
echo "# Généré automatiquement le $(date)" >> .env
echo "# ============================================================" >> .env
echo "" >> .env

echo "TZ=$TZ" >> .env
echo "SERVER_IP=$SERVER_IP" >> .env
echo "TRAEFIK_DOMAIN=$TRAEFIK_DOMAIN" >> .env
echo "DNS_ENGINE=$DNS_ENGINE" >> .env

if [[ "$DNS_ENGINE" == "pi-hole" ]]; then
  echo "PIHOLE_WEBPASSWORD=$PIHOLE_WEBPASSWORD" >> .env
  echo "PIHOLE_DNS=$PIHOLE_DNS" >> .env
fi

# Création des dossiers de config pour AdGuard Home si sélectionné
if [[ "$DNS_ENGINE" == "adguardhome" ]]; then
  mkdir -p config/adguardhome/work
  mkdir -p config/adguardhome/conf
  # Place un fichier README pour guider l'utilisateur
  echo "Ce dossier contiendra les fichiers de configuration et de travail d'AdGuard Home.\nLes fichiers seront générés automatiquement par AdGuard Home au premier lancement.\nVous pouvez y placer vos propres fichiers de config si besoin." > config/adguardhome/README.txt
fi

# Génération dynamique de config/dnsmasq/lab.conf
cat > config/dnsmasq/lab.conf <<EOF
# ============================================================
# dnsmasq – Configuration étendue pour le domaine $TRAEFIK_DOMAIN
# Fichier : /etc/dnsmasq.d/99-$TRAEFIK_DOMAIN.conf (dans Pi-hole)
#
# Ce fichier complète custom.list avec des directives dnsmasq
# avancées : domaine local, TTL, reverse DNS, DHCP (optionnel).
# ============================================================

domain=$TRAEFIK_DOMAIN
local=/$TRAEFIK_DOMAIN/

# TTL des réponses locales
# 300 secondes = 5 minutes (bon compromis pour un lab).
local-ttl=300
EOF

# Génération dynamique de config/squid/squid.conf
cat > config/squid/squid.conf <<EOF
# ============================================================
# Squid – Configuration proxy HTTP/HTTPS
# Lab     : $TRAEFIK_DOMAIN
# Hôte    : ${MACHINES_HOST[2]}.$TRAEFIK_DOMAIN – $SERVER_IP
# Réseau  : $(echo $SERVER_IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
# ============================================================

http_port ${SQUID_PORT:-3128}

cache_dir ufs /var/spool/squid 2048 16 256
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
maximum_object_size 50 MB
connect_timeout 30 seconds
read_timeout    300 seconds
request_timeout 60 seconds

# ACL – Listes de contrôle d'accès
acl localnet src $(echo $SERVER_IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
EOF

# Génération dynamique de config/pihole/custom.list
cat > config/pihole/custom.list <<EOF
# ============================================================
# Pi-hole – Résolutions DNS locales
# Domaine   : $TRAEFIK_DOMAIN
# Réseau    : $(echo $SERVER_IP | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')
# ============================================================

EOF
for i in ${!MACHINES_HOST[@]}; do
  echo "${MACHINES_IP[$i]}   ${MACHINES_HOST[$i]}.$TRAEFIK_DOMAIN   ${MACHINES_HOST[$i]}" >> config/pihole/custom.list
done

echo -e "${GREEN}Fichier .env généré avec succès !${NC}"
cat .env
