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


DNS_ENGINE="adguardhome"

read -rp "Fuseau horaire (ex: Europe/Paris) [Europe/Paris] : " TZ
TZ=${TZ:-Europe/Paris}


read -rp "Domaine DNS interne (ex: lab.local, maison) [lab.local] : " TRAEFIK_DOMAIN
TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-lab.local}

# Affichage plus clair pour l'IP du serveur principal
read -rp "IP du serveur principal (ex: host1.$TRAEFIK_DOMAIN) [192.168.10.10] : " SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.10.10}


# Saisie interactive du nombre de machines et de leurs infos
echo "Combien de machines souhaitez-vous déclarer (ex : 3) ?"
read -rp "Nombre de machines : " NB_MACHINES

MACHINES_LABEL=()
MACHINES_HOST=()
MACHINES_IP=()

for ((i=1; i<=NB_MACHINES; i++)); do
  read -rp "Rôle ou label de la machine #$i (ex: Serveur principal, Passerelle, Hub) : " LABEL
  MACHINES_LABEL+=("$LABEL")
  read -rp "Nom d'hôte pour $LABEL (ex: host1, gw, media) : " HOST
  MACHINES_HOST+=("$HOST")
  read -rp "Adresse IP pour $HOST.$TRAEFIK_DOMAIN (ex: 192.168.10.$((10+i))) : " IP
  MACHINES_IP+=("$IP")
  # Détection serveur principal (premier label contenant 'serveur' ou 'principal')
  if [[ -z "$SERVER_IP" && "$LABEL" =~ [Ss]erveur ]]; then
    SERVER_IP=$IP
  fi
  echo "  $HOST.$TRAEFIK_DOMAIN → $IP ($LABEL)"
done

# Si pas de serveur principal détecté, prendre le premier IP
if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP=${MACHINES_IP[0]}
fi

read -rp "Port d'administration AdGuard Home après installation [8080] : " ADGUARD_PORT
ADGUARD_PORT=${ADGUARD_PORT:-8080}

echo "# ============================================================" > .env
echo "# Lab Example – Variables d'environnement" >> .env
echo "# Généré automatiquement le $(date)" >> .env
echo "# ============================================================" >> .env
echo "" >> .env

echo "TZ=$TZ" >> .env
echo "SERVER_IP=$SERVER_IP" >> .env
echo "TRAEFIK_DOMAIN=$TRAEFIK_DOMAIN" >> .env
echo "ADGUARD_PORT=$ADGUARD_PORT" >> .env


echo "DNS_ENGINE=$DNS_ENGINE" >> .env

# Réinitialisation du dossier work d'AdGuard Home pour forcer la prise en compte du mot de passe admin
if [ -d config/adguardhome/work ]; then
  echo -e "${YELLOW}Suppression du dossier config/adguardhome/work pour réinitialiser AdGuard Home...${NC}"
  rm -rf config/adguardhome/work
fi
mkdir -p config/adguardhome/work
mkdir -p config/adguardhome/conf
# Place un fichier README pour guider l'utilisateur
echo "Ce dossier contiendra les fichiers de configuration et de travail d'AdGuard Home.\nLes fichiers seront générés automatiquement par AdGuard Home au premier lancement.\nVous pouvez y placer vos propres fichiers de config si besoin." > config/adguardhome/README.txt



# Génération du fichier de configuration DNS à partir des tableaux
DNS_CONFIG_PATH="config/dnsmasq/lab.conf"
mkdir -p config/dnsmasq
echo "# Configuration version : v1.0" > "$DNS_CONFIG_PATH"
echo "# ============================================================" >> "$DNS_CONFIG_PATH"
echo "# dnsmasq – Enregistrements DNS générés automatiquement" >> "$DNS_CONFIG_PATH"
echo "# Domaine : $TRAEFIK_DOMAIN" >> "$DNS_CONFIG_PATH"
echo "# ============================================================" >> "$DNS_CONFIG_PATH"
echo "" >> "$DNS_CONFIG_PATH"
for i in "${!MACHINES_HOST[@]}"; do
  echo "address=/${MACHINES_HOST[$i]}.$TRAEFIK_DOMAIN/${MACHINES_IP[$i]}" >> "$DNS_CONFIG_PATH"
done
echo "" >> "$DNS_CONFIG_PATH"
echo "# Vérifiez et validez ces enregistrements DNS avant déploiement !" >> "$DNS_CONFIG_PATH"

# Génération dynamique de config/squid/squid.conf
cat > config/squid/squid.conf <<EOF
# ============================================================
# Squid – Configuration proxy HTTP/HTTPS
# Lab     : $TRAEFIK_DOMAIN
# Hôte    : ${MACHINES_HOST[0]}.$TRAEFIK_DOMAIN – $SERVER_IP
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


# Génération dynamique du fichier de config AdGuard Home avec hash bcrypt
ADMIN_USER="admin"
ADMIN_PASS="admin"
if command -v htpasswd >/dev/null 2>&1; then
  ADMIN_HASH=$(htpasswd -B -C 10 -n -b "$ADMIN_USER" "$ADMIN_PASS" | cut -d: -f2)
else
  echo -e "${YELLOW}htpasswd non trouvé, le mot de passe sera en clair (non recommandé). Installez apache2-utils ou httpd-tools pour la génération automatique du hash bcrypt.${NC}"
  ADMIN_HASH="$ADMIN_PASS"
fi

cat > config/adguardhome/conf/AdGuardHome.yaml <<EOF
# Configuration version : v1.0
bind_host: 0.0.0.0
bind_port: $ADGUARD_PORT

# --- Authentification administrateur ---
users:
  - name: $ADMIN_USER
    password: $ADMIN_HASH  # Mot de passe par défaut : "$ADMIN_PASS" (hashé si possible)
# IMPORTANT : Changez impérativement ce mot de passe via l'interface web AdGuard Home après la première connexion !
# (Menu Paramètres → Général → Utilisateurs)
EOF

echo -e "${GREEN}Fichier .env et config AdGuard Home générés avec succès !${NC}"
cat .env

echo -e "\n${YELLOW}Prochaines étapes recommandées :${NC}"
echo "1) (Optionnel, si Traefik activé) Générer un hash bcrypt pour l'authentification Traefik :"
echo "   echo \\$(htpasswd -nB admin) | sed -e 's/\\$/\\$\\$/g'"
echo "2) Copier ce hash dans config/traefik/dynamic/middlewares.yml à la place du placeholder."
echo "3) Lancer l'installation de la stack : sudo ./install.sh"
echo "4) Pour plus d'infos, consultez le README.md."
echo -e "\n${RED}IMPORTANT : Le mot de passe admin par défaut d'AdGuard Home est 'admin'. Changez-le impérativement via l'interface web après la première connexion !${NC}"
