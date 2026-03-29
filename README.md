# GreyHaven Lab

Stack de filtrage et reverse proxy pour le lab interne **GreyHaven**.

| Composant | Service           | Rôle                                    |
|-----------|-------------------|-----------------------------------------|
| Pi-hole   | DNS               | Résolution locale + bloqueur publicitaire |
| Squid     | Proxy HTTP/HTTPS  | Cache + anonymisation + filtrage DNS    |
| Traefik   | Reverse Proxy     | Routage HTTPS, dashboard, middlewares   |

---

## Infrastructure

| Hostname               | IP              | Rôle                        |
|------------------------|-----------------|-----------------------------|
| `gandalf.greyhaven`    | 192.168.1.254   | Passerelle / Routeur        |
| `palantir.greyhaven`   | 192.168.1.2     | Hub multimédia              |
| `carcharoth.greyhaven` | 192.168.1.3    | Hôte Docker — stack filtre  |

La stack Docker tourne entièrement sur **carcharoth** (192.168.1.3).

---

## Démarrage rapide


```bash
# 1. Cloner le dépôt (privé)
#   (voir plus bas pour l'accès si besoin de token ou SSH)
cd greyhaven-private

# 2. Préparer l'environnement système (Docker, outils, etc.)
chmod +x scripts/bootstrap-prereqs.sh install.sh scripts/*.sh
sudo ./scripts/bootstrap-prereqs.sh

# 3. Configurer les variables d'environnement
cp .env.example .env
nano .env
#   → Modifier au minimum :
#      - PIHOLE_WEBPASSWORD (mot de passe admin Pi-hole, obligatoire !)
#        Si vous laissez la valeur par défaut, le script d'installation vous demandera automatiquement d'en saisir un avant de poursuivre.
#      - PIHOLE_DNS_ (serveurs DNS amont, séparés par ;)
#      - Autres variables selon besoin

# 4. Générer le hash basicAuth pour Traefik
echo $(htpasswd -nB admin) | sed -e 's/\$/\$\$/g'
#   → Copier la sortie dans config/traefik/dynamic/middlewares.yml à la place du placeholder

# 5. Installer et démarrer la stack
sudo ./install.sh
```

## Procedure automatisee des prerequis

Pour installer automatiquement les prerequis systeme (Docker, Compose, outils DNS, htpasswd, jq), utilise le script bootstrap :


```bash
cd greyhaven-private
chmod +x scripts/bootstrap-prereqs.sh install.sh scripts/*.sh
sudo ./scripts/bootstrap-prereqs.sh
```

Ensuite, configure .env et déploie la stack comme indiqué ci-dessus.

Notes :
- Le script gere Ubuntu/Debian, Fedora/RHEL-like et Arch Linux.
- Sur Ubuntu, si le port 53 est deja pris par systemd-resolved, desactive-le avant le deploiement.
- Si ton utilisateur est ajoute au groupe docker, reconnecte-toi pour que le groupe soit applique.

---

## Services accessibles

| URL                                    | Service              | Auth requise |
|----------------------------------------|----------------------|--------------|
| https://traefik.greyhaven              | Tableau de bord Traefik | Oui (basic) |
| https://pihole.greyhaven/admin         | Interface Pi-hole    | Oui (basic) |
| `192.168.1.3:3128`                    | Proxy Squid          | Non (LAN)   |
| `192.168.1.3:53`                      | DNS Pi-hole          | Non          |

> **Note DNS** : pour résoudre les noms `*.greyhaven`, configurez vos clients et
> serveurs avec `192.168.1.3` comme serveur DNS primaire.

---

## Structure du projet

```
greyhaven/
├── .env.example             ← Variables d'environnement (à copier en .env)
├── docker-compose.yml       ← Stack complète
├── install.sh               ← Installation automatisée
├── uninstall.sh             ← Désinstallation (--purge pour les volumes)
├── config/
│   ├── pihole/
│   │   └── custom.list      ← Enregistrements DNS locaux greyhaven
│   ├── squid/
│   │   └── squid.conf       ← Configuration du proxy
│   ├── traefik/
│   │   ├── traefik.yml      ← Config statique Traefik
│   │   └── dynamic/
│   │       ├── middlewares.yml  ← Auth, headers, rate-limit, TLS
│   │       └── routers.yml      ← Routes vers palantir et gandalf
│   ├── dnsmasq/
│   │   └── greyhaven.conf   ← Config dnsmasq étendue (PTR, domaine local)
│   └── hosts                ← Template /etc/hosts pour les machines du lab
├── network/
│   └── topology.md          ← Schéma réseau et flux de trafic
└── scripts/
        ├── bootstrap-prereqs.sh ← Installation automatisée des prérequis système
        ├── deploy.sh            ← Déploiement avec vérifications et healthchecks
        └── update.sh            ← Mise à jour des images Docker
```

---

## Scripts d'administration GreyHaven

### 1. `scripts/bootstrap-prereqs.sh`
**But :** Installe tous les prérequis système pour le lab GreyHaven.
- Installe Docker Engine + Docker Compose plugin.
- Installe les utilitaires nécessaires (curl, htpasswd, dig, jq, etc.).
- Active et démarre Docker.
- Ajoute l’utilisateur courant au groupe docker.
- Prend en charge Ubuntu/Debian, Fedora/RHEL/Rocky/AlmaLinux, Arch Linux.
- **Usage :**
    ```bash
    sudo ./scripts/bootstrap-prereqs.sh
    ```

### 2. `scripts/deploy.sh`
**But :** Déploie ou redémarre la stack GreyHaven.
- Vérifie la syntaxe des fichiers de configuration (Traefik, Squid, Pi-hole).
- Contrôle la cohérence du fichier `.env`.
- Déploie ou redémarre uniquement les services modifiés.
- Effectue des tests de santé post-déploiement.
- Option `--check` pour un dry-run (vérification sans déploiement).
- **Usage :**
    ```bash
    ./scripts/deploy.sh [--check]
    ```

### 3. `scripts/update.sh`
**But :** Met à jour la stack GreyHaven.
- Télécharge les nouvelles images Docker.
- Redémarre les conteneurs impactés.
- Nettoie les anciennes images.
- Affiche l’état des services après mise à jour.
- **Usage :**
    ```bash
    ./scripts/update.sh
    ```

---

## Configuration DNS des clients

### Option A — DNS manuel par machine

Ajoutez dans `/etc/resolv.conf` (Linux) ou les paramètres réseau :

```
nameserver 192.168.1.3
```

Ou utilisez le fichier [config/hosts](config/hosts) sur les machines sans DNS Pi-hole.

### Option B — DHCP de gandalf

Configurez gandalf (192.168.1.254) pour distribuer `192.168.1.3` comme DNS via DHCP.

---

## TLS en lab privé

Le domaine `.greyhaven` n'est pas enregistré publiquement : Let's Encrypt n'est pas utilisé.
Traefik génère des certificats **auto-signés** par défaut.

Pour un certificat de confiance local (éviter les avertissements navigateur) :

```bash
# Installer mkcert
brew install mkcert       # macOS
# ou : https://github.com/FiloSottile/mkcert#installation

# Créer un CA local et un certificat wildcard
mkcert -install
mkcert "*.greyhaven" greyhaven

# Monter le certificat dans Traefik
# → créer config/traefik/dynamic/tls.yml avec :
# tls:
#   certificates:
#     - certFile: /certs/_wildcard.greyhaven.pem
#       keyFile:  /certs/_wildcard.greyhaven-key.pem
```

---

## Maintenance

```bash
# Mettre à jour les images
./scripts/update.sh

# Redéployer avec vérifications
./scripts/deploy.sh

# Dry-run (vérifier sans déployer)
./scripts/deploy.sh --check

# Voir les logs
docker compose logs -f

# Redémarrer un service
docker compose restart pihole

# Désinstaller (sans supprimer les données)
./uninstall.sh

# Désinstaller et supprimer toutes les données
./uninstall.sh --purge
```

---

## Proxy Squid – Configuration clients

| OS / Navigateur | Paramètre                                      |
|-----------------|------------------------------------------------|
| Linux (env)     | `export http_proxy=http://192.168.1.42:3128`   |
| Firefox         | Préférences → Réseau → Proxy manuel : 192.168.1.42:3128 |
| Windows         | Paramètres → Réseau → Proxy : 192.168.1.42:3128 |
| APT (Debian)    | `/etc/apt/apt.conf.d/99proxy` : `Acquire::http::Proxy "http://192.168.1.42:3128";` |

---

## Références

- [Pi-hole documentation](https://docs.pi-hole.net/)
- [Squid configuration reference](https://www.squid-cache.org/Doc/config/)
- [Traefik v3 documentation](https://doc.traefik.io/traefik/)
- [mkcert](https://github.com/FiloSottile/mkcert)
