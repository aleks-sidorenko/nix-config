# services/

Daemons and servers.

| Sub-directory | Features (from `master`) |
|---|---|
| `networking/` | `tailscale` (done), `openvpn`, `nginx` (done), `socket-vmnet` |
| `media/` | `jellyfin`, `sonarr`, `radarr`, `prowlarr`, `recyclarr`, `qbittorrent`, `calibre`, `minidlna` (all done, one `.nix` each), plus `media-library` (the `media` group and `/data` layout they share) |
| `backup/` | `restic`, `restic-server` |
| `gaming/` | `minecraft-server` |
| `virtualisation/` | `podman`, `kvm`, `docker`, `colima`, `lima`, `qemu`, `rancher` |
| `<feature>/` | `k3s`, `printing`, `syncthing`, `kdeconnect`, `teamviewer` |

**Group aggregators.** Today's `services/{media,backup,gaming}/default.nix` bundle their members. They merge into the role of the same purpose (`media-server`, `backup`, `gaming-server`) in `../roles/`. Shared facts don't go in the role, which would make features depend on it: media's group and layout are the `media-library` feature, which each media feature imports.

Examples:
- `nixos/services/virtualisation/podman` + `darwin/services/virtualisation/podman` + `home/virtualization/podman` → `services/virtualisation/podman/`, aspect `podman`.
- `nixos/services/media/qbittorrent` → `services/media/qbittorrent.nix`, aspect `qbittorrent`.
- `nixos/services/networking/tailscale` + `darwin/services/networking/tailscale` → `services/networking/tailscale/`, aspect `tailscale`.

Rules: [../README.md](../README.md).
