# GreyHaven – Topologie réseau

## Vue d'ensemble

```
Internet
    │
    │  (WAN)
    ▼
┌─────────────────────────────────┐
│  gandalf.greyhaven              │
│  192.168.1.254                  │
│  Passerelle / Routeur           │
│  Portail d'entrée du LAN        │
└────────────────┬────────────────┘
                 │
                 │  LAN 192.168.1.0/24
    ┌────────────┴────────────┐
    │                         │
    ▼                         ▼
┌───────────────────┐   ┌───────────────────────────────────┐
│  palantir         │   │  carcharoth                       │
│  192.168.1.2      │   │  192.168.1.42                     │
│  Hub multimédia   │   │  Filtering Stack (Docker)         │
│  (Jellyfin...)    │   │                                   │
│  (pierre de       │   │  ┌─────────┐ ┌───────┐ ┌───────┐ │
│   vision)         │   │  │Traefik  │ │Pihole │ │Squid  │ │
│                   │   │  │:80/:443 │ │:53    │ │:3128  │ │
└───────────────────┘   │  └─────────┘ └───────┘ └───────┘ │
                        └───────────────────────────────────┘
```

## Machines

| Hostname               | IP            | Rôle                         | Note                         |
|------------------------|---------------|------------------------------|------------------------------|
| `gandalf.greyhaven`    | 192.168.1.254 | Passerelle / Routeur         | Gateway LAN, garde l'entrée  |
| `palantir.greyhaven`   | 192.168.1.2   | Hub multimédia               | Pierre de vision du lab      |
| `carcharoth.greyhaven` | 192.168.1.42  | Filtrage & Reverse Proxy     | Loup gardien, hôte Docker    |

## Services déployés sur carcharoth

| Service  | URL interne                    | Port local | Rôle                           |
|----------|--------------------------------|------------|--------------------------------|
| Traefik  | https://traefik.greyhaven      | 80 / 443   | Reverse proxy, dashboard       |
| Pi-hole  | https://pihole.greyhaven/admin | —          | DNS, bloqueur pub              |
| Squid    | —                              | 3128       | Proxy HTTP/HTTPS, cache        |

## Réseaux

| Réseau          | CIDR              | Utilisation                                |
|-----------------|-------------------|--------------------------------------------|
| LAN GreyHaven   | 192.168.1.0/24    | Réseau physique du lab                     |
| Docker `proxy`  | bridge auto       | Communication inter-conteneurs             |
| `pihole_net`    | 172.30.0.0/24     | Réseau isolé Pi-hole (IP fixe 172.30.0.2)  |

## Flux de trafic

```
Client LAN
  │
    ├── Requête DNS ──► carcharoth:53 (Pi-hole) ──► upstream DNS (9.9.9.9)
  │                        │
  │                   Filtre pub + résolution locale greyhaven
  │
  ├── Requête HTTP/HTTPS ──► carcharoth:3128 (Squid)
  │                              │
  │                         Cache + filtrage DNS Pi-hole
  │                              │
  │                         Serveur distant
  │
  └── Services web ──► carcharoth:443 (Traefik)
                           │
                    ┌──────┴──────┐
                    │             │
            pihole.greyhaven  traefik.greyhaven
             (Pi-hole UI)     (Dashboard)
```

## Configuration DNS requise

Pointez le DNS primaire de chaque machine du lab vers Pi-hole :

```
DNS primaire  : 192.168.1.42  (carcharoth – Pi-hole)
DNS secondaire: 192.168.1.254  (gandalf – relais, optionnel)
```

Ou configurez le DHCP de gandalf pour distribuer `192.168.1.42` comme serveur DNS.
