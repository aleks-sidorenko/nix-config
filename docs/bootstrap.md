# Bootstrap

From nothing to a running fleet, in order: each step needs the ones before
it. Day-to-day changes are in [AGENTS.md](../AGENTS.md); what `server` runs,
in [homelab.md](homelab.md).

## 1. Operator

- The owner's PGP key, with its secret subkeys, on the machine you work from
  (`gpg --card-status` or `gpg -K`). Every secrets file is encrypted to its
  encryption subkey; the public key is `identities/<id>/gpg.pub.asc`.
- Nix with flakes, and this repository. Recipes enter the dev shell
  (`nix develop`) themselves.

## 2. Infra credentials

Provider credentials live once in `infra/secrets.yaml`
(`just infra-secrets-edit`): `cloudflare-api-token`, `github-token`,
`tailscale-oauth-client-id` and `tailscale-oauth-client-secret` (the stacks'
OAuth client, not the registrar below).

A stack's own `infra/<stack>/secrets.yaml` holds its `state-passphrase`, which
encrypts its committed state; losing it loses the state. For a new stack:

1. `just infra-secrets-edit <stack>` and set `state-passphrase` to a long
   random string.
2. `just infra-validate <stack>`; commit `.terraform.lock.hcl` and
   `secrets.yaml`.
3. `just infra-plan <stack>`, `just infra-apply <stack>`; commit
   `terraform.tfstate`.

Recipients of every secrets file are generated (`just sops-write`), so a new
stack needs no `.sops.yaml` edit.

## 3. Tailnet

Hosts join the tailnet unattended at first boot, so the tailnet comes before
any host.

1. `just infra-apply tailnet`: the ACL, which makes `tag:registrar` own every
   host tag.
2. In the Tailscale admin console, Settings → OAuth clients, create the
   registrar client: scope `auth_keys` Write only, tag `tag:registrar`. The
   secret (`tskey-client-…`) is shown once.
3. Paste it verbatim as `system-tailscale-auth-key` into
   `sops secrets/nixos.yaml` and `sops secrets/darwin.yaml`.

## 4. Router

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
   and the upstream's SSID and passphrase; `<user>` is the stack's
   `identity`:

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
   /user add name=<user> group=full password="<router-api-password>"
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
   as `<user>` and remove the script, it holds secrets: `/file remove bootstrap.rsc`. Check the uplink:

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

## 5. A NixOS host

1. Define it ([AGENTS.md, A host](../AGENTS.md#a-host)). From the installer,
   capture what the config needs:

   ```
   ls -l /dev/disk/by-id                                       # settings.storage.disko.device
   nixos-generate-config --show-hardware-config --no-filesystems  # _hardware.nix
   ```

2. `just iso-fetch iso-x86_64`, `just iso-write iso-x86_64 <device>`, and boot
   the machine from the stick. Root logs in with the owner's SSH key.
3. `just bootstrap-nixos <host> <address>`. It
   - reuses the host's identity from `hosts/<host>/ssh.yaml`, or creates
     one: `ssh.pub` in plaintext, the private key encrypted to the owner;
   - regenerates `.sops.yaml` and re-keys every secrets file, so the host can
     read its secrets on first boot;
   - shows the target's disks next to the configured one and asks for the
     host name typed back;
   - asks for the disk passphrase twice when the host's disk is encrypted;
   - installs with nixos-anywhere, building on the target, with the key
     placed where the host reads it.

   Arguments after `--` go to nixos-anywhere. Interrupted, the same command
   picks up where it stopped; with `--new-key`, a rerun makes yet another
   key, so drop the flag once the first run has created one. It checks the
   target first: a wrong address or an installed host changes nothing.
4. Commit `.sops.yaml`, `hosts/`, `secrets/` and `infra/` (the re-keyed files are
   staged), and run what it prints:
   `just infra-apply dns` for a deployed host that publishes names,
   `just infra-apply router` for one with a LAN address.
5. Later changes: `just deploy <host>`.

## 6. A Mac

1. Install Nix, clone the repository, and define the host
   ([AGENTS.md, A darwin host](../AGENTS.md#a-darwin-host)).
2. On the Mac, `just bootstrap-darwin <host>`. With no identity in the repo
   it adopts the Mac's own `/etc/ssh` key; with one, it puts it in place of
   a different key, after the host name is typed back.
3. Commit `.sops.yaml`, `hosts/`, `secrets/` and `infra/`, then
   `nix run .#<host> -- switch`. If the key in `/etc/ssh` was replaced,
   restart sshd as it prints.

## 7. Reinstalling

Boot the machine from the installer and run the same command as the first
install; on the running system it stops, since root may not log in. The
host keeps its identity, so its
secrets, backups and SSH host key are unchanged. `--new-key` rotates it: the
old key can no longer decrypt anything once the run re-keys, so a live host
is cut off until it is reinstalled.

A reinstall registers a new tailnet node; remove the old one in the admin
console (Machines) before `just infra-apply dns`.

## 8. Retiring a host

1. Remove its `den.hosts` entry and module, and `hosts/<host>/`.
2. `just sops-rekey`: regenerates `.sops.yaml` and re-keys every secrets
   file, so the host can no longer read them. Commit `.sops.yaml`,
   `hosts/`, `secrets/` and `infra/`.
3. Remove its tailnet node in the admin console; the stacks cannot delete
   devices.
4. `just infra-apply dns` and `just infra-apply router` if it had names or a
   LAN lease.
