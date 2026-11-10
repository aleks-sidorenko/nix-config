# services/

Daemons and servers.

| Sub-directory | Features (from `master`) |
|---|---|
| `networking/` | `tailscale`, `openvpn`, `nginx`, `socket-vmnet` |
| `media/` | `jellyfin`, `sonarr`, `radarr`, `prowlarr`, `recyclarr`, `qbittorrent`, `calibre`, `minidlna` |
| `backup/` | `restic`, `restic-server` |
| `gaming/` | `minecraft-server` |
| `virtualisation/` | `podman`, `kvm`, `docker`, `colima`, `lima`, `qemu`, `rancher` |
| `<feature>/` | `k3s`, `printing`, `syncthing`, `kdeconnect`, `teamviewer` |

**Group aggregators.** Today's `services/{media,backup,gaming}/default.nix` bundle their members. They merge into the role of the same purpose (`media-server`, `backup`, `gaming-server`) in `../roles/`, and options the group shares move with them.

Examples:
- `nixos/services/virtualisation/podman` + `darwin/services/virtualisation/podman` + `home/virtualization/podman` → `services/virtualisation/podman/`, aspect `podman`.
- `nixos/services/media/qbittorrent` → `services/media/qbittorrent/`, aspect `qbittorrent`.
- `nixos/services/networking/tailscale` + `darwin/services/networking/tailscale` → `services/networking/tailscale/`, aspect `tailscale`.

Rules: [../README.md](../README.md).
