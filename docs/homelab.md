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

The router has no cables: its only uplink is a Wi-Fi station on `wifi2`
joining the upstream network, and every LAN device, `server` included, joins
the `SWEET-HOME` access point. Every ethernet port is a LAN bridge port, unused.
The SSID is the `system.networking.wifi.ssid` setting and the password
`system-wifi-password` in `secrets/nixos.yaml`; the router broadcasts them and
hosts including `system.wifi` (`server`) join with a NetworkManager profile
that outranks any made by hand.
The library makes `wifi2` the station master, so the access point on that
radio is a virtual interface following the station: it shares the upstream's
channel and likely does not broadcast while the station has no upstream.
`server` must associate on `wifi1`'s band. `runtimeManaged` makes the stack
ignore the station's configuration and security: the upstream's SSID and
passphrase live only on the device, set by the bootstrap script and changed by
hand:

```
/interface wifi set wifi2 configuration.mode=station configuration.ssid="<upstream>" security.authentication-types=wpa2-psk,wpa3-psk security.passphrase="<passphrase>" disabled=no
```

`wifi1` is 5 GHz and `wifi2` 2.4 GHz, so the upstream must broadcast on
2.4 GHz (`/interface wifi scan wifi2`). The Wi-Fi country is the `country`
setting, in the string form RouterOS expects (`Ukraine`).

The API is reachable from the LAN only (`/ip service set api
address=10.0.0.0/24`), so plan and apply from a machine on `SWEET-HOME`. Off
the LAN, SSH to `server` and run the recipe there; that needs the owner's PGP
key usable on `server` (gpg-agent forwarding) and a checkout with the committed
state, since `infra/router/secrets.yaml` is not encrypted to `server`.

### Bootstrap

The stack applies onto a device with no default configuration, over the API,
from a laptop on the router's own Wi-Fi. A reset with `no-defaults` leaves no
access point to join, so the reset itself runs a script that brings up
`SWEET-HOME` on `wifi1`, the bridge, the address, the LAN's DHCP server, the
upstream's DHCP client and the API user, with the values the stack renders so
that the first apply adopts them. It also adds a temporary NAT rule, tagged
`bootstrap`, so the laptop is online from the start. The apply runs `tofu
init` first, which needs the internet: the router must stay online throughout.

1. Write `bootstrap.rsc`, filling the secrets from
   `sops secrets/nixos.yaml` (`system-wifi-password`) and
   `just infra-secrets-edit router` (`router-api-password`)
   and the upstream's SSID and passphrase; `<apiUser>` is the `apiUser`
   setting:

   ```
   :delay 15s
   /interface bridge add name=bridge
   /interface wifi security add name=home authentication-types=wpa2-psk,wpa3-psk passphrase="<wifi-password>"
   /interface wifi configuration add name=home mode=ap ssid=SWEET-HOME country=Ukraine security=home
   /interface wifi set wifi1 configuration=home disabled=no
   /interface wifi set wifi2 configuration.mode=station configuration.ssid="<upstream>" security.authentication-types=wpa2-psk,wpa3-psk security.passphrase="<passphrase>" disabled=no
   /interface bridge port add bridge=bridge interface=wifi1
   /ip address add address=10.0.0.1/24 interface=bridge comment=defconf
   /ip pool add name=lan ranges=10.0.0.100-10.0.0.250
   /ip dhcp-server add name=lan interface=bridge address-pool=lan lease-time=1d
   /ip dhcp-server network add address=10.0.0.0/24 gateway=10.0.0.1 dns-server=1.1.1.1
   /ip dhcp-client add interface=wifi2 comment=bootstrap
   /ip firewall nat add chain=srcnat out-interface=wifi2 action=masquerade comment=bootstrap
   /user add name=<apiUser> group=full password="<router-api-password>"
   /ip service set api address=10.0.0.0/24
   ```

2. Join the factory Wi-Fi (SSID and password on the device's label), open
   WinBox at `192.168.88.1`, upload `bootstrap.rsc` under Files, then in a
   terminal:

   ```
   /system reset-configuration no-defaults=yes skip-backup=yes run-after-reset=bootstrap.rsc
   ```

3. After the reboot, join `SWEET-HOME`; the laptop gets an address by DHCP
   and reaches the internet through the router. Connect WinBox to `10.0.0.1`
   as `<apiUser>` and remove the script, it holds secrets: `/file remove bootstrap.rsc`. Check the uplink:

   ```
   /interface wifi monitor wifi2 once
   /ping 1.1.1.1 count=3
   ```

   `connected-to-ess` and replies mean the laptop is online too. The DHCP
   server hands out `1.1.1.1` for DNS until the apply turns on the router's
   resolver behind its firewall.
4. Read the ids:

   ```
   /interface bridge print show-ids proplist=name; /interface bridge port print show-ids proplist=interface; /ip address print show-ids proplist=address; /interface wifi print show-ids proplist=name; /interface wifi configuration print show-ids proplist=name; /interface wifi security print show-ids proplist=name; /ip pool print show-ids proplist=name; /ip dhcp-server print show-ids proplist=name; /ip dhcp-server network print show-ids proplist=address; /ip dhcp-client print show-ids proplist=interface
   ```

   and set them in `modules/infra/router.nix`:

   ```nix
   den.stacks.router.settings.infra.router.importIds = {
     "routeros_interface_bridge.bridge" = "*…";
     "routeros_interface_bridge_port.wifi1" = "*…";
     "routeros_ip_address.lan" = "*…";
     "routeros_ip_dhcp_client.upstream" = "*…";
     "routeros_ip_dhcp_server.lan" = "*…";
     "routeros_ip_dhcp_server_network.lan" = "*…";
     "routeros_ip_pool.lan" = "*…";
     "routeros_wifi.wifi1" = "*…";
     "routeros_wifi.wifi2" = "*…";
     "routeros_wifi_configuration.home" = "*…";
     "routeros_wifi_security.home" = "*…";
   };
   ```

5. `just infra-plan router`: the adopted objects should show only in-place
   updates, nothing replaced. Then `just infra-apply router`. The apply
   restricts SSH and WinBox to the LAN and turns off the DHCP client's own
   default route: the stack's route goes through the probe host instead, which
   the client's script routes only when a lease binds. Bind it again, then drop
   the temporary NAT:

   ```
   /ip dhcp-client release [find comment=upstream]
   /ip firewall nat remove [find comment=bootstrap]
   /ip route print where dst-address=0.0.0.0/0
   ```

   The default route via `9.9.9.9` should be active. The laptop's next lease
   points DNS at the router.
6. Re-plan: no changes. Commit `infra/router/terraform.tfstate`.

Once the state holds them, the ids may stay: an import of an
already-managed resource is a no-op.

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
