# install-ssh-server.sh

Ce script automatise l'installation, la configuration et la sécurisation d'un serveur SSH sur la plupart des distributions Linux (Debian/Ubuntu, Fedora/RHEL, Arch). Il permet également de créer un utilisateur dédié, de générer une paire de clés SSH sécurisée, de configurer le port SSH, et d'attribuer ou non les droits sudo à l'utilisateur.

## Fonctionnalités principales
- Installation automatique d'OpenSSH Server selon la distribution
- Création d'un nouvel utilisateur SSH (optionnel)
- Ajout de la clé publique générée sur le poste client dans `authorized_keys`
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
   - Il explique comment ajouter une clé publique SSH générée sur le poste client pour cet utilisateur.
   - Il propose de changer le port SSH par défaut.
   - Il demande si l'utilisateur doit avoir les droits sudo.

4. **Après l'exécution** :
   - La clé privée doit être générée et conservée uniquement sur votre poste client. Ne transférez jamais la clé privée sur le serveur.
   - Testez la connexion SSH avec la clé privée depuis votre poste client avant de fermer la session root.

## Exemple de session
```
Voulez-vous créer un nouvel utilisateur pour SSH ? (y/n) : y
Nom du nouvel utilisateur : alice
alice doit-il avoir les droits sudo ? (y/n) : y
Voulez-vous changer le port SSH par défaut (22) ? (y/n) : y
Nouveau port SSH : 2222
```

## Génération et ajout de la clé SSH (à faire sur le poste client)

1. **Générez une paire de clés SSH sur votre poste client** :
   ```bash
   ssh-keygen -t ed25519 -a 100 -C "poste-client"
   ```
   (Laissez le chemin par défaut et protégez la clé par une passphrase si possible)

2. **Copiez la clé publique sur le serveur** :
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub alice@<IP_SERVEUR>
   ```
   ou, si `ssh-copy-id` n'est pas disponible :
   ```bash
   cat ~/.ssh/id_ed25519.pub | ssh alice@<IP_SERVEUR> 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
   ```

3. **Testez la connexion SSH** :
   ```bash
   ssh alice@<IP_SERVEUR>
   ```

**Ne transférez jamais la clé privée sur le serveur !**

## Sécurité
- Les permissions sur les fichiers de clés et le dossier `.ssh` sont strictes.
- La clé privée ne doit jamais être partagée ni copiée sur le serveur.
- Pensez à désactiver l'authentification par mot de passe dans `/etc/ssh/sshd_config` pour plus de sécurité, une fois la connexion par clé vérifiée.

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
