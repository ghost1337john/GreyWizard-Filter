# Guides de configuration – Interfaces web & fichiers

Ce document regroupe des guides pratiques pour configurer chaque service de la stack via leur interface web ou fichier de configuration, selon les besoins courants.

---


- URL : https://adguard.${DOMAIN} (le domaine est défini dans le .env)
- Authentification : login admin (défini au premier lancement ou dans AdGuardHome.yaml)

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
- Authentification : basicAuth (login admin, mot de passe hashé dans config/traefik/dynamic/middlewares.yml)

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
