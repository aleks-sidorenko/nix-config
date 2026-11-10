# services/

Daemons and servers.

| Sub-directory | Features (from `master`) |
|---|---|
| `networking/` | `tailscale`, `openvpn`, `nginx`, `socket-vmnet` |
| `media/` | `jellyfin`, `sonarr`, `radarr`, `prowlarr`, `recyclarr`, `qbittorrent`, `calibre`, `minidlna` |
| `backup/` | `restic`, `restic-server` |
| `gaming/` | `minecraft-server` |
| `smart-home/` | `mosquitto`, `zigbee2mqtt`, `home-assistant` (its integrations nested inside it as `home-assistant-<x>`) |
| `virtualisation/` | `podman`, `kvm`, `docker`, `colima`, `lima`, `qemu`, `rancher`, `k8s` |
| `<feature>/` | `k3s`, `printing`, `syncthing`, `kdeconnect`, `teamviewer` |

**Registries are data.** Today's `services/smart-home/{devices,zones}` are typed registries, not services. They move to `../constants/` (`constants.smart-home.{devices,zones}`), and the smart-home features read them from there.

**Group aggregators.** Today's `services/{media,backup,gaming,smart-home}/default.nix` bundle their members. They merge into the role of the same purpose (`media-server`, `backup`, `gaming-server`, `smart-home`) in `../roles/`, and options the group shares move with them.

Examples:
- `nixos/services/smart-home/zigbee2mqtt` → `services/smart-home/zigbee2mqtt/`, aspect `zigbee2mqtt`.
- `nixos/services/smart-home/home-assistant/climate` → `services/smart-home/home-assistant/climate/`, aspect `home-assistant-climate`.
- `nixos/services/virtualisation/podman` + `darwin/services/virtualisation/podman` + `home/virtualization/podman` → `services/virtualisation/podman/`, aspect `podman`.
- `nixos/services/media/qbittorrent` → `services/media/qbittorrent/`, aspect `qbittorrent`.
- `nixos/services/networking/tailscale` + `darwin/services/networking/tailscale` → `services/networking/tailscale/`, aspect `tailscale`.

Rules: [../README.md](../README.md).
