# Bootstrap & Installation

This guide walks through installing NixOS on a **new host** from start to finish,
using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and the
bootstrap scripts in this repository.

> **Bootstrapping a Mac?** macOS can't be installed with nixos-anywhere — it uses
> a different, run-on-the-machine flow. Jump to
> [macOS (nix-darwin) bootstrap](#macos-nix-darwin).

Follow the steps **in order** — each one depends on the previous. In particular,
the host must become a SOPS recipient *before* you deploy, because the system
decrypts user passwords and other secrets at boot (see
[Step 4](#step-4--generate-host-keys--register-with-sops)).

## NixOS

**Remote and local** — Steps 1–5 are shared; [Step 6](#step-6--deploy) splits
into a remote install driven from your machine (nixos-anywhere) and a local,
on-machine install run on the target itself.

### The NixOS flow at a glance

```
1. Define the host in the flake        (systems/…, homes/…, users)
2. Prepare your local machine          (tools: pass, nix, ssh, nixos-anywhere)
3. Boot the target                     (installer ISO — verify SSH, capture disks + hardware)
4. Generate host keys → register SOPS   (bootstrap-secrets, .sops.yaml, updatekeys)
5. Add the secrets the host needs      (user-<name>-password)
6. Deploy                              (bootstrap / bootstrap-deploy + disko — or on-machine disko + nixos-install)
7. Post-install                        (FIDO2, …)
```

Steps 4–6 can be run as a single `just bootstrap` command (it pauses at the SOPS
step for you), or split apart for more control. Both paths are covered below.

A **VM guest** follows this same flow — installer ISO plus `nixos-anywhere` —
with QEMU standing in for hardware; only how you reach Step 3 differs. See
[VM guests (QEMU on macOS)](#vm-guests-qemu-on-macos).

---

### Step 1 — Define the host in the flake

Nothing can be deployed until the host exists in the flake. Create the system
directory following snowfall-lib conventions:

```
systems/<arch>/<hostname>/
├── default.nix     # roles, users, stateVersion
├── hardware.nix    # imports, kernel modules, firmware
└── disks.nix       # disko layout (see "Disk layout with disko" below)
```

> **`hardware.nix` and `disks.nix` hold machine-specific values you can't know
> yet** — the disk's stable `/dev/disk/by-id/…` path and the target's kernel
> modules / microcode vendor. Start them from a similar host (or the `server-vm`
> files) and **finalize them after booting the target** in
> [Step 3 → Capture the target's disks & hardware](#capture-the-targets-disks--hardware).
> Leaving `REPLACE-ME` in `disks.nix` makes disko fail during deploy.

Example `default.nix` (from `server-vm`):

```nix
{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  ${namespace} = {
    roles = {
      home-server = enabled;

      # The plugs, heatpump and climate sensors its automations name stayed
      # with the old house.
      smart-home = disabled;

      # Off until there is somewhere off-box to back up to. Backing a laptop
      # guest up to its own disk protects against neither the loss of the host
      # Mac's disk, which both qcow2 files live on, nor a reinstall, which
      # rewrites the root disk the system itself sits on — so the two roles
      # would buy only the appearance of coverage. Disabling the server drops its
      # nginx vhost, which proxied the unauthenticated REST endpoint onto
      # whatever LAN the host Mac had joined.
      backup = disabled;
      backup-server = disabled;
    };

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
```

Then create a home for each account under `homes/<arch>/<user>@<hostname>/`,
selecting the roles it should get. See
[Users & Identities](architecture.md#users--identities) for the full model, and
[Adding a user to an existing host](#adding-a-user-to-an-existing-host) if you are
adding an account rather than a whole host.

Confirm the host is discoverable before continuing:

```bash
just bootstrap-targets    # should list your new hostname
just list-configs nixos   # sanity-check the config evaluates
```

### Step 2 — Prepare your local machine

Bootstrap runs from your machine and pushes to the target. You need:

- SSH access to the target with **passwordless sudo**
- [`pass`](https://www.passwordstore.org/) configured with file storage — used to
  back up the host's SSH keys and disk password
- These tools on `PATH`: `ssh-keygen`, `pass`, `nix`, `mktemp`, `nixos-anywhere`
- For disk encryption: a LUKS password you choose now

### Step 3 — Boot the target

The target must be reachable over SSH before bootstrap can run.

#### Fresh machine with no OS — build the installer ISO

Build the custom minimal installer ISO from this flake and write it to a USB stick:

```bash
# Identify the target USB device first (double-check — writing is destructive!)
lsblk

# Build the ISO and write it to the USB stick in one step (replace sdX)
just iso minimal-x86_64 /dev/sdX

# …or run the steps separately:
just iso-build minimal-x86_64            # -> ./result/iso/nixos-minimal-x86_64.iso
just iso-write minimal-x86_64 /dev/sdX   # dd the built image to the device
```

Boot the target from the USB stick. The **local console autologins** as
**`nixos`** (passwordless — the stock installer default). **SSH is key-based**
(password auth is disabled): the throwaway `nixos` user has no identity of its
own, so the ssh module authorizes the **owner identity** (`lib` `defaults.user`)
— i.e. you connect as `nixos@<host>` with your own private key, no password. The
ISO is defined by the `minimal` role (SSH, networking, locale, fish) in
`systems/x86_64-install-iso/minimal-x86_64/`.

> **Provisioning a VM guest?** `server-vm` runs under QEMU on the `workbook` and
> boots from the same kind of installer ISO, built for its own architecture
> (`just iso-build minimal-aarch64`) and booted with `just vm-install` instead
> of a USB stick. See [VM guests (QEMU on macOS)](#vm-guests-qemu-on-macos).

#### Verify connectivity

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes <username>@<hostname> "sudo -n true"
```

#### Capture the target's disks & hardware

The `hardware.nix` and `disks.nix` you stubbed in [Step 1](#step-1--define-the-host-in-the-flake)
must now be filled with values that only exist on the real machine. Do this while
booted into the installer, **before** deploying — disko formats the disk named in
`disks.nix`, so a wrong or placeholder device is destructive or fails outright.

**1. Find the system disk's stable `by-id` path** (SSH in or use the console):

```bash
lsblk -o NAME,SIZE,MODEL,TYPE          # identify the internal disk (not the USB installer)
ls -l /dev/disk/by-id/                 # map that disk to a stable id
```

Pick the **whole-disk** id for the internal drive — e.g. `nvme-Samsung_SSD_…`
or `ata-…` — **not** a `-part1`/`-partN` entry and **not** the `usb-…` installer
stick. Prefer `by-id` over `/dev/sda`/`/dev/nvme0n1`, which can reorder between
boots. Put it in `disks.nix`:

```nix
root.device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_1TB_XXXXXXXX";  # was REPLACE-ME
```

**2. Generate the hardware config:**

```bash
sudo nixos-generate-config --show-hardware-config --no-filesystems
```

This prints the detected `boot.initrd.availableKernelModules`, `boot.kernelModules`,
and CPU microcode vendor **without** writing any files. Copy the relevant values
into `hardware.nix`:

- Replace the `boot.initrd.availableKernelModules` list with the detected one.
- Set the microcode line to match the CPU —
  `hardware.cpu.intel.updateMicrocode` or `hardware.cpu.amd.updateMicrocode`.
- `--no-filesystems` is intentional: **disko owns the filesystem/mount config**,
  so you don't copy any generated `fileSystems.*` / `swapDevices` entries.

**3. Sanity-check the config still evaluates** from your local machine:

```bash
just list-configs nixos          # <hostname> should appear and evaluate
nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel.drvPath
```

Commit these edits before deploying so the built system matches what you tested.

### Step 4 — Generate host keys & register with SOPS

This is the pivotal step. The host needs an **age key** so sops-nix can decrypt
secrets at boot, but that key is *derived from the host's SSH host key*, which
doesn't exist yet. `bootstrap-secrets` resolves the chicken-and-egg: it generates
the SSH host key, derives the age key, and then **pauses** so you can register it.

```bash
# Generates the SSH host key + age key, then prompts you to update SOPS.
just bootstrap-secrets <hostname> [disk_password]
```

What it does:

1. Generates an Ed25519 SSH host key (or reuses one already in `pass`).
2. Backs up new keys to `pass` at `infra/host/<hostname>/ssh` and pushes to git.
3. Derives the host's age key with `ssh-to-age` and prints it.
4. If a `disk_password` was given, stores it in `pass` at
   `infra/host/<hostname>/disk` and writes `disk.key` for disko.
5. **Pauses**, waiting for you to add the age key to SOPS (next).

The keys land in a temporary directory structure consumed by `nixos-anywhere`:

```
$KEYSDIR/extra/persist/etc/ssh/
├── ssh_host_ed25519_key
└── ssh_host_ed25519_key.pub
$KEYSDIR/disk.key            # only when disk encryption is used
```

#### Register the host in `.sops.yaml`

You don't generate a separate age key — it's the host's **SSH public key
converted to age format** by `ssh-to-age`. `bootstrap-secrets` does this for you
and prints the result while it waits, in the exact form to paste into
`.sops.yaml`:

```
[INFO] Generated age key: age1xxxx...xxxx
[WARNING] Please add the following age key to your .sops.yaml file:
[WARNING]   - &<hostname> age1xxxx...xxxx
```

Copy that `age1…` value. To derive it manually at any time, run (after
`set -x KEYSDIR …` from the recipe output — see [Step 6](#step-6--deploy)):

```bash
ssh-to-age -i "$KEYSDIR/extra/persist/etc/ssh/ssh_host_ed25519_key.pub"
```

Then add it to `.sops.yaml`:

1. Add the host anchor under `hosts`:
   ```yaml
   keys:
     - &hosts:
       - &<hostname> age1xxxx...xxxx     # <- add your new host
   ```

2. Add the host to every creation rule whose secrets it must read (at minimum the
   NixOS rule; add the home rule if it has a home-manager config):
   ```yaml
   creation_rules:
     - path_regex: modules/nixos/secrets.ya?ml$
       key_groups:
         - pgp:
             - *alexander
           age:
             - *<hostname>                # <- add your new host
   ```

3. Re-encrypt existing secrets so the new host can decrypt them:
   ```bash
   sops updatekeys modules/nixos/secrets.yaml
   sops updatekeys modules/home/secrets.yaml
   ```

Then press **Enter** to let `bootstrap-secrets` finish. (Set `AUTO_APPROVE=1` to
skip the interactive pause once you've scripted the SOPS edit.)

> If you reuse SSH keys already in `pass`, the host is presumably already a SOPS
> recipient and the script skips this prompt.

### Step 5 — Add the secrets the host needs

Every account declared in Step 1 expects a `user-<name>-password` secret in
`modules/nixos/secrets.yaml`:

```bash
# Generate a password hash
nix-shell -p mkpasswd --run 'mkpasswd -m SHA-512'

# Edit secrets and add one entry per account: user-<name>-password
just secrets-edit nixos
```

> Because these are declared `neededForUsers = true`, the **host itself** decrypts
> them at boot. That only works if the host became a SOPS recipient in Step 4 and
> `sops updatekeys` has run — which is why SOPS comes first.

Add any other host-specific secrets the same way.

### Step 6 — Deploy

With keys registered and secrets in place, deploy with `nixos-anywhere`.

#### Remote — one command (recommended)

`just bootstrap` runs Steps 4–6 together, pausing at the SOPS prompt:

```bash
just bootstrap <hostname> [username] [disk_password] [extra_opts...]
```

Examples (connect as the installer's `nixos` user — see the note in
[How `<hostname>` reaches the target](#how-hostname-reaches-the-target-machine)):
```bash
just bootstrap myserver nixos                              # no disk encryption
just bootstrap myserver nixos "" --build-on-remote         # build on the target
just bootstrap myserver nixos MyPassword123                # with LUKS disk encryption
```

#### Remote — two-step (if you already ran `bootstrap-secrets`)

Reuse the keys directory printed by Step 4:

```fish
set -x KEYSDIR /tmp/tmp.XXXXXXXX        # path from bootstrap-secrets output
just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]
```

`nixos-anywhere` formats the disks (via disko), copies the SSH host key into
`/persist/etc/ssh`, installs NixOS, and reboots. If `disk.key` is present it is
passed through as `--disk-encryption-keys`.

#### Local — on-machine install (no nixos-anywhere)

Use this when the target is your **only** Nix machine — a first host with no other
box to push a build from. Everything runs **on the target**, booted into an
installer (this flake's minimal ISO, or the stock NixOS ISO — both ship `nix`). It
swaps only the deploy mechanism: Steps 1–5 are unchanged, you just run them here.
Because the install is local there is no SSH addressing to arrange — the
[addressing note below](#how-hostname-reaches-the-target-machine) applies only to
the nixos-anywhere paths.

The result is byte-for-byte the nixos-anywhere outcome: the same host key in
`/persist/etc/ssh`, the same SOPS recipient, a normal first generation.

1. **Get the flake onto the target and finalize hardware.** Clone the repo and
   complete [Step 3 → Capture the target's disks & hardware](#capture-the-targets-disks--hardware)
   on the machine itself, committing/pushing `disks.nix` + `hardware.nix`:
   ```bash
   export NIX_CONFIG='experimental-features = nix-command flakes'  # stock ISO only
   nix shell nixpkgs#git                                           # stock ISO only
   git clone https://github.com/aleks-sidorenko/nix-config && cd nix-config
   ```

2. **Format the disks with disko** — the very step the deploy path runs, just
   invoked locally instead of over SSH:
   ```bash
   sudo nix run github:nix-community/disko -- --mode disko --flake .#<hostname>
   ```
   disko mounts the new filesystem at `/mnt`. A LUKS host prompts for the
   passphrase you chose (enroll FIDO2 later —
   [Step 7](#fido2-auto-unlock-luks-hosts-optional)).

3. **Generate the host key into persisted storage and register SOPS**
   ([Step 4](#step-4--generate-host-keys--register-with-sops)). Write the key
   straight into `/mnt/persist/etc/ssh` — the exact spot nixos-anywhere's
   `--extra-files` fills — so sops-nix finds it on first boot:
   ```bash
   sudo mkdir -p /mnt/persist/etc/ssh
   sudo ssh-keygen -t ed25519 -N "" -C "root@<hostname>" \
     -f /mnt/persist/etc/ssh/ssh_host_ed25519_key
   nix run nixpkgs#ssh-to-age -- -i /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
   ```
   Add the printed `age1…` to `.sops.yaml` and rekey exactly as in Step 4, then add
   the `user-<name>-password` secrets ([Step 5](#step-5--add-the-secrets-the-host-needs)).
   `sops updatekeys` needs your operator key, so import your GPG private key on the
   installer first (`gpg --import …`, as in the darwin
   [post-install](#step-4--post-installation)). Commit and push.

   > `bootstrap-secrets` still works here if you've set up `pass` on the installer;
   > copy the `$KEYSDIR/extra/persist/etc/ssh/*` it produces into
   > `/mnt/persist/etc/ssh` instead of generating the key by hand.

4. **Install and reboot.** `nixos-install` builds locally (no remote builder) and
   installs into `/mnt`; passwords come from SOPS, so skip the root prompt:
   ```bash
   sudo nixos-install --flake .#<hostname> --no-root-passwd
   sudo reboot
   ```

Once it comes up, [subsequent deploys](#subsequent-deploys) deploy normally.

#### How `<hostname>` reaches the target machine

`bootstrap-deploy` uses the `<hostname>` argument **twice**:

- **Flake config** — `nixos-anywhere --flake .#<hostname>` selects
  `nixosConfigurations.<hostname>`.
- **SSH address** — it connects to `<username>@<hostname>` to run the install.

So `<hostname>` must *also resolve to the target's IP*. For a host already known
to the config this is wired up automatically — which is why `ssh nixos@<hostname>`
works from your workstation even though the fresh installer only knows itself as
`nixos` and grabbed its address over DHCP:

- **Name → IP:** the router's `lan` DNS zone answers for `dns = true` hosts —
  e.g. `<hostname>` resolves via `<hostname>.lan`, and the deploying machine's
  search list (`[<tailnet>, lan]`) makes the bare name work too. There is no
  `/etc/hosts` rendering to fall back on; both this record and the DHCP lease
  below come from the single registry entry in `lib/defaults.network.hosts`.
- **Machine holds that IP:** the router hands it out as a **static DHCP lease
  keyed by MAC** (same registry entry, e.g. `68:EC:…` →
  `10.0.0.63`). Because the lease is by MAC, the box gets its reserved address
  even while running the installer — it is not a random IP. Both the DNS
  record and the lease reach the router only via `just router-apply`, not a
  rebuild.

> **Use `nixos` as `<username>` during bootstrap.** That is the only account on
> the installer (it authorizes your owner SSH key — see
> [Step 3](#step-3--boot-the-target)). It is the SSH login for the install only,
> unrelated to the host's eventual accounts, which come from the flake.

**If the host isn't reserved** (not yet in `lib/defaults.network.hosts`), has
`dns = false`, or `just router-apply` hasn't run since it was added,
`<hostname>` won't resolve. Since the script reuses `<hostname>` for both the
flake attr *and* the SSH address, point the name at the real IP just for the
deploy — a throwaway alias is cleanest. The managed `~/.ssh/config` is a
read-only nix symlink, so add it to the writable **`~/.ssh/config.local`** it
`Include`s (see `modules/home/security/ssh`):

```
Host <hostname>
  HostName 10.0.0.63
  User nixos
```

so `.#<hostname>` still selects the right config while SSH goes to the actual IP.

**`server-vm`** never gets a registry-driven address — it carries
`dns = false, dhcp = false` permanently. See
[VM guests (QEMU on macOS)](#vm-guests-qemu-on-macos) for how to reach it
instead.

### Step 7 — Post-installation

#### FIDO2 auto-unlock (LUKS hosts, optional)

The system ships with `fido2-device=auto` in the LUKS settings. Enroll a token:

```bash
ssh <username>@<hostname>
systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device_name>
```

### Subsequent deploys

After the initial bootstrap, deploy changes normally:

```bash
just deploy <hostname>                 # remote deploy via deploy-rs
just deploy <hostname> --remote-build  # build on target
nh os switch                           # local rebuild (on the host itself)
```

### Retiring a host

Run both recipes without `--apply` first to see what they would touch, then
repeat with `--apply`:

```bash
just secrets-revoke <hostname>             # dry-run: secrets it can decrypt, its pass entries
just tailnet-revoke <hostname>             # dry-run: its tailnet devices
just secrets-revoke <hostname> --apply     # drop its &<hostname> recipient, rekey, remove infra/host/<hostname> from pass
just tailnet-revoke <hostname> --apply     # delete its tailnet devices
```

Then delete its `systems/<arch>/<hostname>/` and `homes/<arch>/*@<hostname>/`
directories. `bootstrap-secrets` reuses keys it finds in `pass`, so revoke a
name before reusing it for new hardware; otherwise the new machine inherits the
old host's key.

---

## VM guests (QEMU on macOS)

`server-vm` is a headless aarch64-linux guest — a home-server stand-in, not a
desktop — running under QEMU on the `workbook`.

It installs exactly like a physical host does — installer ISO plus
`nixos-anywhere` — following the [NixOS flow](#nixos) above with QEMU standing
in for hardware. Only the endpoints differ:

| Hardware | VM |
| --- | --- |
| `just iso minimal-x86_64 /dev/sdX` — write the stick | `just iso-build minimal-aarch64` |
| boot-menu → USB | `just vm-install server-vm` |
| `just bootstrap <host>` | identical, unchanged |
| pull the stick, reboot | quit the installer QEMU with **Ctrl-C** (headless: no window, no monitor), `launchctl kickstart` the agent |

### Step 1 — Install the guest

```bash
darwin-rebuild switch --flake .        # Linux builder, socket_vmnet, the guest agent
just iso-build minimal-aarch64         # build the installer ISO
just vm-install server-vm              # boot the guest from it (blank disks are created)
# from another terminal, once the guest has an address:
just bootstrap server-vm nixos "" --build-on-remote
# then quit the installer QEMU (Ctrl-C in its terminal) and start the guest normally:
launchctl kickstart -k gui/$(id -u)/org.nixos.qemu-server-vm
```

`just vm-install` runs QEMU in the **foreground** and does not return, so the
`just bootstrap` line belongs in a second terminal.

> **`server-vm` never resolves on its own.** It lives behind the host Mac's NAT
> (vmnet `shared` mode), so its registry entry is `dns = false, dhcp = false`
> permanently — see [Reaching the guest](#reaching-the-guest). `just bootstrap`
> reuses the hostname as the SSH address (`nixos@server-vm`); point it at the
> guest's vmnet address instead, the same `~/.ssh/config.local` alias described
> under
> [How `<hostname>` reaches the target machine](#how-hostname-reaches-the-target-machine):
>
> ```
> Host server-vm
>   HostName <vmnet-address>
>   User nixos
> ```
>
> The vmnet subnet is chosen by macOS and isn't pinned, so the address moves
> across restarts — find it with `arp -a | grep 52:54` on the workbook once the
> guest has talked to the network, or in its serial console log
> (`/tmp/qemu-server-vm.console.log`). Once the guest joins the tailnet
> ([Step 2](#step-2--join-the-tailnet)) reach it by name from there instead and
> drop the alias.

The empty `""` is the `disk_password` positional — the guest has no LUKS, but
the slot must be filled for `--build-on-remote` to land in `extra_opts` rather
than being read as the disk password.

`--build-on-remote` matters: the guest runs under `hvf` at native speed, so
building its closure inside the guest is far faster than building it on the
emulated Linux builder. Most of an aarch64 closure is substituted from the
binary cache rather than built at all.

The guest is headless — `/tmp/qemu-server-vm.console.log` is its console, and
the only place a failed boot is visible.

**SOPS comes first, inside this step.** `just bootstrap` runs
[Step 4 — Generate host keys & register with SOPS](#step-4--generate-host-keys--register-with-sops)
before the install, exactly as for a physical host: the host key is generated
*on your machine*, the age key derived from it is printed, the script **pauses**
for the `.sops.yaml` edit, and `nixos-anywhere` then ships the key to the guest
with `--extra-files`. The only VM-specific detail: `.sops.yaml` already carries
a `&server-vm` anchor, dereferenced by `*server-vm` in two creation rules, so
**replace its value in place** rather than appending a second entry — then
`sops updatekeys` both secrets files and press Enter.

#### Redoing an install

`just vm-install` never replaces an existing disk, and the guest's EDK2 varstore
remembers the boot entries a previous attempt wrote — so a second run over a
half-installed disk may boot that disk instead of the ISO. To start genuinely
clean, delete the guest's state first:

```bash
rm -f ~/.local/share/qemu/server-vm/{root,data}.qcow2 ~/.local/share/qemu/server-vm/vars.img
```

### Step 2 — Join the tailnet

If `nix-config.services.networking.tailscale.authKeyFromSecret` is on for this
host (see [Tailnet membership](#tailnet-membership)), it joins on its own at
first boot — nothing to do here. Otherwise join by hand, passing
`--advertise-tags` so the node is tagged from the start and never needs a
later re-auth to pick tags up:

```bash
ssh server-vm -- sudo tailscale up --ssh --advertise-tags=tag:server
```

Open the URL it prints. The vmnet address moves with the host Mac's network
and across restarts, so the tailnet is the only stable way in from elsewhere.

### Reaching the guest

The guest is `server-vm` everywhere — flake attribute, `networking.hostName`,
and the tailnet. It has no LAN identity: its registry entry
(`lib/defaults.network.hosts.server-vm`) is `dns = false, dhcp = false`
permanently, since it lives behind the host Mac's NAT and there is no LAN
address to publish for it.

Two ways in:

- **The tailnet**, once the guest has joined
  ([Step 2](#step-2--join-the-tailnet)) — `ssh server-vm` resolves through
  MagicDNS from anywhere, and is the only stable option.
- **From the workbook only**, over the vmnet subnet — find the guest's current
  address with `arp -a | grep 52:54` (macOS chooses the subnet; it is not
  pinned and moves across restarts).

`just deploy` already passes `--hostname server-vm`, which the tailnet name
satisfies, so `just deploy server-vm` works once the guest is enrolled. Before
that, or from the workbook directly, deploy to the vmnet address instead —
deploy-rs rejects `--hostname` twice, so call `deploy` directly:

```bash
deploy .#server-vm --hostname <vmnet-address> --skip-checks --remote-build
```

### Backups

The guest runs **no** backups: both the restic client and the restic REST server
are disabled on it. Backing a laptop guest up to its own disk would survive
neither the loss of the host Mac's disk — both qcow2 files live on it — nor a
reinstall, which rewrites the root disk the system itself sits on, so it would
buy only the appearance of coverage. Re-enable them once there is somewhere
off-box to send backups to.

### Recovering a wedged guest NIC

Symptom: the guest's console log (`/tmp/qemu-server-vm.console.log`) repeats
`NETDEV WATCHDOG: transmit queue 0 timed out`, the guest is missing from
`arp -a` on the host, and `tailscale status` shows `rx 0`. This happens when
the vmnet daemon's socket was not yet serving when the guest attached — the
guest's virtio NIC does not recover on its own, so restarting the guest alone
re-wedges it. Restart the daemon first, then the guest:

```bash
sudo launchctl kickstart -k system/org.nixos.socket-vmnet
launchctl kickstart -k gui/$(id -u)/org.nixos.qemu-server-vm
```

---

## macOS (nix-darwin)

**Local only** — there is no remote install path: macOS has no kexec/netboot
install phase, so macOS hosts (`workbook`) are **not** installed
with nixos-anywhere. You start from a stock macOS install and run the bootstrap
**on the Mac itself**. The
[`bootstrap-darwin`](../scripts/bootstrap/bootstrap-darwin.sh) script automates
every step that can be automated and pauses at the one manual gate (registering
the host with SOPS).

> **Apple Silicon only.** The script refuses to run on Intel: Homebrew's
> installer and Determinate's Nix installer have both stopped publishing
> `x86_64-darwin` builds, and nixpkgs drops that platform after 26.05. An Intel
> Mac has to be set up by hand.

### The macOS flow at a glance

```
1. Define the host in the flake     (systems/<arch>-darwin/…, homes/…, users)
2. On the Mac: fetch the config (curl+tar), enable Remote Login (for the SSH host key)
3. Run `just bootstrap-darwin <hostname>`
     ├─ Xcode Command Line Tools (git + toolchain)
     ├─ Homebrew                    (nix-darwin manages the Brewfile, not brew itself)
     ├─ Nix                         (Determinate installer, upstream Nix)
     ├─ Register host with SOPS      (pauses — add age key to .sops.yaml)
     ├─ Trust third-party brew taps  (akeylesslabs/tap, nikitabobko/tap)
     └─ First `darwin-rebuild switch`
4. Post-install                     (import GPG key, clone pass store)
```

### Step 1 — Define the Mac in the flake

Same model as NixOS, minus disks/hardware. Create
`systems/<arch>-darwin/<hostname>/default.nix` (Apple Silicon is
`aarch64-darwin`; Intel is `x86_64-darwin`) selecting a role and declaring the
**already-existing** macOS account as primary (nix-darwin configures the primary
account but does not create it — macOS/MDM owns account creation):

```nix
{ lib, namespace, ... }:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    roles.work = enabled;                       # common + macbook + dev + browsers
    users.<macos-login> = { primary = true; admin = true; };
    system.networking.knownNetworkServices = [ "Wi-Fi" ];
  };
  system.stateVersion = 5;
}
```

Add a home under `homes/<arch>-darwin/<login>@<hostname>/`. Confirm it evaluates:

```bash
just list-configs darwin       # <hostname> should appear
```

### Step 2 — Prepare the Mac

On the target Mac:

A stock macOS install has **no `git`** — `/usr/bin/git` is only a stub that
pops up the Xcode Command Line Tools installer. Fetch the flake with `curl` and
`tar`, which *are* part of the base system (the bootstrap installs the CLT, and
with it a real `git`, in step 3):

```bash
# Fetch the config somewhere stable — no git required
mkdir -p ~/.nix-config
curl -fsSL https://github.com/aleks-sidorenko/nix-config/archive/refs/heads/master.tar.gz \
  | tar -xz --strip-components=1 -C ~/.nix-config
cd ~/.nix-config

# The SOPS host key is macOS's SSH host key; Remote Login ensures it exists.
sudo systemsetup -setremotelogin on
```

### Step 3 — Run the bootstrap

`just` is itself installed by the flake, so on a fresh Mac call the script
directly:

```bash
./scripts/bootstrap/bootstrap-darwin.sh <hostname>   # e.g. … workbook
just bootstrap-darwin <hostname>                     # equivalent, once `just` exists
```

What it does, idempotently (safe to re-run):

1. **Xcode Command Line Tools** — installs them if missing (launches Apple's GUI
   installer the first time; re-run the command once it finishes).
2. **Homebrew** — installs it. nix-darwin's `homebrew` module manages the
   *Brewfile* declaratively but requires `brew` to already exist.
3. **Nix** — installs via the
   [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer)
   in **upstream mode** (vanilla Nix, no `--determinate` flag) — nix-darwin owns
   `nix.conf` and the daemon (`nix.enable = true`), the same model as every NixOS
   host.
4. **Register the host with SOPS** — derives the host's age key from
   `/etc/ssh/ssh_host_ed25519_key.pub` (via `ssh-to-age`), prints the line to add
   to `.sops.yaml`, and **pauses**. Add it under the anchors *and* the darwin
   (and home) creation rules, then `sops updatekeys modules/darwin/secrets.yaml`
   and `sops updatekeys modules/home/secrets.yaml`, then press Enter. This must
   happen before the first switch — activation decrypts the GitHub token. (Set
   `AUTO_APPROVE=1` to skip the pause once you've scripted the edit.)
5. **Trust third-party Homebrew taps** — recent Homebrew refuses formulae from
   untrusted taps (e.g. the `akeyless` error:
   *"Refusing to load formula akeylesslabs/tap/akeyless from untrusted tap"*).
   The script reads the taps declared in the flake and runs `brew trust` on each
   so the first `brew bundle` during activation doesn't abort.
6. **First switch** — `sudo nix run nix-darwin/master#darwin-rebuild -- switch
   --flake .#<hostname>`.

### Step 4 — Post-installation

- **GPG / pass.** The public identity is declarative
   (`identities/<name>/`), but the **private** GPG key is imported out-of-band,
   exactly as on NixOS. Import it, then the `pass` store just works:

   ```bash
   gpg --import <your-private-key.asc>          # or restore from a backup
   pass git clone <your-password-store-remote>  # if not already present
   ```

   > **`pass` comes from Nix, not Homebrew.** `pass` (with the `pass-otp`,
   > `pass-file`, `pass-import` extensions) is installed by the home `common`
   > role. **Do not `brew install pass`** — a stray brew `pass` on `PATH` can
   > shadow the Nix one. The Nix `pass` is the single source of truth.
   >
   > **Homebrew cleanup is `none`.** Homebrew 6 removed `brew bundle --cleanup`
   > ("no replacement"); any other value makes nix-darwin pass that now-fatal
   > switch and activation fails at the Homebrew step. `system.homebrew.cleanup`
   > therefore defaults to `"none"` — undeclared brews/casks are left in place
   > rather than auto-removed. Revisit once nix-darwin adapts to Homebrew 6.

- **Turn the extracted tarball into a git checkout.** The CLT installed in
   step 3 provide `git`, and `~/.nix-config` needs history for later pulls:

   ```bash
   cd ~/.nix-config
   git init -q -b master
   git remote add origin https://github.com/aleks-sidorenko/nix-config
   git fetch origin master
   git reset --hard FETCH_HEAD          # discards local edits — commit or stash them first
   git branch --set-upstream-to=origin/master master
   ```

- **Open a fresh shell** so fish and the Nix profile are active.

### Subsequent updates

Just like NixOS, from the Mac:

```bash
nh os switch                    # rebuild + switch (uses hostname)
darwin-rebuild switch --flake .#<hostname>   # equivalent, explicit
```

---

## Adding a user to an existing host

Hosts can carry several accounts (e.g. a host with `alexander` and `dima`).
Adding one is three small steps:

### 1. Declare the account

In the host config, add an entry under `nix-config.users` (see
[Users & Identities](architecture.md#users--identities)):

```nix
nix-config.users = {
  alexander = { primary = true; admin = true; };
  dima       = { profile = "child"; };   # no wheel; restricted home
};
```

Give the account a home at `homes/<arch>/<name>@<host>/` selecting the roles it
should get.

### 2. Add a password secret

Add a `user-<name>-password` secret to `modules/nixos/secrets.yaml` (same as
[Step 5](#step-5--add-the-secrets-the-host-needs)):

```bash
nix-shell -p mkpasswd --run 'mkpasswd -m SHA-512'
just secrets-edit nixos
```

### 3. (Optional) Give them key material

If the person needs GPG/SSH (git signing, SSH auth), add their public keys as a
colocated identity — one copy-paste (see
[identities/README.md](../identities/README.md)):

```bash
cp -r identities/alexander identities/<name>   # then replace the 3 files
```

`nix-config.security.identity.name` defaults to the account username, so the
folder name should match it (or set the option to reuse another identity, as
`oleksandrsy@workbook` reuses `alexander`). An account with **no** identity
folder (e.g. a child) simply gets no key material — nothing else to do. The
private GPG key is imported out-of-band on the machine, exactly as for the
primary user.

Then deploy the host to apply ([Step 6](#step-6--deploy) / `just deploy`).

---

## Tailnet membership

Every host with `roles.common` runs Tailscale; membership is not tied to any
other role. Joining is opt-in per host via
`nix-config.services.networking.tailscale.authKeyFromSecret` — off by default,
because the key it wires in doesn't exist until you create it (below). With it
off, both platforms join the way they always have: interactively, once, by
hand.

No host opts in today, and the two joined hosts were joined by hand — so the
manual flow below is the live one, and the automated flow is there for the
next host bootstrapped from scratch.

### One-time setup

Create a **separate** Tailscale OAuth client (admin console → Settings → OAuth
clients) scoped to `auth_keys` write access only. Do not widen the existing
client that `infra/tailnet` uses for `policy_file`: this secret is readable on
every host that opts in, so anything able to read `/run/secrets` there could
mint tagged nodes. A distinct client keeps that blast radius to node
registration.

An OAuth secret rather than a plain auth key because auth keys cap out at 90
days and would silently stop working on every host that reads one. Put the
client secret in **both** secrets files under the same name:

At <https://login.tailscale.com/admin/settings/oauth> → *Generate OAuth
client*: tick `auth_keys` → **Write**, leave every other scope unticked, and
select the tags the client may register nodes with — it can only issue keys
for tags it is associated with, and those must already exist in `tagOwners`
(`infra/tailnet` declares `tag:server`, `tag:desktop`, `tag:laptop`,
`tag:agent-host`, `tag:work`).

The secret is shown **once**, on creation, in the form `tskey-client-…`. Copy
it before closing the dialog; it cannot be retrieved later, only replaced.

```bash
just secrets-edit nixos    # add: system-tailscale-auth-key: tskey-client-…
just secrets-edit darwin   # add: system-tailscale-auth-key: tskey-client-…
```

Paste the secret **verbatim** — no `?preauthorized=true` suffix and no
quoting. The modules append that parameter themselves via upstream's
`authKeyParameters`, so a secret carrying it too would register with a
malformed key.

Nothing decrypts this secret until a host flips the opt-in below, so adding it
here is safe even before any host uses it.

### Per host

```nix
nix-config.services.networking.tailscale.authKeyFromSecret = true;
```

A NixOS host then joins non-interactively at first boot: the module registers
with `--advertise-tags` and `preauthorized = true` (both required for an
OAuth-issued key to register at all — see
[`authKeyParameters`](https://tailscale.com/kb/1215/oauth-clients#registering-new-nodes-using-oauth-credentials)).
A macOS host joins once, at the next activation, the same way.

Tags come from the roles a host enables (`server`, `desktop`, `laptop`,
`agent-host`, `work`) and are set only at this registration — tags are a
property of *joining*, not of the running config, so no later rebuild can add,
change, or remove them. Tagged devices do not expire, which is why an
always-on host must carry one. Confirm after joining:

    tailscale status --json | jq -r '.Self.Tags'

### Manual fallback

Without the opt-in — or before the secret exists — join by hand. Pass
`--advertise-tags` in the same `up` call that joins the node (this is how both
existing hosts joined): adding tags later via a second `tailscale up
--advertise-tags=...` forces a live session to re-authenticate, which
supplying them at join time avoids entirely.

```bash
sudo tailscale up --advertise-tags=tag:server               # e.g. server-vm
sudo tailscale up --advertise-tags=tag:work,tag:agent-host  # e.g. workbook
```

Pass only the tags that host's roles derive, and no other flags. In particular
do not add `--ssh` unless that host's config sets
`services.networking.tailscale.ssh` (today only hosts enabling `agent-host`
do): the module adds `--ssh` from config but never removes it, so a flag
supplied by hand here persists on the node and silently diverges from nix.

The managed Mac runs `tailscaled` from nixpkgs under launchd, where endpoint
security terminates processes by executable name. After any change to the
daemon, confirm it survives a reboot and an idle period:

    pgrep -l tailscaled && tailscale status

If it does not survive, that host has no tailnet identity: set
`services.networking.tailscale.enable = false` on it and reach the homelab
guest through the vmnet subnet from the host Mac instead.

## How hosts are addressed

Three namespaces, each with one owner:

| namespace | example | owner | scope |
| --- | --- | --- | --- |
| machine | `server-vm` | Tailscale MagicDNS | anywhere |
| LAN | `server.lan` | MikroTik DNS, from the registry | LAN only |
| service | `jellyfin.home.sidorenko.me` | Cloudflare, from `infra/dns` | anywhere |

`/etc/hosts` carries no host entries on any platform. Bare names resolve
through MagicDNS; the search list falls back to the router's `lan` zone, which
answers only on the LAN. Off the LAN a `.lan` name fails immediately rather
than resolving to an address with no route — that honest failure is the point.

The registry in `lib/defaults.network.hosts` is the single source of DHCP
reservations and `lan` records. It reaches hosts only through the router, so
changing it takes effect on `just router-apply`, not on a rebuild.

Service names are not registered anywhere — they're derived from
`${namespace}.system.networking.names`, a list option each service module
contributes to inside its own `mkIf cfg.enable` (nginx contributes every
vhost's `serverName`; a non-HTTP service like `minecraft-server` declares its
own). `infra/dns` reads that list across every host and writes one A record
per name, pointed at that host's tailnet address, so enabling a service needs
no DNS edit — only `just dns-apply`. Disabling one is the mirror image with a
lag: rebuilding takes the service offline immediately, but its record only
disappears on the next `dns-apply`. A record that still resolves for a
service that's already down is that lag, not a bug in the derivation.

The one exception is `home-assistant/inverter`, which names a physical
device rather than a service and stays on `hosts.lan`. The rule for any
future call site: if the name would appear in `system.networking.names`, use
`hosts.service`; otherwise `hosts.lan`.

---

## Web ingress

nginx is the only way into a server's web services — one virtual host per
service, each proxying to `127.0.0.1:<port>`. An unmatched `Host` header now
hits a catch-all vhost that returns `444` (connection closed, no response),
instead of falling through to whichever vhost nginx happened to sort first.

Apps bind loopback wherever their module exposes the option, so the proxy is
the only path in even from the LAN: `sonarr`, `radarr`, `prowlarr`
(`bindAddress`, default `127.0.0.1`), qBittorrent's WebUI
(`WebUI\Address=127.0.0.1`), `calibre` (`services.calibre-web.listen.ip`),
`home-assistant` and `zigbee2mqtt` (`bindAddress` / `frontend.host`), and
`restic-server` (`listenAddress`).

Two services still listen on every interface, and for them the firewall is
the only thing keeping them off the network — not the app itself:

- `jellyfin` has no bind-address option upstream at all, only `openFirewall`.
- `minidlna` deliberately isn't bound: DLNA clients fetch from the host's own
  address, so loopback would break them. minidlna can be pinned to one
  interface (`network_interface`) but not to an address, so there is no
  binding that keeps DLNA working and also hides it.

### Authentication at the edge

Loopback binding decides *who can reach* a service, not *who may use it*, and
the two came apart when the proxy became the only client: an app that exempts
local addresses from authentication exempts everyone once every request
arrives from `127.0.0.1`. So a vhost whose backend delegates authentication to
the proxy sets `requiresProxyAuth`, and nginx withholds it entirely until
`authFile` names an htpasswd file — publishing it unauthenticated is not one
of the options. A withheld vhost contributes no name to
`system.networking.names`, so no DNS record outlives the service it pointed
at.

One gate, at the edge, for everything whose own login is vestigial or absent:

- `sonarr`, `radarr`, `prowlarr` — `AuthenticationMethod=External` means they
  authenticate nobody, and they serve their API key at `/initialize.json`.
- `zigbee2mqtt` — its frontend has no login unless an auth token is set.
- `qbittorrent` — one shared account, and `LocalHostAuth=false` deliberately
  exempts loopback so the on-host clients that drive its API need no
  credentials. The cost is that its own logs and bans see the proxy.
- `minidlna` — no login at all. DLNA clients want it that way but reach port
  8200 directly, so guarding the vhost costs them nothing.

`jellyfin`, `calibre` and `home-assistant` keep their own authentication
instead: they have real user accounts, and their TV and phone clients cannot
answer a basic-auth challenge. Stacking a second prompt in front of them would
break the clients without adding a boundary the app doesn't already draw.

Set the file with `services.networking.nginx.authFromSecret = true`, which
points `authFile` at the SOPS secret `service-ingress-htpasswd`. It is opt-in
for the same reason the tailnet auth key is: sops-nix fails activation on a
secret that isn't in `modules/nixos/secrets.yaml` yet.

`restic-server` is the same shape and handles it itself: it runs with
`--no-auth` until `htpasswdFile` is set, and its vhost is withheld until then,
because a proxied `--no-auth` REST server is write and delete access to the
whole backup repository for every tailnet peer.

`80` is opened on the Tailscale interface only, not globally. 443 stays closed
and ungranted until a vhost terminates TLS — an open port with nothing behind
it hangs a client that upgraded the scheme, where a closed one fails at once.

Note that the firewall is belt and braces rather than the enforcing layer:
`tailscaled` inserts `-A ts-input -i tailscale0 -j ACCEPT` ahead of `nixos-fw`,
so traffic arriving over the tailnet is accepted before the firewall sees it.
Anything bound to all interfaces — `jellyfin`, `minidlna` — is therefore
reachable from any tailnet node whatever the port list says. Access *between*
tailnet nodes is controlled by the Tailscale ACL in `infra/tailnet`, not by the
firewall, which is also why a port is withheld there and not only here.

A `roles.server` host's firewall is otherwise closed: `system.networking`
leaves `networking.firewall.enable` at `mkDefault false` (so desktops stay
open by default), and `roles.server` sets it plainly to `true`. Past `22`,
what stays open on every interface is traffic that isn't HTTP or can't go
through a proxy:

| Port(s)     | Proto   | Why                                                                                                   |
| ----------- | ------- | ------------------------------------------------------------------------------------------------------ |
| 8200        | TCP     | minidlna: DLNA clients discover the server over SSDP, then fetch media straight from this port, never through a vhost |
| 1900        | UDP     | minidlna: SSDP discovery — minidlna never listens for it on TCP                                       |
| 17348       | TCP+UDP | qbittorrent: inbound peer connections don't go through a proxy; closing it would silently degrade torrenting to passive-only |
| 25565       | TCP+UDP | minecraft-server: not HTTP                                                                            |
| 41641       | UDP     | tailscale: direct (non-DERP) peer connections — opened by `roles.server`, not by a service module     |

These are the deliberate exceptions to "nginx is the only ingress," not
oversights — everything else a server used to open per-service is gone.

---

## Reference

### Disk layout with disko

Each system defines its disk layout in `systems/<arch>/<hostname>/disks.nix`.
The `root.device` must be set to the target's real disk before deploying — see
[Step 3 → Capture the target's disks & hardware](#capture-the-targets-disks--hardware).
During bootstrap, `nixos-anywhere` formats disks automatically. To run disko on
its own (e.g. re-format an existing host):

```bash
# Preview changes (dry-run)
just bootstrap-disk <hostname>

# Apply and format disks (DESTROYS ALL DATA)
just bootstrap-disk <hostname> --apply

# Then deploy to apply mount configuration
just deploy <hostname>
```

#### Manual formatting (single data disk)

For adding a data disk without touching the system disk:

```bash
# Format with btrfs
sudo mkfs.btrfs -f -L <disk-label> /dev/disk/by-id/<disk-id>

# Mount and create subvolumes
sudo mount /dev/disk/by-id/<disk-id> /mnt
sudo btrfs subvolume create /mnt/@<subvol>
sudo umount /mnt

# Rebuild to apply mount configuration
sudo nixos-rebuild switch --flake .#<hostname>
```

### What bootstrap does internally

1. **Checks prerequisites** — verifies SSH connectivity and required tools.
2. **Generates SSH host keys** (Ed25519) — or retrieves existing keys from `pass`
   at `infra/host/<hostname>/ssh`.
3. **Converts the SSH public key to age format** using `ssh-to-age`.
4. **Stores keys in `pass`** and pushes to git (for newly generated keys). With a
   disk password, also stores it at `infra/host/<hostname>/disk`.
5. **Prompts to update `.sops.yaml`** — add the new host's age key, then run
   `sops updatekeys` (skipped when reusing existing keys).
6. **Runs nixos-anywhere** — deploys NixOS with the prepared keys and optional
   disk encryption.

### `pass` layout

| Path | Contents |
|------|----------|
| `infra/host/<hostname>/ssh` | SSH host key pair (Ed25519) |
| `infra/host/<hostname>/disk` | LUKS disk password (only when encryption is used) |

### Command reference

| Command | Description |
|---------|-------------|
| `just bootstrap <host> [user] [disk_pw] [opts]` | Complete bootstrap (secrets + deploy) |
| `just bootstrap-secrets <host> [disk_pw]` | Generate SSH/age keys only |
| `just bootstrap-darwin <host>` | Bootstrap a macOS host (run on the Mac) |
| `just bootstrap-deploy <host> [user] [keysdir] [opts]` | Deploy using existing keys |
| `just bootstrap-disk <host>` | Preview disk formatting (dry-run) |
| `just bootstrap-disk <host> --apply` | Format disks with disko |
| `just bootstrap-targets` | List available bootstrap targets |
| `just secrets-revoke <host> [--apply]` | Retire a host's SOPS recipient and pass keys |
| `just tailnet-revoke <host> [--apply]` | Delete a host's tailnet devices |
| `just scripts-validate` | Shellcheck every script under `scripts/` |
| `just bootstrap-help` | Show detailed bootstrap help |

### nixos-anywhere options

Common options passed via `extra_opts`:

| Option | Description |
|--------|-------------|
| `--build-on-remote` | Build the system on the target host |
| `--phases <phases>` | Run specific phases: `kexec`, `disko`, `install`, `reboot` |
| `--debug` | Enable debug output |
| `--no-reboot` | Don't reboot after installation |

### Environment variables

| Variable | Description |
|----------|-------------|
| `KEYSDIR` | Keys directory (set by `bootstrap-secrets`, used by `bootstrap-deploy`) |
| `AUTO_APPROVE` | Skip the interactive SOPS update confirmation |
