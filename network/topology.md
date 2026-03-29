# Exemple lab – Topologie réseau

## Vue d'ensemble

```
Internet
    │
    │  (WAN)
    ▼
┌─────────────────────────────────┐
│  gw.lab.local                   │
│  192.168.10.1                   │
│  Passerelle / Routeur           │
│  Portail d'entrée du LAN        │
└────────────────┬────────────────┘
                 │
                 │  LAN 192.168.1.0/24
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌───────────────────┐   ┌───────────────────────────────────┐
│  media            │   │  host1                            │
│  192.168.10.20    │   │  192.168.10.10                    │
│  Hub multimédia   │   │  Filtering Stack (Docker)         │
│  (Jellyfin...)    │   │                                   │
│                   │   │  ┌─────────┐ ┌───────┐ ┌───────┐ │
│                   │   │  │Traefik  │ │Pihole │ │Squid  │ │
│                   │   │  │:80/:443 │ │:53    │ │:3128  │ │
└───────────────────┘   │  └─────────┘ └───────┘ └───────┘ │
                        └───────────────────────────────────┘
```

## Machines

| Hostname           | IP            | Rôle                     | Note                         |
|--------------------|---------------|--------------------------|------------------------------|
| `gw.lab.local`     | 192.168.10.1  | Passerelle / Routeur     | Gateway LAN, garde l'entrée  |
| `media.lab.local`  | 192.168.10.20 | Hub multimédia           | Serveur multimédia du lab    |
| `host1.lab.local`  | 192.168.10.10 | Filtrage & Reverse Proxy | Hôte Docker principal        |

## Services déployés sur carcharoth

| Service  | URL interne                    | Port local | Rôle                           |
|----------|--------------------------------|------------|--------------------------------|
| Traefik  | https://traefik.lab.local      | 80 / 443   | Reverse proxy, dashboard       |
| Pi-hole  | https://pihole.lab.local/admin | —          | DNS, bloqueur pub              |
| Squid    | —                              | 3128       | Proxy HTTP/HTTPS, cache        |

## Réseaux

| Réseau          | CIDR              | Utilisation                                |
|-----------------|-------------------|--------------------------------------------|
| LAN lab.local   | 192.168.10.0/24   | Réseau physique du lab                     |
| Docker `proxy`  | bridge auto       | Communication inter-conteneurs             |
| `pihole_net`    | 172.30.0.0/24     | Réseau isolé Pi-hole (IP fixe 172.30.0.2)  |

## Flux de trafic

```
Client LAN
  │
      ├── Requête DNS ──► host1:53 (Pi-hole) ──► upstream DNS (9.9.9.9)
      │                        │
      │                   Filtre pub + résolution locale lab.local
      │
      ├── Requête HTTP/HTTPS ──► host1:3128 (Squid)
      │                              │
      │                         Cache + filtrage DNS Pi-hole
      │                              │
      │                         Serveur distant
      │
      └── Services web ──► host1:443 (Traefik)
             │
            ┌──────┴──────┐
            │             │
          pihole.lab.local  traefik.lab.local
             (Pi-hole UI)     (Dashboard)
```

## Configuration DNS requise

Pointez le DNS primaire de chaque machine du lab vers Pi-hole :

```
DNS primaire  : 192.168.1.42  (carcharoth – Pi-hole)
DNS secondaire: 192.168.1.254  (gandalf – relais, optionnel)
```

Ou configurez le DHCP de gandalf pour distribuer `192.168.1.42` comme serveur DNS.
