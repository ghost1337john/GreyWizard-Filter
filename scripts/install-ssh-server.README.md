# install-ssh-server.sh

Ce script automatise l'installation, la configuration et la sécurisation d'un serveur SSH sur la plupart des distributions Linux (Debian/Ubuntu, Fedora/RHEL, Arch). Il permet également de créer un utilisateur dédié, de générer une paire de clés SSH sécurisée, de configurer le port SSH, et d'attribuer ou non les droits sudo à l'utilisateur.

## Fonctionnalités principales
- Installation automatique d'OpenSSH Server selon la distribution
- Création d'un nouvel utilisateur SSH (optionnel)
- Génération sécurisée d'une paire de clés SSH pour l'utilisateur (optionnel)
- Ajout automatique de la clé publique dans `authorized_keys`
- Possibilité de changer le port SSH par défaut
- Attribution des droits sudo à l'utilisateur (optionnel)
- Permissions et sécurité renforcées sur les fichiers de clés
- Installation et configuration optionnelle de fail2ban pour protéger SSH contre les attaques par force brute
   - Personnalisation interactive du nombre d'essais (maxretry) et de la durée de bannissement (bantime)
- Configuration interactive d'une bannière de connexion SSH (affichée avant login)
- Renforcement automatique des permissions sur les fichiers critiques SSH
- Rapport récapitulatif de la configuration à la fin du script

## Utilisation

1. **Rendez le script exécutable** :
   ```bash
   chmod +x scripts/install-ssh-server.sh
   ```

2. **Lancez le script en root (sudo)** :
   ```bash
   sudo ./scripts/install-ssh-server.sh
   ```

3. **Suivez les instructions interactives** :
   - Le script détecte la distribution et installe le serveur SSH.
   - Il propose de créer un nouvel utilisateur SSH.
   - Il propose de générer une paire de clés SSH sécurisée pour cet utilisateur.
   - Il propose de changer le port SSH par défaut.
   - Il demande si l'utilisateur doit avoir les droits sudo.

4. **Après l'exécution** :
   - La clé privée générée (si choisie) se trouve dans `/home/<utilisateur>/.ssh/id_ed25519`. Sauvegardez-la en lieu sûr !
   - Testez la connexion SSH avec la clé privée avant de fermer la session root.
   - Instructions détaillées pour récupérer la clé privée SSH sur le poste client (Linux/macOS/Windows) et rappel de la supprimer du serveur après transfert

## Exemple de session
```
Voulez-vous créer un nouvel utilisateur pour SSH ? (y/n) : y
Nom du nouvel utilisateur : alice
Voulez-vous générer une paire de clés SSH pour alice ? (y/n) : y
alice doit-il avoir les droits sudo ? (y/n) : y
Voulez-vous changer le port SSH par défaut (22) ? (y/n) : y
Nouveau port SSH : 2222
```

## Sécurité
- Les permissions sur les fichiers de clés et le dossier `.ssh` sont strictes.
- La clé privée ne doit jamais être partagée.
- Pensez à désactiver l'authentification par mot de passe dans `/etc/ssh/sshd_config` pour plus de sécurité.

## Dépannage
- Vérifiez le statut du service SSH :
  ```bash
  sudo systemctl status sshd
  # ou
  sudo systemctl status ssh
  ```
- Consultez les logs en cas de problème de connexion :
  ```bash
  sudo journalctl -u sshd
  ```

---
Script généré par GitHub Copilot, 2026.
