# Checklist migration complete Palantir vers nouveau serveur

Objectif: migrer Docker + Portainer + stacks sans perte de configuration.

## Phase 0 - Pre-checks (serveur source Palantir)

1. Verifier l'etat global:

```bash
hostname
date
docker ps
docker volume ls
docker network ls
```

2. Verifier le script de sauvegarde:

```bash
sudo bash -n /home/plex/hub_multimedia/save_hub.sh
```

3. Lancer une sauvegarde fraiche:

```bash
sudo /home/plex/hub_multimedia/save_hub.sh
```

4. Identifier la derniere archive:

```bash
LATEST_BACKUP=$(ls -t /sauvegarde/hub_backup_*.tar.gz | head -n 1)
echo "$LATEST_BACKUP"
```

5. Controle du contenu archive (doit inclure Portainer):

```bash
sudo tar -tzf "$LATEST_BACKUP" | grep -E 'portainer_data|/app/' | head -n 50
```

## Phase 1 - Export des informations critiques (source)

1. Sauver l'inventaire Docker:

```bash
mkdir -p /sauvegarde/inventaire
sudo docker ps -a > /sauvegarde/inventaire/docker-ps-a.txt
sudo docker volume ls > /sauvegarde/inventaire/docker-volume-ls.txt
sudo docker network ls > /sauvegarde/inventaire/docker-network-ls.txt
```

2. Sauver les compose utilises (si plusieurs):

```bash
sudo find /opt -maxdepth 4 -name 'docker-compose*.yml' -o -name 'compose*.yml'
```

3. Sauver les variables d'environnement associees:

```bash
sudo find /opt -maxdepth 4 -name '.env'
```

## Phase 2 - Transfert vers nouveau serveur

1. Copier la derniere archive:

```bash
scp "$LATEST_BACKUP" user@nouveau-serveur:/tmp/
```

2. Copier aussi les fichiers de deploiement:

```bash
scp /home/plex/hub_multimedia/docker-compose.yml user@nouveau-serveur:/tmp/
scp /home/plex/hub_multimedia/.env user@nouveau-serveur:/tmp/
```

## Phase 3 - Preparation du nouveau serveur

1. Installer Docker + plugin compose.
2. Verifier:

```bash
docker --version
docker compose version
```

3. Preparer dossiers:

```bash
sudo mkdir -p /home/plex/hub_multimedia
sudo mkdir -p /app
sudo mkdir -p /sauvegarde
```

## Phase 4 - Restauration des donnees

1. Extraire l'archive:

```bash
sudo mkdir -p /tmp/restore_hub
sudo tar -xzf /tmp/hub_backup_YYYY-MM-DD_HH-MM-SS.tar.gz -C /tmp/restore_hub
```

2. Restaurer les dossiers applicatifs:

```bash
sudo rsync -a /tmp/restore_hub/app/ /app/
```

3. Restaurer les fichiers de deploiement:

```bash
sudo cp /tmp/restore_hub/home/plex/hub_multimedia/docker-compose.yml /home/plex/hub_multimedia/
sudo cp /tmp/restore_hub/home/plex/hub_multimedia/.env /home/plex/hub_multimedia/
```

4. Restaurer le volume Portainer:

```bash
docker volume create portainer_data
docker run --rm \
  -v portainer_data:/to \
  -v /tmp/restore_hub:/from:ro \
  busybox sh -c "cd /from && tar -cf - tmp/save_hub_portainer_export/portainer_data | tar -xf - -C /to --strip-components=2"
```

## Phase 5 - Redemarrage des services

1. Relancer la stack principale:

```bash
cd /home/plex/hub_multimedia
docker compose up -d
```

2. Si Portainer est externe a cette stack, le relancer:

```bash
docker run -d \
  --name portainer \
  --restart=always \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:lts
```

## Phase 6 - Validation post-migration

1. Verification conteneurs:

```bash
docker ps
```

2. Verification Portainer:
- Connexion HTTPS sur port 9443
- Presence des endpoints
- Presence des stacks

3. Verification applicative:
- Ouvrir Sonarr, Radarr, Prowlarr, Plex, etc.
- Verifier chemins et permissions
- Verifier que les medias sont visibles

4. Verification reseau:
- Reverse proxy / Traefik
- Certificats TLS
- DNS pointant vers nouveau serveur

## Phase 7 - Bascule DNS et surveillance

1. Bascule DNS vers le nouveau serveur.
2. Surveiller pendant 24-48h:
- Logs Docker
- Erreurs applicatives
- Jobs planifies (cron)

## Rollback (si souci)

1. Rebasculer DNS vers Palantir.
2. Redemarrer les services sur Palantir:

```bash
cd /home/plex/hub_multimedia
docker compose up -d
```

3. Analyser les ecarts de configuration avant nouvelle tentative.

## Points critiques anti-perte

- Toujours faire une sauvegarde fraiche juste avant migration.
- Restaurer Portainer uniquement a partir du volume portainer_data sauvegarde.
- Restaurer egalement /app et les fichiers compose/.env.
- Eviter un saut de version majeur Portainer lors de la restauration.
- Ne couper Palantir qu'apres validation complete sur le nouveau serveur.
