# Homelab Services

All homelab services run on the `server` host (Raspberry Pi 4, aarch64-linux) using the `home-server` NixOS role, which composes: `common` + `server` + `media-server` + `smart-home` + `gaming-server` + `backup-server` + `backup`.

## Smart Home

### Home Assistant

Full home automation platform with the following sub-modules:

| Sub-module | Purpose |
|-----------|---------|
| **climate** | HVAC and climate control |
| **heatpump** | Heat pump integration and monitoring |
| **inverter** | Deye solar inverter monitoring |
| **night-schedule** | Scheduled automations (time-based) |
| **plugs** | Smart plug control (TV, Fireplace, Hall Mirror, Kids Door, PC) |
| **telegram-notifications** | Telegram bot alerts and notifications |
| **weather** | Weather data integration |
| **zigbee2mqtt** | Zigbee device bridge integration |

Configuration: `modules/nixos/services/smart-home/home-assistant/`

### Mosquitto MQTT

MQTT message broker for IoT device communication. Used by Home Assistant and Zigbee2MQTT.

Configuration: `modules/nixos/services/smart-home/mosquitto/`

### Zigbee2MQTT

Bridges Zigbee devices to MQTT using a SONOFF Zigbee adapter (Ember). Manages smart plugs, sensors, and other Zigbee devices.

Configuration: `modules/nixos/services/smart-home/zigbee2mqtt/`

### Zones & Devices

Zone-based automation (room/area definitions) and device management.

Configuration: `modules/nixos/services/smart-home/zones/`, `modules/nixos/services/smart-home/devices/`

## Media Stack

### Jellyfin

Media server for movies, TV shows, and music. Accessible via web interface.

### Sonarr & Radarr

Automated TV show (Sonarr) and movie (Radarr) management. Monitors for new episodes/releases and triggers downloads.

### Prowlarr

Torrent and Usenet indexer manager. Provides unified search across indexers for Sonarr and Radarr.

### qBittorrent

Torrent client. Downloads are organized into:
- `/data/torrents/Movies/`
- `/data/torrents/Series/`

Media files are served from:
- `/data/media/Movies/`
- `/data/media/Series/`

### MiniDLNA

UPnP/DLNA media server for streaming to TVs and other DLNA-compatible devices on the local network.

Configuration for all media services: `modules/nixos/services/media/`

## Networking

### Tailscale

VPN mesh network connecting all hosts. Provides secure access to homelab services from anywhere.

Configuration: `modules/nixos/services/networking/tailscale/`

### Nginx

Reverse proxy for internal services. Routes traffic to appropriate backends.

Configuration: `modules/nixos/services/networking/nginx/`

## Containers & Orchestration

### Podman

Container runtime (Docker-compatible, rootless). Used for running containerized services.

Configuration: `modules/nixos/services/virtualisation/podman/`

### k3s

Lightweight Kubernetes distribution. Supports both server and agent modes with token-based authentication.

Configuration: `modules/nixos/services/k3s/`

## Gaming

### Minecraft Server

Dedicated Minecraft server with configured ops, difficulty (hard), and game rules (keep inventory, mob griefing).

Configuration: `modules/nixos/services/gaming/minecraft-server/`

## Printing

### CUPS

Print server with network sharing support.

Configuration: `modules/nixos/services/printing/`

## Backup

Restic-based backup system with client-server architecture:

- **Restic client** (`modules/nixos/services/backup/restic/`) - Scheduled backups with retention policies
- **Restic server** (`modules/nixos/services/backup/restic-server/`) - REST API server for receiving backups

For detailed backup configuration, see [`modules/nixos/services/backup/README.md`](../modules/nixos/services/backup/README.md).

## Enabling Services

Services are typically enabled through the role system:

```nix
# In systems/aarch64-linux/server/default.nix
nix-config.roles.home-server.enable = true;  # Enables ALL server services
```

Individual services can also be toggled:

```nix
# Enable specific services
nix-config.services.media.jellyfin.enable = true;
nix-config.services.smart-home.home-assistant.enable = true;
nix-config.services.backup.restic.enable = true;
```

## Network Layout

All homelab devices have static IPs managed by the router (see [docs/router.md](router.md)):

| Device | IP | Purpose |
|--------|-----|---------|
| server | 10.0.0.40 | Main server (all services) |
| router | 10.0.0.1 | MikroTik gateway |
| cap1/cap2 | 10.0.0.11-12 | WiFi access points |
| monitor | 10.0.0.30 | Security camera |
| ajax | 10.0.0.31 | Security hub |
| tv / tv-wifi | 10.0.0.50-51 | Smart TVs |
| inverter | 10.0.0.52 | Solar inverter |
| heatpump | 10.0.0.53 | Heat pump |
