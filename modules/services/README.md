# services/

Daemons and servers.

| Sub-directory | Features (from `master`) |
|---|---|
| `networking/` | `tailscale` (done), `openvpn`, `nginx` (done), `socket-vmnet` |
| `media/` | `jellyfin`, `sonarr`, `radarr`, `prowlarr`, `flaresolverr`, `recyclarr`, `qbittorrent`, `calibre`, `minidlna` (all done, one `.nix` each), plus `media-library` and `arr-factory.nix` (below) |
| `backup/` | `restic`, `restic-server` |
| `gaming/` | `minecraft-server` |
| `virtualisation/` | `podman`, `kvm`, `docker`, `colima`, `lima`, `qemu`, `rancher` |
| `<feature>/` | `k3s`, `printing`, `syncthing`, `kdeconnect`, `teamviewer` |

**Group aggregators.** Today's `services/{media,backup,gaming}/default.nix` bundle their members. They merge into the role of the same purpose (`media-server`, `backup`, `gaming-server`) in `../roles/`. Shared facts don't go in the role, which would make features depend on it: media's group, `/data` layout and ports are `constants.media` and `constants.network.ports`. Each media feature imports what it uses (`media-library`, `nginx`), never the role or a system type.

Examples:
- `nixos/services/virtualisation/podman` + `darwin/services/virtualisation/podman` + `home/virtualization/podman` → `services/virtualisation/podman/`, aspect `podman`.
- `nixos/services/media/qbittorrent` → `services/media/qbittorrent.nix`, aspect `qbittorrent`.
- `nixos/services/networking/tailscale` + `darwin/services/networking/tailscale` → `services/networking/tailscale/`, aspect `tailscale`.

`media/media-library.nix`: the `media` group, the library root `/data/media` (owned by root, so no service owns another's directory), and `nix-config.media.users.<name> = { home; description; extraGroups; secrets; templates; }`, which gives each media service's system user the same shape and makes its SOPS secrets and templates readable by that user only.

`media/arr-factory.nix`: `config.factory.arr { name; title; userDescription; dataDir ? "/var/lib/<name>"; category ? null; upstreamPaths ? true; }` returns the nixos module radarr, sonarr and prowlarr share: the port from `constants.network.ports.<name>.web`, a media user with the `service-<name>-api-key` secret and the `config.xml` template (bound to loopback) installed by `preStart`, the upstream service with its firewall closed, and an nginx vhost behind the htpasswd. With `upstreamPaths` the upstream service gets the user, group and data dir; `category` adds the category's library dir. prowlarr passes `upstreamPaths = false` (nixpkgs #445983). The factory's tests cover all three arrs.

Rules: [../README.md](../README.md).
