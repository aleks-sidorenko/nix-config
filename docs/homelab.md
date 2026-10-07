# Homelab Services

Homelab services run on `server-vm`, a headless aarch64 QEMU guest standing in for `server`, whose hardware is being replaced (#235), using the `home-server` NixOS role, which composes: `common` + `server` + `media-server` + `smart-home` + `gaming-server` + `backup`. `server-vm` switches `smart-home` back off, since the plugs, heatpump and climate sensors its automations name stayed with the old house. Once `server` exists again, `home-server` moves there and off `server-vm`.

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

Each `home-server` host backs its state up daily (03:00, `Persistent = false`
— a run missed while the host is off is skipped) with restic to its own
repository in the Cloudflare R2 bucket `backups`, at `backups/<hostname>`.

- **What**: `/home`, `/root`, the whole persist root, plus `extraPaths` modules
  contribute (Calibre's library). Media on `/data` is not backed up — it can be
  re-fetched. Modules exclude what they can regenerate via `extraExclude`
  (Jellyfin's cache). The host's SSH key is included, so a restore brings its
  SOPS identity back.
- **Where it's declared**: the bucket in `infra/backup`; bucket name and
  account ID in `lib/defaults.backup`; the client in
  `modules/nixos/services/backup/restic/`.
- **Other roles**: the `graphical` role also enables `backup`, so a future
  desktop host would back up its `/home` to the same bucket unless it turns
  `backup` off.
- **Failures are silent**: check `systemctl status restic-backups-default`.

### Bootstrap (once)

1. Cloudflare dashboard → API token with **Workers R2 Storage: Edit** (account permission) → `just backup-secrets-edit`
   (`cloudflare-api-token`, plus a new random `state-passphrase`).
2. `just backup-apply` — creates the bucket.
3. Dashboard → R2 → API token, **Object Read & Write**, bucket `backups` only →
   `just secrets-edit nixos`: `service-restic-r2-access-key-id` (Access Key ID)
   and `service-restic-r2-secret-access-key` (Secret Access Key). The host
   won't build (sops-nix's manifest check fails on a missing key) until both
   are in `modules/nixos/secrets.yaml`, so add them before building or deploying.
4. Deploy the host, then `sudo systemctl start restic-backups-default` and
   `journalctl -u restic-backups-default` for the first snapshot.

### Restore

On the host (or a fresh one with the same identity):

```bash
sudo -u restic restic-default snapshots
sudo restic-default restore --no-cache <snapshot-id> --target /tmp/restore --include /persist/var/lib/<service>
```

`restic-default` is the NixOS wrapper that carries the repository, password
and R2 environment. Read-only commands run as the `restic` user, which owns
the shared cache directory; `restore` runs as root, so it skips the cache to
avoid leaving root-owned files there.

**If every device is lost**, a restore needs only this repo and the PGP private
key: the key decrypts the restic password and the R2 credential from SOPS. The
PGP key's own backup is the root of disaster recovery.

### Rotating the R2 credential

Create a new bucket-scoped token, `just secrets-edit nixos`, deploy, then revoke
the old token in the dashboard.

## Available Modules (Not Currently Enabled)

These service modules exist in the repo but no host enables them. Enable them explicitly if needed.

| Module | Purpose | Configuration |
| ------ | ------- | ------------- |
| **k3s** | Lightweight Kubernetes (server/agent, token auth) | `modules/nixos/services/k3s/` |
| **CUPS** | Print server with network sharing | `modules/nixos/services/printing/` |
| **restic-server** | Self-hosted restic REST target (`roles.backup-server`) | `modules/nixos/services/backup/restic-server/` |

Two service modules run outside the `home-server` role: **Tailscale** (`modules/nixos/services/networking/tailscale/`), which `common` enables on every host, and **Podman** (`modules/nixos/services/virtualisation/podman/`), enabled by the `desktop` role.

## Enabling Services

Services are typically enabled through the role system:

```nix
# In systems/aarch64-linux/server-vm/default.nix
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
