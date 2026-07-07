# Homelab Services

All homelab services run on the `server` host (Raspberry Pi 4, aarch64-linux) using the `home-server` NixOS role, which composes: `common` + `server` + `media-server` + `smart-home` + `gaming-server` + `backup-server` + `backup`.

## Smart Home

### Home Assistant

Full home automation platform with the following sub-modules:

| Sub-module                 | Purpose                                                        |
| -------------------------- | -------------------------------------------------------------- |
| **climate**                | HVAC and climate control                                       |
| **heatpump**               | Heat pump integration and monitoring                           |
| **inverter**               | Deye solar inverter monitoring                                 |
| **night-schedule**         | Scheduled automations (time-based)                             |
| **plugs**                  | Smart plug control (TV, Fireplace, Hall Mirror, Kids Door, PC) |
| **telegram-notifications** | Telegram bot alerts and notifications                          |
| **weather**                | Weather data integration                                       |
| **zigbee2mqtt**            | Zigbee device bridge integration                               |

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

### Nginx

Reverse proxy for internal services. Routes traffic to appropriate backends.

Configuration: `modules/nixos/services/networking/nginx/`

## Gaming

### Minecraft Server

Dedicated Minecraft server with configured ops, difficulty (hard), and game rules (keep inventory, mob griefing).

Configuration: `modules/nixos/services/gaming/minecraft-server/`

## Backup

Restic-based backup system with client-server architecture:

- **Restic client** (`modules/nixos/services/backup/restic/`) - Scheduled backups with retention policies
- **Restic server** (`modules/nixos/services/backup/restic-server/`) - REST API server for receiving backups

## Available Modules (Not Currently Enabled)

These service modules exist in the repo but are **not** enabled by the `home-server` role, so they do not run on `server` in the current configuration. Enable them explicitly if needed.

| Module | Purpose | Configuration |
| ------ | ------- | ------------- |
| **Tailscale** | VPN mesh network for secure remote access | `modules/nixos/services/networking/tailscale/` |
| **Podman** | Rootless, Docker-compatible container runtime | `modules/nixos/services/virtualisation/podman/` |
| **k3s** | Lightweight Kubernetes (server/agent, token auth) | `modules/nixos/services/k3s/` |
| **CUPS** | Print server with network sharing | `modules/nixos/services/printing/` |

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

| Device       | IP           | Purpose                    |
| ------------ | ------------ | -------------------------- |
| server       | 10.0.0.40    | Main server (all services) |
| router       | 10.0.0.1     | MikroTik gateway           |
| cap1/cap2    | 10.0.0.11-12 | WiFi access points         |
| monitor      | 10.0.0.30    | Security camera            |
| ajax         | 10.0.0.31    | Security hub               |
| tv / tv-wifi | 10.0.0.50-51 | Smart TVs                  |
| inverter     | 10.0.0.52    | Solar inverter             |
| heatpump     | 10.0.0.53    | Heat pump                  |
