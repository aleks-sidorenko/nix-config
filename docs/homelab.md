# Homelab

`server` is a mini PC (Intel Core i3-7020U, 8 GB RAM, 2 TB SATA SSD) on the
home Wi-Fi, running `roles.home-server`. `server-vm` runs the same role as a
test guest; CI install-tests it in place of `server`.

## Services

| Service | Aspect | Site | Port | Proxy auth | State |
| --- | --- | --- | --- | --- | --- |
| Jellyfin (media server) | `services.jellyfin` | `jellyfin` | 8096 | no, own login | `/var/lib/jellyfin` |
| Sonarr (series) | `services.sonarr` | `sonarr` | 8989 | yes | `/var/lib/sonarr` |
| Radarr (movies) | `services.radarr` | `radarr` | 7878 | yes | `/var/lib/radarr` |
| Prowlarr (indexers) | `services.prowlarr` | `prowlarr` | 9696 | yes | `/var/lib/private/prowlarr` |
| qBittorrent | `services.qbittorrent` | `qbittorrent` | 8080 | yes | `/var/lib/qbittorrent` |
| Calibre-Web (books) | `services.calibre-web` | `calibre` | 8083 | no, own login | `/var/lib/calibre-web` |
| MiniDLNA | `services.minidlna` | `minidlna` | 8200 | yes | `/var/cache/minidlna` |
| FlareSolverr | `services.flaresolverr` | none | 8191, loopback only | — | none |
| Recyclarr | `services.recyclarr` | none | — | — | `/var/lib/recyclarr` |
| Minecraft | `services.minecraft-server` | none | 25565 | — | `/var/lib/minecraft` |

- **Sonarr and Radarr** import finished downloads by hardlink, so downloads
  and the library share `/data`. Their API keys come from SOPS
  (`service-<app>-api-key`) and are rendered into each app's `config.xml`.
- **Prowlarr** feeds indexers to Sonarr and Radarr. FlareSolverr listens on
  loopback for the indexers behind a browser challenge.
- **Recyclarr** syncs TRaSH quality profiles into Sonarr and Radarr daily,
  directly over loopback. It targets 720p, with 1080p as a fallback.
- **qBittorrent**'s settings are rendered from nix at every start, with the
  web password from `service-qbittorrent-<user>-password`; the web login is
  the host's `primaryUser`. Peers connect on 17348 (TCP and UDP).
- **MiniDLNA** serves Movies and Series to TVs on the LAN. TVs find it over
  SSDP (UDP 1900) and stream from port 8200 directly; only its status page
  goes through the proxy.
- **Calibre-Web** keeps its library at `/data/media/Books` and creates an
  empty one on first start.
- **Minecraft**: operators, whitelist, difficulty and gamerules are settings
  in `modules/hosts/home-servers.nix`; gamerules apply through a datapack on
  world load. The heap is 2 GB.

## Ingress

nginx serves each proxied service at `<site>.home.sidorenko.me`, the nginx
`domain` setting. Those names resolve to the server's tailnet address, and
ports 80 and 443 are open only on `tailscale0`, so the sites are reachable
from the tailnet and not from the LAN. Traffic is plain HTTP inside the
tailnet; 443 is open so an upgraded request is refused instead of hanging.

Sites marked "proxy auth" need HTTP basic auth from the `service-ingress-htpasswd`
secret: those apps trust every request that reaches them. An unknown `Host`
gets connection closed (444) instead of the first site.

The records are the `dns` stack (`modules/infra/dns.nix`,
`just infra-apply dns`), in the `sidorenko.me` zone beside the static site's
apex, `www` and the mail records. A service gets a record by being included
on a host with `deploy`: nginx publishes each of its vhosts' names, Minecraft
publishes `minecraft.<public>`. Each name is an unproxied A record at the
host's tailnet address, read from the tailnet at plan time. `server-vm`
publishes nothing, since it would claim every name `server` does.

Evaluation fails when two hosts publish the same name (DNS would round-robin
between them) or one host publishes a name twice. The plan fails when two
tailnet devices share a hostname (remove the stale one with
`just tailnet-revoke`) or a publishing host is not on the tailnet, rather
than planning its records away.

## Storage

```
/data/torrents/{Movies,Series}    qBittorrent downloads
/data/media/{Movies,Series}       the Sonarr and Radarr libraries
/data/media/Books                 the Calibre library
```

Everything under `/data` sits on its own subvolume and survives reboots.
Service state lives under `/var/lib` (or `/var/cache`), bind-mounted from
`/persist`; root itself is reset at every boot (see
[architecture](architecture.md#storage)). All media services share the
`media` group.

## Network

The box has only Wi-Fi. NetworkManager manages it, and the saved connection
is persisted state (`/etc/NetworkManager/system-connections`), not part of
this config: losing it takes the box off the network. The LAN domain is
`lan`, and the tailnet's MagicDNS domain comes first in the search list.

Tailscale joins unattended with the `system-tailscale-auth-key` secret, an
OAuth client secret, and retries until it succeeds. The key registers only a
tagged node, so the host advertises its `services.tailscale.tags` setting
(`tag:server`); a node removed from the tailnet rejoins at the next boot.
Darwin hosts join the same way through a launchd daemon.

The tailnet ACL is the `tailnet` stack (`modules/infra/tailnet.nix`,
`just infra-apply tailnet`). Its tags are every host's
`services.tailscale.tags`, each owned by `tag:registrar`, the OAuth client's
tag. Servers (`tag:server`) are reachable from the other tags on 22, 80, 443
and 25565 only; the other tags reach each other on every port, and SSH reaches
every tag. Removing a tag from den drops it from the ACL, so first re-advertise
the live node without it (`tailscale up --advertise-tags=…`), then apply: no
device may hold a tag the ACL no longer owns.

A reinstalled guest registers a new node and leaves the old one behind, which
trips the dns stack's ambiguous-hostname guard. `just tailnet-revoke <host>`
lists the devices with that hostname (a dry run); add `--apply` to delete them
after typing the hostname. It reads `infra/secrets.yaml`, and the OAuth client
needs the `devices:core` write scope.

The firewall is open on all interfaces for SSH (22), MiniDLNA (8200/TCP,
1900/UDP), qBittorrent peers (17348), Minecraft (25565) and Tailscale
(41641/UDP), and on the tailnet for 80 and 443.

## Backups

restic backs each `home-server` host up every night at 03:00 (with up to
30 minutes' random delay) to its own repository in the R2 bucket `backups`
(managed by the `storage` stack, `just infra-plan storage`), at
`backups/<host>`. A night the host is off is skipped, not run at boot.

- **What**: `/home`, `/root`, the whole `/persist`, and the Calibre library.
  The rest of `/data` can be fetched again and is not backed up. Jellyfin's
  cache, temporary files, logs and build artifacts are excluded. The host's
  SSH key is under `/persist`, so a restore brings back its SOPS identity.
- **Retention**: 7 daily, 4 weekly, 6 monthly and 2 yearly snapshots.
- **Credentials** (SOPS): `service-restic-password` (the repository password)
  and `service-restic-r2-access-key-id` / `service-restic-r2-secret-access-key`
  (an R2 token limited to the bucket). Rotate the token by creating a new one,
  updating both secrets, deploying, then revoking the old one.
- **Failures are silent**: check `systemctl status restic-backups-default`.
- The install test turns the timer off: its VM has no network.

### Restore

On the host, or a fresh one with the same identity:

```bash
sudo -u restic restic-default snapshots
sudo restic-default restore --no-cache <snapshot-id> --target /tmp/restore --include /persist/var/lib/<service>
```

`restic-default` wraps restic with the repository, password and R2
credentials. Read-only commands run as the `restic` user, which owns the
cache; `restore` runs as root, so it skips the cache rather than leave
root-owned files in it.

If every device is lost, a restore needs only this repository and the PGP
private key that decrypts the SOPS secrets.

## Deploys and rollback

```bash
just deploy server            # build on the box and switch now
just deploy server --boot     # build on the box; switch at the next boot
```

Use `--boot` for changes that are risky to switch live, then reboot with
someone at the keyboard. The boot menu lists the last 3 generations, so
rolling back means choosing the previous entry. nh prunes old generations
weekly but always keeps the last 5 and anything from the last 7 days.

After a deploy, check that `systemctl --failed` is empty and that the sites
answer.
