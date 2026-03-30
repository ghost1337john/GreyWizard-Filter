#!/bin/bash
# Script de suppression du dossier dnsmasq (obsolète)

if [ -d "config/dnsmasq" ]; then
  echo "Suppression du dossier config/dnsmasq..."
  rm -rf config/dnsmasq
  echo "Dossier supprimé."
else
  echo "Le dossier config/dnsmasq n'existe pas ou a déjà été supprimé."
fi
