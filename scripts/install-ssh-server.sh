#!/usr/bin/env bash
# ============================================================
# Script d'installation OpenSSH Server (Linux)
# Usage : sudo ./install-ssh-server.sh
# Ce script installe et active le serveur SSH sur la plupart des distributions Linux.
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [[ $EUID -ne 0 ]]; then
  log_error "Ce script doit être exécuté en root (sudo)."
  exit 1
fi

# Détection de la distribution
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  log_error "Impossible de détecter la distribution."
  exit 1
fi

case "$DISTRO" in
  ubuntu|debian)
    log_info "Installation OpenSSH Server (apt)..."
    apt-get update -y
    apt-get install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
    ;;
  fedora|rhel|rocky|almalinux|centos)
    log_info "Installation OpenSSH Server (dnf/yum)..."
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y openssh-server
    else
      yum install -y openssh-server
    fi
    systemctl enable sshd
    systemctl start sshd
    ;;
  arch)
    log_info "Installation OpenSSH Server (pacman)..."
    pacman -Sy --noconfirm openssh
    systemctl enable sshd
    systemctl start sshd
    ;;
  *)
    log_warn "Distribution non reconnue. Installez openssh-server manuellement."
    exit 1
    ;;
esac

# Demande d'un nouvel utilisateur SSH (optionnel)
read -rp "Voulez-vous créer un nouvel utilisateur pour SSH ? (y/n) : " CREATE_USER
if [[ "$CREATE_USER" =~ ^[Yy]$ ]]; then
  read -rp "Nom du nouvel utilisateur : " SSH_USER
  if id "$SSH_USER" &>/dev/null; then
    log_warn "L'utilisateur $SSH_USER existe déjà."
  else
    useradd -m -s /bin/bash "$SSH_USER"
    log_success "Utilisateur $SSH_USER créé."
  fi
  passwd "$SSH_USER"
  log_info "Ajoutez la clé publique SSH pour $SSH_USER dans /home/$SSH_USER/.ssh/authorized_keys si besoin."
  # Création de clé SSH pour l'utilisateur (optionnel et sécurisé)
  if [[ "$CREATE_USER" =~ ^[Yy]$ ]]; then
    read -rp "Voulez-vous générer une paire de clés SSH pour $SSH_USER ? (y/n) : " GEN_KEY
    if [[ "$GEN_KEY" =~ ^[Yy]$ ]]; then
      su - "$SSH_USER" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
      su - "$SSH_USER" -c "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C '$SSH_USER@$(hostname)' < /dev/null"
      su - "$SSH_USER" -c "cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 600 ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub"
      chown -R "$SSH_USER:$SSH_USER" "/home/$SSH_USER/.ssh"
      log_success "Clé SSH générée et ajoutée à authorized_keys pour $SSH_USER."
      log_info "Clé privée disponible dans /home/$SSH_USER/.ssh/id_ed25519 (à sauvegarder et protéger !)."
      log_warn "La clé privée NE DOIT PAS être partagée. Sauvegardez-la en lieu sûr."
    fi
  fi
  # Demande si l'utilisateur doit avoir les droits sudo
  read -rp "L'utilisateur $SSH_USER doit-il avoir les droits sudo ? (y/n) : " SUDO_USER
  if [[ "$SUDO_USER" =~ ^[Yy]$ ]]; then
    usermod -aG sudo "$SSH_USER"
    log_success "$SSH_USER ajouté au groupe sudo."
  else
    log_info "$SSH_USER n'aura pas les droits sudo."
  fi
fi

# Demande de changement du port SSH (optionnel)
read -rp "Voulez-vous changer le port SSH par défaut (22) ? (y/n) : " CHANGE_PORT
if [[ "$CHANGE_PORT" =~ ^[Yy]$ ]]; then
  read -rp "Nouveau port SSH : " SSH_PORT
  if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
    log_error "Port invalide."
    exit 1
  fi
  sed -i.bak "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  log_success "Port SSH changé en $SSH_PORT."
fi

# Installation et configuration de fail2ban (optionnel)
read -rp "Voulez-vous installer et activer fail2ban pour protéger SSH ? (y/n) : " INSTALL_F2B
if [[ "$INSTALL_F2B" =~ ^[Yy]$ ]]; then
  case "$DISTRO" in
    ubuntu|debian)
      apt-get install -y fail2ban
      ;;
    fedora|rhel|rocky|almalinux|centos)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y fail2ban
      else
        yum install -y fail2ban
      fi
      ;;
    arch)
      pacman -Sy --noconfirm fail2ban
      ;;
    *)
      log_warn "Distribution non reconnue pour fail2ban. Installez-le manuellement."
      ;;
  esac
  # Configuration basique pour SSH
  F2B_JAIL="/etc/fail2ban/jail.local"
  if [[ ! -f "$F2B_JAIL" ]]; then
    echo -e "[sshd]\nenabled = true\nport = ssh\nlogpath = /var/log/auth.log\nmaxretry = 5\nbantime = 1h\n" > "$F2B_JAIL"
  fi
  # Configuration personnalisée fail2ban
  if [[ -f "$F2B_JAIL" ]]; then
    read -rp "Nombre d'essais avant bannissement (maxretry, défaut 5) : " F2B_MAXRETRY
    F2B_MAXRETRY=${F2B_MAXRETRY:-5}
    read -rp "Durée du bannissement (bantime, ex: 1h, 10m, défaut 1h) : " F2B_BANTIME
    F2B_BANTIME=${F2B_BANTIME:-1h}
    sed -i "s/^maxretry = .*/maxretry = $F2B_MAXRETRY/" "$F2B_JAIL"
    sed -i "s/^bantime = .*/bantime = $F2B_BANTIME/" "$F2B_JAIL"
    log_success "fail2ban configuré : $F2B_MAXRETRY essais, bannissement $F2B_BANTIME."
  fi
  systemctl enable fail2ban
  systemctl restart fail2ban
  log_success "fail2ban installé et activé pour SSH."
else
  log_info "fail2ban non installé. Pensez à l'ajouter pour plus de sécurité."
fi

# Redémarrage du service SSH pour appliquer les changements
if [[ "$DISTRO" =~ (ubuntu|debian) ]]; then
  systemctl restart ssh
else
  systemctl restart sshd
fi
log_success "Configuration SSH terminée. Testez la connexion avant de fermer la session !"

# 5. Configurer une bannière de connexion SSH (optionnel)
read -rp "Voulez-vous configurer une bannière de connexion SSH ? (y/n) : " SET_BANNER
if [[ "$SET_BANNER" =~ ^[Yy]$ ]]; then
  read -rp "Texte de la bannière (affiché avant login) : " SSH_BANNER
  echo "$SSH_BANNER" > /etc/issue.net
  sed -i.bak 's|^#\?Banner .*|Banner /etc/issue.net|' /etc/ssh/sshd_config
  log_success "Bannière SSH configurée."
fi

# 8. Vérification et renforcement des permissions sur les fichiers critiques
chmod 600 /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
if [[ -d /etc/ssh ]]; then
  chmod 755 /etc/ssh
fi
log_info "Permissions renforcées sur /etc/ssh/sshd_config."

# 10. Rapport récapitulatif
log_info "\n===== RAPPORT FINAL DE CONFIGURATION SSH ====="
log_info "Port SSH : $(grep ^Port /etc/ssh/sshd_config | awk '{print $2}' || echo 22)"
if [[ -n "${SSH_USER:-}" ]]; then
  log_info "Utilisateur créé : $SSH_USER"
  if id -nG "$SSH_USER" | grep -qw sudo; then
    log_info "Droits sudo : OUI"
  else
    log_info "Droits sudo : NON"
  fi
  if [[ -f "/home/$SSH_USER/.ssh/id_ed25519" ]]; then
    log_info "Clé SSH générée pour $SSH_USER : OUI"
  else
    log_info "Clé SSH générée pour $SSH_USER : NON"
  fi
fi
if [[ -f /etc/issue.net ]]; then
  log_info "Bannière SSH activée : OUI"
else
  log_info "Bannière SSH activée : NON"
fi
if systemctl is-active --quiet fail2ban; then
  log_info "fail2ban actif : OUI"
else
  log_info "fail2ban actif : NON"
fi
log_info "Permissions /etc/ssh/sshd_config : $(stat -c '%a %U:%G' /etc/ssh/sshd_config)"
log_info "===== FIN DU RAPPORT =====\n"

# Instructions pour récupérer la clé privée sur le poste client
if [[ -n "${SSH_USER:-}" && -f "/home/$SSH_USER/.ssh/id_ed25519" ]]; then
  log_info "\n===== RÉCUPÉRATION DE LA CLÉ PRIVÉE POUR LE CLIENT ====="
  log_info "Pour transférer la clé privée sur votre poste client :"
  log_info "Sous Linux/macOS :"
  echo "  scp root@<IP_SERVEUR>:/home/$SSH_USER/.ssh/id_ed25519 <chemin_local>"
  log_info "Sous Windows (avec WinSCP ou scp) :"
  echo "  Utilisez WinSCP en mode SFTP, connectez-vous en root, puis téléchargez /home/$SSH_USER/.ssh/id_ed25519"
  echo "  Ou avec scp (depuis PowerShell) :"
  echo "  scp root@<IP_SERVEUR>:/home/$SSH_USER/.ssh/id_ed25519 C:\\Users\\<VotreNom>\\.ssh\\id_ed25519"
  log_warn "Après transfert, supprimez la clé privée du serveur : rm /home/$SSH_USER/.ssh/id_ed25519"
  log_info "Assurez-vous que les permissions de la clé privée sont strictes (chmod 600)."
  log_info "N'utilisez jamais la clé privée sur plusieurs postes sans précaution."
fi
