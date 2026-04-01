# FAQ – Stack DNS/Proxy/Reverse Proxy

## Questions fréquentes

### 1. Je n’ai pas d’accès à l’interface web AdGuard Home
- Vérifiez que le conteneur AdGuard Home est bien démarré (`docker compose ps`).
- Vérifiez que le firewall local ou distant n’empêche pas l’accès au port publié pour votre interface web.
- Vérifiez que le reverse proxy Traefik est bien démarré.
- Essayez d’accéder à l’interface via l’IP directe et le port local configuré (ex : `http://127.0.0.1:${ADGUARD_PORT}` si vous utilisez AdGuard Home).

- Assurez-vous que le DNS des clients pointe bien vers l’IP du serveur (voir .env, variable DOMAIN).
- Vérifiez la redirection DNS sur le firewall/routeur (voir README, section redirection DNS).
- Vérifiez que le service AdGuard Home est bien en état healthy.

### 2. Pourquoi Traefik ou les certificats TLS ne fonctionnent-ils pas comme prévu ?
- Par défaut, Traefik utilise des certificats auto-signés. Ajoutez le certificat racine à vos clients pour éviter les alertes.
- Pour un certificat local de confiance, utilisez mkcert (voir README).
- Le domaine utilisé pour les URL (ex : `traefik.${DOMAIN}`) est défini dans le `.env`.
- Si vous activez l'auth basic Traefik, elle s'ajoute à l'authentification propre de l'application derrière Traefik. AdGuard Home demande donc son propre mot de passe après le passage dans Traefik.

### 3. Le proxy Squid ne fonctionne pas
- Vérifiez que le port 3128 est ouvert et accessible sur le serveur.
- Vérifiez la syntaxe de config/squid/squid.conf.
- Consultez les logs du conteneur Squid (`docker compose logs squid`).

### 4. Faut-il acheter un nom de domaine pour cette infrastructure ?
- Pas pour faire fonctionner la stack en local.
- Oui si vous voulez des certificats Let's Encrypt valides via Traefik en DNS-01 ou une exposition avec un vrai nom public.
- Non si vous restez sur un domaine interne de type `lab.local`, mais dans ce cas il faut utiliser un certificat auto-signé ou `mkcert` au lieu de Let's Encrypt.

### 5. Les scripts ne sont pas exécutables
- Rendez-les exécutables : `chmod +x scripts/*.sh install.sh`.

### 6. Je veux changer de moteur DNS après installation
- Modifiez la variable DNS_ENGINE dans .env.
- Relancez la stack avec `bash scripts/compose-up.sh` ou `sudo ./install.sh`.

### 7. Pourquoi mes entrées DNS locales (rewrites) ne sont-elles plus injectées automatiquement dans AdGuard Home ?
- Suite à un bug, l'injection automatique des entrées DNS locales (bloc rewrites) dans la configuration AdGuard Home a été désactivée temporairement.
- Ajoutez désormais vos entrées manuellement dans la section `rewrites:` du fichier `AdGuardHome.yaml`.
- Consultez le README pour un exemple de syntaxe.

### 8. Pourquoi dois-je passer par l’assistant web AdGuard Home lors de l’installation ?
- Par sécurité, le mot de passe admin doit être choisi par l’utilisateur lors du premier lancement via l’assistant web `install.html`.
- Le script d’installation adapte ensuite automatiquement le port d’administration selon votre `.env`, mais ne modifie plus le mot de passe.
- Il suffit de relancer `sudo ./install.sh` après avoir terminé l’assistant web.

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
