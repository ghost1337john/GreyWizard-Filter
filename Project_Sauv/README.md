# Sauvegarde automatique Docker (Debian)

Ce document explique comment mettre en place la sauvegarde automatique de ta stack containers media avec le script `save_hub.sh`.

Checklist migration complete disponible ici: `MIGRATION_PALANTIR_CHECKLIST.md`

Script de restauration globale disponible ici: `restore_hub.sh`

Guide de restauration d un seul container disponible ici: `README_RESTAURATION_UN_CONTAINER.md`

Script de restauration d un seul container disponible ici: `restore_one_container.sh`

Script de test (simulation panne + restauration unitaire) disponible ici: `test_restore_one_container.sh`

## Prerequis

- Script present sur le serveur: `/home/plex/hub_multimedia/save_hub.sh`
- Dossiers applicatifs presents sous `/app`
- Docker et `docker compose` (ou `docker-compose`) installes
- Acces sudo
- `rsync` recommande pour les restaurations (optionnel: les scripts basculent sur `cp -a` si absent)
- Si Portainer est utilise: donnees Portainer disponibles soit via bind mount (`./portainer_data`), soit via volume Docker `portainer_data` (pas besoin de dossier `/app/portainer`)

## Procedure pas a pas

1. Connexion au serveur

```bash
ssh plex@palantir
```

2. Creer le dossier de sauvegarde

```bash
sudo mkdir -p /sauvegarde
sudo chmod 750 /sauvegarde
```

3. Rendre le script executable

```bash
sudo chmod +x /home/plex/hub_multimedia/save_hub.sh
```

4. Verifier la syntaxe

```bash
sudo bash -n /home/plex/hub_multimedia/save_hub.sh
```

5. Lancer un test manuel

```bash
sudo /home/plex/hub_multimedia/save_hub.sh
```

6. Verifier la creation de l'archive

```bash
ls -lh /sauvegarde
sudo tar -tzf $(ls -t /sauvegarde/hub_backup_*.tar.gz | head -n 1) | head -n 40
```

7. Activer la tache automatique (cron a 03:00)

```bash
( sudo crontab -l 2>/dev/null | grep -v 'save_hub.sh' ; echo '0 3 * * * /home/plex/hub_multimedia/save_hub.sh >> /sauvegarde/backup.log 2>&1' ) | sudo crontab -
```

Cette commande ajoute ou remplace l entree de sauvegarde sans doublon.

Entree cron installee:

```cron
0 3 * * * /home/plex/hub_multimedia/save_hub.sh >> /sauvegarde/backup.log 2>&1
```

8. Verifier la tache cron

```bash
sudo crontab -l
```

9. Suivre les logs

```bash
tail -f /sauvegarde/backup.log
```

10. Tester manuellement l ecriture dans le log (simulation du cron)

```bash
sudo bash -c '/home/plex/hub_multimedia/save_hub.sh >> /sauvegarde/backup.log 2>&1'
tail -n 50 /sauvegarde/backup.log
```

Note: il faut passer par `sudo bash -c`, sinon la redirection `>> /sauvegarde/backup.log`
est executee par ton shell courant avant `sudo`, ce qui provoque `Permission non accordee`.

11. Tester les scripts de restauration (recommande)

```bash
sudo chmod +x /home/plex/hub_multimedia/restore_one_container.sh
sudo chmod +x /home/plex/hub_multimedia/test_restore_one_container.sh
sudo /home/plex/hub_multimedia/test_restore_one_container.sh tautulli
```

## Version copier-coller (bloc unique)

Important:
- Ce bloc suppose que le script est deja a cet emplacement: `/home/plex/hub_multimedia/save_hub.sh`

```bash
ssh plex@palantir << 'EOF'
set -e

# 1) Dossier de sauvegarde
sudo mkdir -p /sauvegarde
sudo chmod 750 /sauvegarde

# 2) Permissions script
sudo chmod +x /home/plex/hub_multimedia/save_hub.sh

# 3) Verification syntaxe
sudo bash -n /home/plex/hub_multimedia/save_hub.sh

# 4) Test manuel
sudo /home/plex/hub_multimedia/save_hub.sh

# 5) Verification archive
ls -lh /sauvegarde
LATEST_BACKUP=$(ls -t /sauvegarde/hub_backup_*.tar.gz | head -n 1)
echo "Derniere archive: $LATEST_BACKUP"
sudo tar -tzf "$LATEST_BACKUP" | head -n 40

# 6) Installation cron quotidienne a 03:00 (sans doublon)
( sudo crontab -l 2>/dev/null | grep -v 'save_hub.sh' ; echo '0 3 * * * /home/plex/hub_multimedia/save_hub.sh >> /sauvegarde/backup.log 2>&1' ) | sudo crontab -

# 7) Verification cron
sudo crontab -l

# 8) Test manuel de l ecriture dans le log
sudo bash -c '/home/plex/hub_multimedia/save_hub.sh >> /sauvegarde/backup.log 2>&1'
tail -n 50 /sauvegarde/backup.log

# 9) Test de restauration unitaire (recommande)
sudo chmod +x /home/plex/hub_multimedia/restore_one_container.sh
sudo chmod +x /home/plex/hub_multimedia/test_restore_one_container.sh
sudo /home/plex/hub_multimedia/test_restore_one_container.sh tautulli

echo "Mise en place terminee."
EOF
```

## Verification finale

- Une archive `hub_backup_*.tar.gz` est creee dans `/sauvegarde`
- Les conteneurs redemarrent apres sauvegarde
- Le fichier `/sauvegarde/backup.log` contient l'execution cron
- Le test `test_restore_one_container.sh` retourne `PASS`

## Portainer: sauvegarde et migration

Le script sauvegarde aussi automatiquement les donnees Portainer, avec detection auto:
- cas 1: bind mount vers `/data` (exemple du tuto IT-Connect: `./portainer_data:/data`)
- cas 2: volume Docker sur `/data` (ex: `portainer_data:/data`)

Note: dans les 2 cas, il n'y a pas de dossier `/app/portainer` a sauvegarder.

Ce volume contient notamment:
- la base Portainer
- les endpoints
- les stacks creees dans Portainer

### Reinstallation de Portainer sur un autre serveur

Oui, c'est possible de reinstaller Portainer ailleurs et de recuperer les stacks, a condition de restaurer les donnees `/data` de Portainer (bind mount ou volume selon ton installation).

1. Copier une archive de sauvegarde sur le nouveau serveur.
2. Extraire l'archive dans un dossier temporaire.
3. Restaurer les donnees Portainer dans le bon backend:
	- bind mount: restaurer le dossier `portainer_data` a l'emplacement attendu
	- volume: recreer `portainer_data` et restaurer son contenu
4. Relancer Portainer avec le meme mode de stockage.

Exemple de commandes:

```bash
# 1) Extraire l'archive
mkdir -p /tmp/restore_hub
tar -xzf /chemin/vers/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz -C /tmp/restore_hub

# 2) Cas VOLUME: recreer le volume Portainer
docker volume create portainer_data

# 3) Cas VOLUME: restaurer les donnees Portainer dans le volume
docker run --rm \
	-v portainer_data:/to \
	-v /tmp/restore_hub:/from:ro \
	busybox sh -c "cd /from && tar -cf - tmp/save_hub_portainer_export/portainer_data | tar -xf - -C /to --strip-components=2"

# 4) Cas BIND (tuto IT-Connect): restaurer le dossier bind mount
sudo mkdir -p /opt/docker-compose/portainer
sudo rsync -a /tmp/restore_hub/opt/docker-compose/portainer/portainer_data/ /opt/docker-compose/portainer/portainer_data/

# 5) Reinstaller/relancer Portainer avec le backend adapte
docker run -d \
	--name portainer \
	--restart=always \
	-p 9443:9443 \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v portainer_data:/data \
	portainer/portainer-ce:lts
```

### Important pour ne rien perdre

- Les stacks Portainer sont restaurees avec les donnees `/data` de Portainer (bind mount ou volume).
- Les donnees applicatives reelles (ex: configs dans `/app`, volumes d'applications) doivent aussi etre restaurees sur le nouveau serveur.
- Garder une version Portainer proche de l'ancienne limite les risques d'incompatibilite.

## Restauration globale (Portainer + autres conteneurs)

Le script `restore_hub.sh` restaure automatiquement:
- les dossiers applicatifs `/app`
- les fichiers de deploiement `/home/plex/hub_multimedia/docker-compose.yml` et `.env`
- les donnees Portainer (volume exporte ou bind mount detecte)
- puis redemarre la stack principale

### Procedure rapide

1. Copier l'archive de sauvegarde sur le serveur cible (ou source)
2. Copier `restore_hub.sh` dans `/home/plex/hub_multimedia/`
3. Lancer:

```bash
sudo chmod +x /home/plex/hub_multimedia/restore_hub.sh
sudo /home/plex/hub_multimedia/restore_hub.sh /chemin/vers/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

### Version copier-coller (bloc unique)

```bash
set -e

sudo mkdir -p /home/plex/hub_multimedia
sudo chmod +x /home/plex/hub_multimedia/restore_hub.sh

# Exemple: derniere archive locale
LATEST_BACKUP=$(ls -t /sauvegarde/hub_backup_*.tar.gz | head -n 1)
echo "Archive restauree: $LATEST_BACKUP"

sudo /home/plex/hub_multimedia/restore_hub.sh "$LATEST_BACKUP"

# Verification
sudo docker ps
```
