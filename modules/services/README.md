# services/

Daemons and servers.

| Sub-directory | Features (from `master`) |
|---|---|
| `networking/` | `tailscale` (done), `openvpn`, `nginx` (done), `socket-vmnet` |
| `media/` | `jellyfin`, `sonarr`, `radarr`, `prowlarr`, `recyclarr`, `qbittorrent`, `calibre`, `minidlna` (all done, one `.nix` each), plus `media-library` (the `media` group and `/data` layout they share) and `arr-factory.nix` (below) |
| `backup/` | `restic`, `restic-server` |
| `gaming/` | `minecraft-server` |
| `virtualisation/` | `podman`, `kvm`, `docker`, `colima`, `lima`, `qemu`, `rancher` |
| `<feature>/` | `k3s`, `printing`, `syncthing`, `kdeconnect`, `teamviewer` |

**Group aggregators.** Today's `services/{media,backup,gaming}/default.nix` bundle their members. They merge into the role of the same purpose (`media-server`, `backup`, `gaming-server`) in `../roles/`. Shared facts don't go in the role, which would make features depend on it: media's group and layout are the `media-library` feature, which each media feature imports.

Examples:
- `nixos/services/virtualisation/podman` + `darwin/services/virtualisation/podman` + `home/virtualization/podman` → `services/virtualisation/podman/`, aspect `podman`.
- `nixos/services/media/qbittorrent` → `services/media/qbittorrent.nix`, aspect `qbittorrent`.
- `nixos/services/networking/tailscale` + `darwin/services/networking/tailscale` → `services/networking/tailscale/`, aspect `tailscale`.

`media/arr-factory.nix`: `config.factory.arr { name; title; userDescription; dataDir ? "/var/lib/<name>"; }` returns the nixos module radarr, sonarr and prowlarr share: the `service-<name>-api-key` secret, the `config.xml` SOPS template (bound to loopback) installed by `preStart`, a system user in `media`, the upstream service with its firewall closed, and an nginx vhost behind the htpasswd. It also gives radarr and sonarr their upstream user, group and data dir, and their tmpfiles (`category` adds the media root and library dir; `ownsMediaRoot` puts sonarr's rules first, since the first rule owns `/data/media`). prowlarr passes `upstreamPaths = false` (nixpkgs #445983). Features add only their port.

Rules: [../README.md](../README.md).
