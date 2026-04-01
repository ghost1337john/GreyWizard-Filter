# Guides de configuration – Interfaces web & fichiers

Ce document regroupe des guides pratiques pour configurer chaque service de la stack via leur interface web ou fichier de configuration, selon les besoins courants.

Important pour les noms de domaine et TLS :
- si vous utilisez un domaine interne uniquement, la stack fonctionne en local mais Let's Encrypt ne pourra pas émettre de certificat valide
- si vous voulez des certificats Let's Encrypt via Traefik, utilisez un nom de domaine public enregistré que vous contrôlez et configurez correctement votre DNS
- sans domaine public, utilisez un certificat auto-signé ou `mkcert`

Pour un domaine interne, il faut aussi adapter la config Traefik :
- retirer les labels `tls.certresolver=letsencrypt` dans `docker-compose.yml`
- générer un certificat local
- renseigner `config/traefik/dynamic/tls.yml` avec `certFile` et `keyFile`
- redémarrer Traefik

---


- URL : https://adguard.${DOMAIN} (le domaine est défini dans le .env)
- Authentification :
- d'abord basicAuth Traefik si elle est activée dans `config/traefik/dynamic/middlewares.yml`
- ensuite le compte admin propre à AdGuard Home, défini au premier lancement ou dans `AdGuardHome.yaml`

### Exemples de configuration
- **Ajouter une liste de filtres** :
  1. Menu « Filtres » > « Listes de filtres »
  2. Cliquer sur « Ajouter une liste de filtres »
  3. Coller l’URL, valider
- **Bloquer un domaine** :
  1. Menu « Filtres » > « Règles personnalisées »
  2. Ajouter une règle du type : `||domaine.com^`
- **Autoriser un domaine** :
  1. Menu « Filtres » > « Règles personnalisées »
  2. Ajouter une règle du type : `@@||domaine.com^`
- **Voir les requêtes DNS** :
  1. Menu « Statistiques » > « Requêtes DNS »

---

- URL : https://traefik.${DOMAIN} (le domaine est défini dans le .env)
- Authentification : basicAuth configurée dans `config/traefik/dynamic/middlewares.yml`
- Le hash bcrypt doit être généré localement avec `htpasswd -nB <utilisateur>` puis collé dans le fichier sans commiter de valeur réelle dans le dépôt.

### Exemples de configuration
- **Voir l’état des routes/services** :
  1. Accéder au dashboard, menu « HTTP Routers » ou « Services »
- **Ajouter une règle d’accès** :
  1. Modifier config/traefik/dynamic/routers.yml ou middlewares.yml
  2. Redémarrer Traefik si besoin

---

## Squid (fichier de configuration)

### Accès
- Fichier : config/squid/squid.conf
- Pas d’interface web, configuration par fichier

### Exemples de configuration
- **Restreindre l’accès à certains sites** :
  1. Ajouter une ACL : `acl interdits dstdomain .facebook.com .twitter.com`
  2. Ajouter une règle : `http_access deny interdits`
- **Limiter l’accès au proxy à certains IP** :
  1. Ajouter une ACL : `acl reseau_local src 192.168.10.0/24`
  2. Ajouter une règle : `http_access allow reseau_local`
- **Activer le cache** :
  1. Vérifier/adapter les directives `cache_dir`, `cache_mem`, etc.

---

Pour des besoins spécifiques, demande une doc ciblée ou un exemple détaillé !
