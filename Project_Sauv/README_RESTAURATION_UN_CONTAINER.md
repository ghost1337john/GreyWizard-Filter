# Restauration d un seul container Docker

Ce guide explique comment restaurer uniquement un container (ex: sonarr) a partir d une archive `hub_backup_*.tar.gz`.

## Quand utiliser ce guide

- Un seul service est casse (config supprimee, corruption locale, mauvaise modif)
- Tu veux eviter une restauration globale
- Tu as une archive creee par `save_hub.sh`

## Prerequis

- Une archive valide dans `/sauvegarde`
- Acces sudo
- Nom du container a restaurer (ex: `sonarr`)
- Dossier applicatif existe dans l archive sous `/app/<container>`
- `rsync` recommande (optionnel: le script bascule automatiquement sur `cp -a`)

## Procedure recommandee (script)

Le script `restore_one_container.sh` automatise la restauration d un seul container.

```bash
# 1) Rendre le script executable
sudo chmod +x /home/plex/hub_multimedia/restore_one_container.sh

# 2) Restaurer un container depuis la derniere archive
sudo /home/plex/hub_multimedia/restore_one_container.sh sonarr

# 3) Ou restaurer depuis une archive precise
sudo /home/plex/hub_multimedia/restore_one_container.sh sonarr /sauvegarde/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

Le script fait automatiquement:

- verification des prerequis (root, docker, archive)
- extraction du seul dossier `app/<container>` depuis l archive
- arret du container cible si necessaire
- restauration vers `/app/<container>` (`rsync --delete` si disponible, sinon `cp -a`)
- redemarrage du container et verification
- gestion du cas `gluetun` pour `flaresolverr`, `qbittorrent`, `prowlarr`

## Test automatique (simulation de panne)

Le script `test_restore_one_container.sh` simule une panne controlee, lance une sauvegarde, restaure le container et affiche `PASS` ou `FAIL`.

```bash
# 1) Rendre le script executable
sudo chmod +x /home/plex/hub_multimedia/test_restore_one_container.sh

# 2) Test par defaut sur tautulli (backup fraiche + panne + restore + verification)
sudo /home/plex/hub_multimedia/test_restore_one_container.sh

# 3) Test sur un autre container
sudo /home/plex/hub_multimedia/test_restore_one_container.sh sonarr

# 4) Test avec une archive precise
sudo /home/plex/hub_multimedia/test_restore_one_container.sh sonarr /sauvegarde/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz
```

Important:

- Le script ecrit et remplace `/app/<container>/restore_test.txt` pendant le test.
- Evite de lancer ce test en pleine heure de pointe, car il cree une sauvegarde et redemarre le container teste.

## Procedure manuelle (fallback)

Utilise cette methode seulement si tu ne peux pas utiliser le script.

```bash
set -euo pipefail

CONTAINER_NAME="sonarr"
BACKUP_FILE="$(ls -t /sauvegarde/hub_backup_*.tar.gz | head -n 1)"
TMP_DIR="/tmp/restore_one_${CONTAINER_NAME}_$(date +%s)"

sudo mkdir -p "$TMP_DIR"
sudo tar -xzf "$BACKUP_FILE" -C "$TMP_DIR" "app/$CONTAINER_NAME"
sudo docker stop "$CONTAINER_NAME" || true
sudo mkdir -p "/app/$CONTAINER_NAME"
if command -v rsync >/dev/null 2>&1; then
	sudo rsync -a --delete "$TMP_DIR/app/$CONTAINER_NAME/" "/app/$CONTAINER_NAME/"
else
	sudo find "/app/$CONTAINER_NAME" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
	sudo cp -a "$TMP_DIR/app/$CONTAINER_NAME/." "/app/$CONTAINER_NAME/"
fi
sudo docker start "$CONTAINER_NAME"
sudo docker ps --filter "name=^/${CONTAINER_NAME}$"
```

## Cas special: containers relies a gluetun

Si tu restaures `flaresolverr`, `qbittorrent` ou `prowlarr`, ils dependent de `gluetun`.

Si le demarrage echoue, lance:

```bash
sudo docker start gluetun
sleep 10
sudo docker start flaresolverr qbittorrent prowlarr
```

## Option Portainer (si besoin)

Si tu veux aussi revoir le YAML de la stack d un seul service, il est exporte dans l archive sous:

- `tmp/save_hub_portainer_export/portainer_stacks/stack_<id>/docker-compose.yml`

Commande utile:

```bash
sudo tar -tzf "$BACKUP_FILE" | grep portainer_stacks
```

## Nettoyage

Apres verification, supprime le dossier temporaire:

```bash
sudo rm -rf "$TMP_DIR"
```
