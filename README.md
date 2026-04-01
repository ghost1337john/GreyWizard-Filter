
> ⚠️ **DISCLAIMER :** ce projet a été testé et déployé dans un lab domestique réel, mais il peut encore contenir des bugs ou nécessiter des ajustements selon votre environnement.


# GreyWizard-Filter : la stack de filtrage et reverse proxy adaptable à tout lab ou réseau local

---

## Il était une fois... (prologue façon Seigneur des Anneaux)

Dans les terres numériques du LAN, là où les publicités et les trackers rôdent dans l’ombre, un magicien se dressa pour protéger les royaumes des utilisateurs. Son nom : **GreyWizard-Filter**.

Guidé par la sagesse de Gandalf, la force d'Aragorn et la lumière d'Eärendil, ce projet réunit trois artefacts légendaires :

- **AdGuard Home** (le Gardien du DNS) : repousse les armées de publicités et de malwares, filtrant les requêtes indésirables comme un bouclier elfique.
- **Squid** (le Proxy Caméléon) : dissimule les traces des voyageurs du réseau, met en cache les savoirs, et détourne les regards indiscrets.
- **Traefik** (le Passeur de Portails) : ouvre les portes sécurisées du royaume, distribue les certificats magiques et veille sur les accès aux tours de contrôle.

Ensemble, ils forment la **Communauté du Filtre**, protégeant votre lab des forces obscures du web. Mais n’ayez crainte, jeune hobbit : l’installation est plus simple que de traverser la Moria, et la configuration s’adapte à tous les royaumes, du plus modeste des villages au plus vaste des citadelles.

---


| AdGuard Home | DNS               | Résolution locale + bloqueur publicitaire |
| Squid        | Proxy HTTP/HTTPS  | Cache + anonymisation + filtrage DNS    |
| Traefik      | Reverse Proxy     | Routage HTTPS, dashboard, middlewares *(en test, intégration officielle dans une prochaine release)* |

---


> **ℹ️ Statut :** le projet a été testé et mis en place dans le lab personnel du mainteneur. AdGuard Home, Squid et Traefik ont été validés ensemble dans cet environnement, mais des adaptations peuvent rester nécessaires selon votre réseau, votre DNS et votre distribution Linux.

> **ℹ️ Domaine et certificats TLS :** si vous voulez des certificats Let's Encrypt via DNS-01, vous devez disposer d'un nom de domaine public que vous contrôlez réellement, en pratique un domaine enregistré chez un registrar et géré par un fournisseur DNS compatible comme Cloudflare. Un domaine purement interne de type `lab.local` ou un sous-domaine non délégué publiquement ne permet pas d'obtenir ces certificats. Dans ce cas, utilisez un certificat auto-signé ou `mkcert`.

## Fonctionnement global des outils

- **AdGuard Home** : Fournit la résolution DNS locale pour tout le réseau et bloque la publicité/les trackers.
    - Interface web sur https://adguard.${DOMAIN}
    - Les entrées DNS locales (machines du lab) doivent être ajoutées manuellement dans la section `rewrites:` de la configuration AdGuard Home. L'injection automatique est désactivée temporairement suite à un bug.
    - La variable `DOMAIN` peut être un domaine interne pour un usage local, ou un domaine public si vous voulez des certificats Let's Encrypt.
- **Squid** : Sert de proxy HTTP/HTTPS pour les clients du réseau. Il permet le cache, l’anonymisation et le filtrage DNS des requêtes web. Les clients peuvent configurer leur navigateur ou OS pour passer par Squid.
- **Traefik** : Reverse proxy qui gère le routage HTTPS, la terminaison TLS (certificats auto-signés ou mkcert), l’accès sécurisé aux interfaces web (dashboard Traefik, AdGuard admin) et l’application de middlewares (authentification, headers, etc.).


**Flux typique :**
- Un client configure son DNS sur AdGuard Home (IP définie dans le .env) et, s’il le souhaite, son proxy HTTP sur Squid (IP:port définis dans le .env).
- Les requêtes DNS passent par AdGuard Home, qui filtre et résout localement ou en amont.
- Les requêtes web passent par Squid, qui peut les filtrer, les cacher et les anonymiser.
- Les accès aux interfaces web (admin AdGuard, dashboard Traefik) passent par Traefik, qui applique HTTPS et l’authentification.

---

## Exemple d'infrastructure (personnalisable)

| Hostname                | IP              | Rôle                        |
|-------------------------|-----------------|-----------------------------|
| `passerelle.${DOMAIN}` | 192.168.10.1    | Passerelle / Routeur        |
| `hub.${DOMAIN}`        | 192.168.10.2    | Hub multimédia              |
| `serveur.${DOMAIN}`    | 192.168.10.10   | Hôte Docker — stack filtre  |

La stack Docker tourne sur le serveur principal défini lors de l'installation (voir .env, variable DOMAIN).
#
# ℹ️ Le domaine utilisé pour toutes les URL (ex : `intranet.home.arpa` pour un usage interne, ou `lab.example.com` pour un domaine public) est défini dans le fichier .env via la variable DOMAIN. Modifiez cette variable pour adapter la stack à votre environnement.

---

## Démarrage rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/ghost1337john/GreyWizard-Filter.git
cd GreyWizard-Filter


# 2. Préparer l'environnement système (Docker, outils, etc.)
sudo bash ./scripts/bootstrap-prereqs.sh


# 3. Générer la configuration interactive
sudo bash ./scripts/generate-env.sh

# 4. (Optionnel, si Traefik activé) Générer un hash bcrypt pour l'authentification Traefik :
htpasswd -nB admin

# 5. Copier la ligne complète renvoyée dans config/traefik/dynamic/middlewares.yml
#    à la place du placeholder prévu pour basicAuth.

# 6. Installer la stack (premier lancement)
sudo bash ./install.sh

# 7. Lors du premier lancement, ouvrez votre navigateur sur http://<IP>:<PORT> (ex : http://192.168.1.3:8080)
#    et terminez l'assistant d'installation web AdGuard Home (choix du mot de passe admin, etc.).
#    Laissez le script attendre ou relancez ./install.sh après l'installation web.
```

---

## Accès Traefik (dashboard, certificats, sécurité)

- **Dashboard Traefik** : https://traefik.${DOMAIN}
- **Authentification** : protégée par basic auth (voir ci-dessous)
- **Certificat TLS** : auto-signé par défaut (voir ci-dessous)

Si vous voulez remplacer le certificat auto-signé par un certificat Let's Encrypt, il vous faut :
- un domaine public enregistré et contrôlé par vous
- la possibilité de créer des enregistrements DNS sur cette zone
- un token API DNS limité à cette zone si vous utilisez DNS-01 avec Cloudflare

Si vous n'avez pas de domaine public, gardez un domaine interne et utilisez `mkcert` ou un certificat auto-signé.

**1. Générer le hash d’authentification**

Pour activer l’accès sécurisé au dashboard Traefik, générez un hash bcrypt :

```bash
htpasswd -nB admin
```

Copiez la ligne complète obtenue dans `config/traefik/dynamic/middlewares.yml` à la place du placeholder.

Ne commitez pas un hash réel, un mot de passe, un token Cloudflare ou une adresse email personnelle dans le dépôt. Utilisez des placeholders dans les exemples et renseignez vos vraies valeurs uniquement dans votre environnement de déploiement.

**2. Générer un certificat auto-signé**

Pour éviter les avertissements navigateur, générez un certificat local :

```bash
./scripts/generate-traefik-cert.sh
```

Les fichiers seront créés dans `traefik_certs/` et utilisés automatiquement.

Vous pouvez aussi utiliser [mkcert](https://github.com/FiloSottile/mkcert) pour un certificat reconnu localement.

**3. Documentation Traefik**

[Traefik v3 documentation](https://doc.traefik.io/traefik/)

```bash
# 8. Relancez l'installation pour appliquer automatiquement le port choisi dans .env et injecter les entrées DNS locales dans la section rewrites :
sudo bash ./install.sh

# 9. (Optionnel) Redémarrez la stack si besoin :
sudo docker compose restart
```

> ⚠️ **Important** : Ne lancez pas `compose-up.sh` avant `install.sh` !
> Le script d'installation prépare l'environnement, crée les dossiers et fichiers nécessaires, et vérifie la configuration. Si vous inversez l'ordre, la stack risque de ne pas démarrer correctement ou d'être incomplète.

> ℹ️ **Astuce** : Utilisez toujours `sudo bash ...` pour éviter les problèmes de droits lors de l'installation et du lancement des scripts.

## Procedure automatisee des prerequis

Pour installer automatiquement les prerequis systeme (Docker, Compose, outils DNS, htpasswd, jq), utilise le script bootstrap :


```bash
cd lab-example
chmod +x scripts/bootstrap-prereqs.sh install.sh scripts/*.sh
sudo ./scripts/bootstrap-prereqs.sh
```

Ensuite, configure .env et déploie la stack comme indiqué ci-dessus.

Notes :
- Le script gere Ubuntu/Debian, Fedora/RHEL-like et Arch Linux.
- Sur Ubuntu, si le port 53 est deja pris par systemd-resolved, desactive-le avant le deploiement.
- Si ton utilisateur est ajoute au groupe docker, reconnecte-toi pour que le groupe soit applique.

---


## Résolution DNS locale automatisée

Lors de la génération de l'environnement, les machines déclarées sont automatiquement ajoutées dans la section `rewrites:` de la configuration AdGuard Home (`AdGuardHome.yaml`). Cela permet une résolution locale immédiate de tous les hôtes du lab, sans configuration manuelle dans l'interface web.

Exemple généré :

```yaml
rewrites:
    - domain: host1.${DOMAIN}
        answer: 192.168.10.10
        enabled: true
    - domain: passerelle.${DOMAIN}
        answer: 192.168.10.1
        enabled: true
```

---

## Services accessibles

| URL                                    | Service              | Auth requise |
|----------------------------------------|----------------------|--------------|
| https://traefik.${DOMAIN}              | Tableau de bord Traefik | Oui (basic) |
| https://adguard.${DOMAIN}              | Interface AdGuard Home  | Oui (basic puis login AdGuard) |
| `<IP_DU_SERVEUR>:3128`                 | Proxy Squid             | Non (LAN)   |
| `<IP_DU_SERVEUR>:53`                   | DNS AdGuard Home        | Non         |

> **Note DNS** : pour résoudre les noms `*.${DOMAIN}`, configurez vos clients et
> serveurs avec l'IP de votre serveur AdGuard Home comme DNS primaire.

---

## Structure du projet

```
lab-example/
├── .env.example             ← Variables d'environnement (à copier en .env)
├── docker-compose.yml       ← Stack complète
├── install.sh               ← Installation automatisée
├── uninstall.sh             ← Désinstallation (--purge pour les volumes)
├── config/
│   ├── adguardhome/
│   │   └── custom.list      ← Enregistrements DNS locaux ${DOMAIN} (si besoin)
│   ├── squid/
│   │   └── squid.conf       ← Configuration du proxy
│   ├── traefik/
│   │   ├── traefik.yml      ← Config statique Traefik
│   │   └── dynamic/
│   │       ├── middlewares.yml  ← Auth, headers, rate-limit, TLS
│   │       └── routers.yml      ← Routes vers media et gw
│   ├── dnsmasq/
│   │   └── lab.conf         ← Config dnsmasq étendue (PTR, domaine local)
│   └── hosts                ← Template /etc/hosts pour les machines du lab
├── network/
│   └── topology.md          ← Schéma réseau et flux de trafic
└── scripts/
    ├── bootstrap-prereqs.sh ← Installation automatisée des prérequis système
    ├── deploy.sh            ← Déploiement avec vérifications et healthchecks
    └── update.sh            ← Mise à jour des images Docker
```

---

## Scripts d'administration du lab

### 1. `scripts/bootstrap-prereqs.sh`
**But :** Installe tous les prérequis système pour le lab.
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
**But :** Déploie ou redémarre la stack du lab.
- Vérifie la syntaxe des fichiers de configuration (Traefik, Squid, AdGuard Home).
- Contrôle la cohérence du fichier `.env`.
- Déploie ou redémarre uniquement les services modifiés.
- Effectue des tests de santé post-déploiement.
- Option `--check` pour un dry-run (vérification sans déploiement).
- **Usage :**
    ```bash
    ./scripts/deploy.sh [--check]
    ```

### 3. `scripts/update.sh`
**But :** Met à jour la stack du lab.
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

Ou utilisez le fichier [config/hosts](config/hosts) sur les machines sans DNS AdGuard Home.

### Option B — DHCP de gandalf

Configurez gandalf (192.168.1.254) pour distribuer `192.168.1.3` comme DNS via DHCP.

---

## TLS en lab privé

Si vous utilisez un domaine interne non public, par exemple `intranet.home.arpa`, Let's Encrypt ne peut pas émettre de certificat valide pour cette zone.
Traefik doit alors utiliser des certificats **auto-signés** ou des certificats générés avec `mkcert`.

Si vous voulez des certificats Let's Encrypt valides, utilisez à la place un domaine public enregistré que vous contrôlez et configurez le challenge DNS-01.

### Adaptation de la configuration pour un domaine interne

Pour faire fonctionner la stack sans domaine public, adaptez explicitement la configuration de cette façon :

1. Dans `.env`, définissez `DOMAIN` avec votre domaine interne, par exemple `intranet.home.arpa`.
2. N'utilisez pas les valeurs ACME/Cloudflare pour ce mode ; elles ne serviront pas à émettre un certificat valide.
3. Dans `docker-compose.yml`, retirez ou commentez les labels `traefik.http.routers.*.tls.certresolver=letsencrypt` sur les routeurs Traefik et AdGuard Home.
4. Générez un certificat local :
     - soit avec `./scripts/generate-traefik-cert.sh`
     - soit avec `mkcert`
5. Placez les fichiers du certificat et de la clé dans `traefik_certs/`.
6. Renseignez `config/traefik/dynamic/tls.yml` avec la référence vers ces fichiers.
7. Redémarrez Traefik avec `docker compose up -d --force-recreate traefik`.

Exemple minimal de `config/traefik/dynamic/tls.yml` pour un certificat local :

```yaml
tls:
    stores:
        default:
            defaultCertificate:
                certFile: /certs/local.crt
                keyFile: /certs/local.key
```

Avec `mkcert`, vous pouvez aussi utiliser d'autres noms de fichiers, mais il faut alors adapter `certFile` et `keyFile` dans `config/traefik/dynamic/tls.yml`.

Pour un certificat de confiance local (éviter les avertissements navigateur) :

```bash
# Installer mkcert
brew install mkcert       # macOS
# ou : https://github.com/FiloSottile/mkcert#installation

# Créer un CA local et un certificat wildcard
mkcert -install
mkcert "*.<votre-domaine-interne>" <votre-domaine-interne>

# Monter le certificat dans Traefik
# → adapter config/traefik/dynamic/tls.yml avec :
# tls:
#   stores:
#     default:
#       defaultCertificate:
#         certFile: /certs/_wildcard.<votre-domaine-interne>.pem
#         keyFile: /certs/_wildcard.<votre-domaine-interne>-key.pem
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
docker compose restart adguardhome

# Désinstaller (sans supprimer les données)
./uninstall.sh

# Désinstaller et supprimer toutes les données
./uninstall.sh --purge
```

---

## Proxy Squid – Configuration clients

| OS / Navigateur | Paramètre                                      |
|-----------------|------------------------------------------------|
| Linux (env)     | `export http_proxy=http://192.168.10.10:3128`   |
| Firefox         | Préférences → Réseau → Proxy manuel : 192.168.10.10:3128 |
| Windows         | Paramètres → Réseau → Proxy : 192.168.10.10:3128 |
| APT (Debian)    | `/etc/apt/apt.conf.d/99proxy` : `Acquire::http::Proxy "http://192.168.10.10:3128";` |

---

## 🔥 Important : Redirection DNS via le firewall/routeur

Pour garantir que tout le trafic DNS du réseau soit filtré par AdGuard Home, il est fortement recommandé de configurer votre firewall/routeur pour :

- Rediriger toutes les requêtes DNS sortantes (port 53, TCP/UDP) vers l’IP du serveur où tourne la stack (variable SERVER_IP dans .env).
- Bloquer l’accès direct à d’autres serveurs DNS publics depuis le LAN (optionnel mais conseillé).

**Exemple de règle iptables (à adapter à votre IP) :**

```bash
# Redirige tout le trafic DNS sortant du LAN vers le serveur DNS local (ex : 192.168.10.10)
iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 192.168.10.10:53
iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 192.168.10.10:53
```

Cela force tous les clients à utiliser le filtrage DNS, même s’ils tentent de contourner la configuration DHCP ou manuelle.

---

## 📦 Dossiers de configuration AdGuard Home

Si vous choisissez AdGuard Home comme moteur DNS, les dossiers `config/adguardhome/work` et `config/adguardhome/conf` sont créés automatiquement lors de la génération du `.env`.

- **Pas de fichier de configuration par défaut** : AdGuard Home génère ses fichiers de config au premier lancement. Vous pouvez placer vos propres fichiers dans ces dossiers si besoin.
- Un fichier `README.txt` est placé pour vous guider.

---

## Support

Si vous avez besoin d'aide pour adapter ou déployer la stack dans votre environnement :

- ouvrez une issue sur le dépôt GitHub
- ou envoyez un message au mainteneur ; une réponse sera apportée dès que possible

---

## Références

- [AdGuard Home documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Squid configuration reference](https://www.squid-cache.org/Doc/config/)
- [Traefik v3 documentation](https://doc.traefik.io/traefik/)
- [mkcert](https://github.com/FiloSottile/mkcert)

## Projet adaptable à tout environnement LAN

Ce projet est conçu pour être utilisé dans n'importe quel lab ou réseau local.

Les noms d'hôtes, domaines et adresses IP sont entièrement personnalisables lors de l'installation grâce au script interactif `scripts/generate-env.sh`.

Toutes les références à des domaines internes ou à des IP par défaut sont des exemples :

- le domaine, les noms d'hôtes et les IP seront adaptés selon vos réponses lors de la génération du `.env` et du fichier `hosts`
- les fichiers de configuration, scripts et documentation utilisent les variables du `.env` pour garantir la cohérence avec votre environnement

Exemple :

- domaine choisi : `<votre-domaine>`
- serveur principal : `host1.<votre-domaine>` (`192.168.10.10`)
- passerelle : `gw.<votre-domaine>` (`192.168.10.1`)
- hub multimédia : `media.<votre-domaine>` (`192.168.10.20`)

Les instructions, configurations et accès s'adapteront automatiquement à ces choix.

Pour toute adaptation, lancez simplement l'installation et laissez-vous guider par les scripts interactifs.

Dans toute la documentation, remplacez les exemples de domaines et d'IP par vos propres valeurs renseignées dans le `.env`.

---

## Sources officielles des conteneurs

- **AdGuard Home**  
    Image : [`adguard/adguardhome`](https://hub.docker.com/r/adguard/adguardhome)  
    Documentation : [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki)

- **Squid**  
    Image : [`ubuntu/squid`](https://hub.docker.com/r/ubuntu/squid)  
    Documentation : [Squid Config Reference](https://www.squid-cache.org/Doc/config/)

- **Traefik**  
    Image : [`traefik`](https://hub.docker.com/_/traefik)  
    Documentation : [Traefik v3](https://doc.traefik.io/traefik/)
