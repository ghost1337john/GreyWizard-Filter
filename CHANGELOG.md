# Changelog – Stack DNS/Proxy/Reverse Proxy

## [1.0.1] – 2026-04-01
- Nettoyage des exemples et de la documentation pour supprimer les valeurs sensibles, hashes, emails et tokens réels.
- Clarification de la différence entre domaine interne et domaine public pour l'utilisation de Let's Encrypt.
- Ajout d'instructions explicites indiquant qu'un domaine public enregistré est requis pour DNS-01 avec Traefik.
- Harmonisation du README, de la FAQ et des guides de configuration autour des placeholders `${DOMAIN}` et des valeurs à renseigner.

## [Unreleased]
- Améliorations continues de la documentation et des scripts
- Harmonisation de la documentation avec la variable DOMAIN du .env (remplace TRAEFIK_DOMAIN)
- Ajout d’exemples de configuration pour AdGuard Home
- Ajout d’une FAQ et d’une section debug
- Désactivation temporaire de l'injection automatique des entrées DNS (rewrites) dans AdGuard Home lors de l'installation (ajout manuel requis)
- Mise à jour du README pour refléter ce changement et informer sur l'état de Traefik (toujours en test)

## [1.0.0] – 2026-03-30
- Stack générique AdGuard Home + Squid + Traefik
- Génération interactive du .env et des configs
- AdGuard Home comme moteur DNS unique
- Scripts d’installation, déploiement, update, test, SSH
- Documentation complète (README, exemples, schéma réseau)
- Gestion automatique des volumes et profils Docker Compose
- Prise en charge Ubuntu/Debian, Fedora/RHEL, Arch Linux
