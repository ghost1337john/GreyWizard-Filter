### 7. Pourquoi mes entrées DNS locales (rewrites) ne sont-elles plus injectées automatiquement dans AdGuard Home ?
- Suite à un bug, l'injection automatique des entrées DNS locales (bloc rewrites) dans la configuration AdGuard Home a été désactivée temporairement. Il faut désormais ajouter manuellement vos entrées dans la section `rewrites:` du fichier `AdGuardHome.yaml`. Consultez le README pour un exemple de syntaxe.
# Q : Pourquoi dois-je passer par l’assistant web AdGuard Home lors de l’installation ?

R : Par sécurité, le mot de passe admin doit être choisi par l’utilisateur lors du premier lancement via l’assistant web (install.html). Le script d’installation adapte ensuite automatiquement le port d’administration selon votre .env, mais ne modifie plus le mot de passe. Il suffit de relancer `sudo ./install.sh` après avoir terminé l’assistant web.

# FAQ – Stack DNS/Proxy/Reverse Proxy

## Questions fréquentes

### 1. Je n’ai pas d’accès à l’interface web Pi-hole/AdGuard Home
- Vérifiez que le conteneur DNS choisi est bien démarré (`docker compose ps`).
- Vérifiez que le firewall local ou distant n’empêche pas l’accès au port (8080 pour Pi-hole, 3000 pour AdGuard Home).
- Vérifiez que le reverse proxy Traefik est bien démarré.
- Essayez d’accéder à l’interface via l’IP directe et le port local (ex : http://127.0.0.1:8080 ou :3000).

### 2. Les clients du réseau ne sont pas filtrés par le DNS
- Assurez-vous que le DNS des clients pointe bien vers l’IP du serveur (voir .env).
- Vérifiez la redirection DNS sur le firewall/routeur (voir README, section redirection DNS).
- Vérifiez que le service DNS choisi (Pi-hole ou AdGuard Home) est bien en état healthy.

### 3. Le proxy Squid ne fonctionne pas
- Vérifiez que le port 3128 est ouvert et accessible sur le serveur.
- Vérifiez la syntaxe de config/squid/squid.conf.
- Consultez les logs du conteneur Squid (`docker compose logs squid`).

### 4. Problème de certificat HTTPS (Traefik)
- Par défaut, Traefik utilise des certificats auto-signés. Ajoutez le certificat racine à vos clients pour éviter les alertes.
- Pour un certificat local de confiance, utilisez mkcert (voir README).

### 5. Les scripts ne sont pas exécutables
- Rendez-les exécutables : `chmod +x scripts/*.sh install.sh`.

### 6. Je veux changer de moteur DNS après installation
- Modifiez la variable DNS_ENGINE dans .env.
- Relancez la stack avec `bash scripts/compose-up.sh` ou `sudo ./install.sh`.

---

# Dépannage & Debug

## Vérifications de base
- `docker compose ps` : état des conteneurs
- `docker compose logs <service>` : logs détaillés
- `docker compose restart <service>` : redémarrer un service
- `docker compose down && docker compose up -d` : redémarrage complet

## Problèmes courants
- **Port 53 déjà utilisé** : Désactivez systemd-resolved sur Ubuntu (`sudo systemctl stop systemd-resolved`)
- **Erreur de permissions sur les volumes** : Vérifiez les droits sur les dossiers config/ et volumes Docker
- **Erreur de variable d’environnement** : Vérifiez le contenu de .env et relancez generate-env.sh si besoin
- **Problème de résolution DNS** : Testez avec `dig @127.0.0.1 -p 53 google.com` depuis le serveur

## Outils utiles
- `curl`, `dig`, `htpasswd`, `jq`, `yamllint`
- `docker compose logs`, `docker compose exec`, `docker compose ps`

---

Pour toute question ou bug non résolu, ouvrez une issue sur le dépôt GitHub ou contactez le mainteneur.
