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
`domain` setting. On the tailnet those names resolve to the server's tailnet
address; on the LAN the router's DNS answers them with the server's LAN address
(split-horizon). Ports 80 and 443 are open on every interface, so both are
reachable. Traffic is plain HTTP; 443 is open so an upgraded request is
refused instead of hanging.

Sites marked "proxy auth" need HTTP basic auth from the
`service-ingress-htpasswd` secret: those apps trust every request that reaches
them, on the LAN as on the tailnet. An unknown `Host` gets connection closed
(444) instead of the first site.

The records are the `dns` stack (`modules/infra/dns.nix`,
`just infra-apply dns`), in the `sidorenko.me` zone beside the static site's
apex, `www` and the mail records. A service gets a record by being included
on a host with `deploy`: nginx publishes each of its vhosts' names, Minecraft
publishes `minecraft.<public>`. Each name is an unproxied A record at the
host's tailnet address, read from the tailnet at plan time. `server-vm`
publishes nothing, since it would claim every name `server` does.

Evaluation fails when two hosts publish the same name (DNS would round-robin
between them) or one host publishes a name twice. The plan fails when two
tailnet devices share a hostname (remove the stale one in the admin
console) or a publishing host is not on the tailnet, rather
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

The box has only Wi-Fi; its address on the LAN is reserved by the router
(see [Router](#router)). NetworkManager manages it, and the saved connection
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
trips the dns stack's ambiguous-hostname guard. Remove the old node in the
Tailscale admin console (Machines): the stacks' OAuth client deliberately has
no `devices:core` write scope, so nothing here can delete devices.

The firewall is open on all interfaces for SSH (22), HTTP and HTTPS (80, 443),
MiniDLNA (8200/TCP, 1900/UDP), qBittorrent peers (17348), Minecraft (25565) and
Tailscale (41641/UDP).

## Router

A MikroTik hAP ax³ is the LAN's router, DHCP and DNS server, managed by the
`router` stack (`modules/infra/router.nix`, `just infra-plan router`).

| Device | Address |
| --- | --- |
| router | `10.0.0.1` |
| `server` | `10.0.0.10`, static lease from its `lan` option |
| DHCP pool | `10.0.0.100`-`10.0.0.250` |

`ether2` is the ISP uplink, a Wi-Fi station on `wifi2` the hotspot fallback.
The library makes `wifi2` the station master, so the `SWEET-HOME` access point
on that radio is a virtual interface following the station and likely does not
broadcast while the station has no upstream. Clients only on that band depend
on the station; `server`'s Wi-Fi NIC must associate on the other radio's band
before cut-over. `runtimeManaged` makes the stack ignore the station's
configuration and security, so set its mode, SSID and passphrase by hand once
after import:

```
/interface wifi set wifi2 configuration.mode=station configuration.ssid=<upstream> security.passphrase=<passphrase>
```

Verify the port and radio names on the device before the first plan: which
`wifiN` is 2.4 GHz and which 5 GHz, and which `etherN` is the 2.5G port, are
read from `/interface print` and `/interface wifi print`. The Wi-Fi country is
the `country` setting, in the string form RouterOS expects (`Ukraine`).

The API is reachable from the LAN only (`/ip service set api
address=10.0.0.0/24`), so plan and apply from a LAN machine. Off the LAN,
SSH to `server` and run the recipe there; that needs the owner's PGP key
usable on `server` (gpg-agent forwarding) and a checkout with the committed
state, since `infra/router/secrets.yaml` is not encrypted to `server`.
Otherwise plan and apply from a machine on the LAN.

### Bring-up

Apply onto a device with no default configuration. Plug the admin machine
into a LAN port (`ether1`, `ether3`, `ether4` or `ether5`, never the ISP
uplink `ether2`); that is `<port>` below. The library bridges every ethernet
port except the uplinks. A reset device has no DHCP server, so give the admin
machine a static address in `10.0.0.0/24` (e.g. `10.0.0.2/24`, no gateway)
for the bring-up. The device has no uplink, NAT or DHCP yet, so that
interface has no internet: warm the caches while still online
(`just infra-validate router`, or `nix build .#router.config`), and keep
internet on another interface, since `just infra-plan router` runs `tofu init`.
The reset reboots the device, so reconnect afterwards. Run the console steps over the console or WinBox (which connects by
MAC); once the address is set the API answers on `10.0.0.1`, port 8728:

```
/system reset-configuration no-defaults=yes
/interface bridge add name=bridge
/interface bridge port add bridge=bridge interface=<port>
/ip address add address=10.0.0.1/24 interface=bridge
/user add name=<apiUser> group=full password=…
/ip service set api address=10.0.0.0/24
```

`<apiUser>` is the `apiUser` setting; its password is the
`router-api-password` secret in `infra/router/secrets.yaml`. The user is not a
managed resource, and the library adopts the built-in `ip_service` entries by
their numbers, so neither needs an import. Read the ids of what the stack must
adopt with `print show-ids`, in `/interface bridge`, `/interface bridge port`,
`/ip address` and `/interface wifi`, and set them in the router stack's
settings in `modules/infra/router.nix`:

```nix
den.stacks.router.settings.infra.router.bringUpIds = {
  "routeros_interface_bridge.bridge" = "*1";
  "routeros_interface_bridge_port.<port>" = "*1";
  "routeros_ip_address.lan" = "*1";
  "routeros_wifi.wifi1" = "*1";
  "routeros_wifi.wifi2" = "*2";
};
```

The bridge port key is `routeros_interface_bridge_port.<port>`, with the name
of the port you plugged into; the radios are those carrying a network or
station. Then `just infra-plan router` and apply, and switch the admin machine
back to DHCP. The first apply restricts SSH and WinBox to the LAN. Once the
state holds them, the ids may stay: an import of an already-managed resource
is a no-op.

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
