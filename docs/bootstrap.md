# Bootstrap & Installation

This guide walks through installing NixOS on a **new host** from start to finish,
using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and the
bootstrap scripts in this repository.

> **Bootstrapping a Mac?** macOS can't be installed with nixos-anywhere — it uses
> a different, run-on-the-machine flow. Jump to
> [macOS (nix-darwin) bootstrap](#macos-nix-darwin-bootstrap).

Follow the steps **in order** — each one depends on the previous. In particular,
the host must become a SOPS recipient *before* you deploy, because the system
decrypts user passwords and other secrets at boot (see
[Step 4](#step-4--generate-host-keys--register-with-sops)).

## The flow at a glance

```
1. Define the host in the flake        (systems/…, homes/…, users)
2. Prepare your local machine          (tools: pass, nix, ssh, nixos-anywhere)
3. Boot the target                     (installer ISO — or Vagrant for a VM — verify SSH, capture disks + hardware)
4. Generate host keys → register SOPS   (bootstrap-secrets, .sops.yaml, updatekeys)
5. Add the secrets the host needs      (user-<name>-password)
6. Deploy                              (bootstrap / bootstrap-deploy + disko)
7. Post-install                        (FIDO2, RPi firmware, …)
```

Steps 4–6 can be run as a single `just bootstrap` command (it pauses at the SOPS
step for you), or split apart for more control. Both paths are covered below.

---

## Step 1 — Define the host in the flake

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
> modules / microcode vendor. Start them from a similar host (or the `homebook`
> placeholders, which are marked `# TODO` / `REPLACE-ME`) and **finalize them
> after booting the target** in
> [Step 3 → Capture the target's disks & hardware](#capture-the-targets-disks--hardware).
> Leaving `REPLACE-ME` in `disks.nix` makes disko fail during deploy.

Example `default.nix` (from the shared family laptop `homebook`):

```nix
{ lib, namespace, ... }:
with lib;
with lib.${namespace};
{
  imports = [ ./hardware.nix ./disks.nix ];

  ${namespace} = {
    roles.homebook = enabled;

    # All accounts are declared here, including the primary.
    users = {
      alexander = { primary = true; admin = true; };  # profile defaults to "adult"
      dima       = { profile = "child"; };            # no wheel; restricted home
    };
  };

  system.stateVersion = "25.05";  # do not change after install
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

## Step 2 — Prepare your local machine

Bootstrap runs from your machine and pushes to the target. You need:

- SSH access to the target with **passwordless sudo**
- [`pass`](https://www.passwordstore.org/) configured with file storage — used to
  back up the host's SSH keys and disk password
- These tools on `PATH`: `ssh-keygen`, `pass`, `nix`, `mktemp`, `nixos-anywhere`
- For disk encryption: a LUKS password you choose now

## Step 3 — Boot the target

The target must be reachable over SSH before bootstrap can run.

### Fresh machine with no OS — build the installer ISO

Build the custom minimal installer ISO from this flake and write it to a USB stick:

```bash
# Identify the target USB device first (double-check — writing is destructive!)
lsblk

# Build the ISO and write it to the USB stick in one step (replace sdX)
just iso /dev/sdX

# …or run the steps separately:
just iso-build            # -> ./result/iso/nixos-minimal-*.iso
just iso-write /dev/sdX   # dd the built image to the device
```

Boot the target from the USB stick. The **local console autologins** as
**`nixos`** (passwordless — the stock installer default). **SSH is key-based**
(password auth is disabled): the throwaway `nixos` user has no identity of its
own, so the ssh module authorizes the **owner identity** (`lib` `defaults.user`)
— i.e. you connect as `nixos@<host>` with your own private key, no password. The
ISO is defined by the `minimal` role (SSH, networking, locale, fish) in
`systems/x86_64-install-iso/minimal/`.

> **Raspberry Pi 4:** first
> [prepare the bootloader](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md#prepare-bootloader-on-raspberry-pi-5)
> (update firmware, change boot order), then continue here. Firmware is installed
> post-deploy — see [Raspberry Pi 4](#raspberry-pi-4).

> **VM (testing):** provision with [Vagrant](https://www.vagrantup.com/) instead
> of building/booting an ISO. The VirtualBox provider is enabled by the `desktop`
> role, so run this **on the desktop** (from `systems/x86_64-linux/vm/`).
>
> The VM is wired like a physical host: `lib/defaults` reserves `vm = 10.0.0.64`,
> `infra/router/hosts.nix` gives it a static DHCP lease keyed by MAC
> (`08:00:27:00:00:64`), and the Vagrantfile bridges onto the LAN (`eno1`) with
> that MAC. **One-time prerequisites:** apply the router config (`just router-*`)
> so the lease exists, and `nh os switch` on the machines you deploy from so their
> `/etc/hosts` learns `vm → 10.0.0.64`.
>
> ```bash
> vagrant up
> ```
>
> **Install phase (over Vagrant's NAT).** Vagrant's passwordless SSH runs on its
> NAT adapter with the box's `vagrant` key, so bootstrap connects that way — not
> over the bridge yet. Add a throwaway alias and bootstrap as `vagrant`:
> ```bash
> vagrant ssh-config >> ~/.ssh/config.local   # Host vm → 127.0.0.1:<nat-port>, User vagrant
> just bootstrap vm vagrant
> ```
> The VM is **not** exempt from SOPS: with the default `alexander` account its
> `user-alexander-password` is `neededForUsers`, so the VM must be a SOPS
> recipient (Steps 4–5) to boot with a working login. The ISO build, FIDO2, and
> RPi steps do **not** apply.
>
> **After install, switch firmware to UEFI.** The Vagrant box boots legacy BIOS
> (fine for the install), but the installed NixOS only has a UEFI bootloader
> (systemd-boot + ESP), so the post-install reboot lands in BIOS with *"cannot
> read from boot medium"*. Run **`just vm-uefi`** once — it power-cycles the VM
> into EFI firmware, and systemd-boot's removable fallback
> (`\EFI\BOOT\BOOTX64.EFI`) then loads NixOS.
>
> **Steady state.** Delete the throwaway `~/.ssh/config.local` alias — the
> installed VM is now a first-class host on the LAN, so `ssh vm` and
> `just deploy vm` reach it as your user on port 22 via `/etc/hosts` (`10.0.0.64`),
> exactly like `desktop` or `server`.

### Verify connectivity

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes <username>@<hostname> "sudo -n true"
```

### Capture the target's disks & hardware

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

## Step 4 — Generate host keys & register with SOPS

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

### Register the host in `.sops.yaml`

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
       - &desktop age1kjlpt0mu072vqk8txgkfs7yvehkvk0kysawyqvy96zcqmf49wgkq3hlsag
       - &myhost  age1xxxx...xxxx        # <- add your new host
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
             - *desktop
             - *myhost                    # <- add your new host
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

## Step 5 — Add the secrets the host needs

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

## Step 6 — Deploy

With keys registered and secrets in place, deploy with `nixos-anywhere`.

### One command (recommended)

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
just bootstrap vm vagrant                                  # testing VM (Vagrant, connect as vagrant)
```

### Two-step (if you already ran `bootstrap-secrets`)

Reuse the keys directory printed by Step 4:

```fish
set -x KEYSDIR /tmp/tmp.XXXXXXXX        # path from bootstrap-secrets output
just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]
```

`nixos-anywhere` formats the disks (via disko), copies the SSH host key into
`/persist/etc/ssh`, installs NixOS, and reboots. If `disk.key` is present it is
passed through as `--disk-encryption-keys`.

### How `<hostname>` reaches the target machine

`bootstrap-deploy` uses the `<hostname>` argument **twice**:

- **Flake config** — `nixos-anywhere --flake .#<hostname>` selects
  `nixosConfigurations.<hostname>`.
- **SSH address** — it connects to `<username>@<hostname>` to run the install.

So `<hostname>` must *also resolve to the target's IP*. For a host already known
to the config this is wired up automatically — which is why `ssh nixos@homebook`
works from your workstation even though the fresh installer only knows itself as
`nixos` and grabbed its address over DHCP:

- **Name → IP:** your nix-config workstation's `/etc/hosts` is populated from
  `defaults.network.hosts` (`lib/defaults`) by the networking module —
  e.g. `homebook → 10.0.0.63`. (This is local resolution, independent of router
  DNS: `homebook` has `dns = false` in `infra/router/hosts.nix`, so it is *not*
  served by the router, but `/etc/hosts` still maps it.)
- **Machine holds that IP:** the router hands it out as a **static DHCP lease
  keyed by MAC** (`infra/router/hosts.nix`, e.g. homebook's `68:EC:…` →
  `10.0.0.63`). Because the lease is by MAC, the box gets its reserved address
  even while running the installer — it is not a random IP.

> **Use `nixos` as `<username>` during bootstrap.** That is the only account on
> the installer (it authorizes your owner SSH key — see
> [Step 3](#step-3--boot-the-target)). It is the SSH login for the install only,
> unrelated to the host's eventual accounts, which come from the flake.

**If the host isn't reserved** (not yet in `infra/router/hosts.nix` /
`defaults.network.hosts`), or you deploy from a machine without those static
hosts, `<hostname>` won't resolve. Since the script reuses `<hostname>` for both
the flake attr *and* the SSH address, point the name at the real IP just for the
deploy — a throwaway alias is cleanest. The managed `~/.ssh/config` is a
read-only nix symlink, so add it to the writable **`~/.ssh/config.local`** it
`Include`s (see `modules/home/security/ssh`):

```
Host homebook
  HostName 10.0.0.63
  User nixos
```

so `.#homebook` still selects the right config while SSH goes to the actual IP
(a temporary `/etc/hosts` line works too).

The **VM** has a reserved lease (`vm → 10.0.0.64`) just like a physical host, so
its installed system resolves normally. Only its *install phase* needs the
throwaway-alias trick, because Vagrant's bootstrap SSH runs over NAT with the
box's key — see the VM note in [Step 3](#step-3--boot-the-target).

## Step 7 — Post-installation

### FIDO2 auto-unlock (LUKS hosts, optional)

The system ships with `fido2-device=auto` in the LUKS settings. Enroll a token:

```bash
ssh <username>@<hostname>
systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device_name>
```

### Raspberry Pi 4 firmware

```bash
just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]
```

Examples:
```bash
just bootstrap-rpi-firmware myrpi                          # defaults: current user, /mnt/boot, v1.42
just bootstrap-rpi-firmware myrpi pi /boot v1.50           # custom settings
just bootstrap-rpi-firmware 192.168.1.100 root             # by IP
```

This downloads [RPi4 UEFI firmware](https://github.com/pftf/RPi4) and extracts it
to the target directory.

### Subsequent updates

After the initial bootstrap, deploy changes normally:

```bash
just deploy <hostname>                 # remote deploy via deploy-rs
just deploy <hostname> --remote-build  # build on target
nh os switch                           # local rebuild (on the host itself)
```

---

## macOS (nix-darwin) bootstrap

macOS hosts (`workbook`, `tempbook`) are **not** installed with nixos-anywhere —
there is no kexec/netboot install phase for macOS. Instead you start from a
stock macOS install and run the bootstrap **on the Mac itself**. The
[`bootstrap-darwin`](../scripts/bootstrap/bootstrap-darwin.sh) script automates
every step that can be automated and pauses at the one manual gate (registering
the host with SOPS).

### The flow at a glance

```
1. Define the host in the flake     (systems/<arch>-darwin/…, homes/…, users)
2. On the Mac: clone the config, enable Remote Login (for the SSH host key)
3. Run `just bootstrap-darwin <hostname>`
     ├─ Xcode Command Line Tools (git + toolchain)
     ├─ Homebrew                    (nix-darwin manages the Brewfile, not brew itself)
     ├─ Nix                         (Determinate installer, upstream Nix)
     ├─ Register host with SOPS      (pauses — add age key to .sops.yaml)
     ├─ Trust third-party brew taps  (akeylesslabs/tap, nikitabobko/tap)
     └─ First `darwin-rebuild switch`
4. Post-install                     (import GPG key, clone pass store)
```

### Step 1 — Define the host in the flake

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

```bash
# Clone the config somewhere stable
git clone https://github.com/aleks-sidorenko/nix-config ~/.nix-config
cd ~/.nix-config

# The SOPS host key is macOS's SSH host key; Remote Login ensures it exists.
sudo systemsetup -setremotelogin on
```

### Step 3 — Run the bootstrap

```bash
just bootstrap-darwin <hostname>          # e.g. just bootstrap-darwin workbook
```

What it does, idempotently (safe to re-run):

1. **Xcode Command Line Tools** — installs them if missing (launches Apple's GUI
   installer the first time; re-run the command once it finishes).
2. **Homebrew** — installs it. nix-darwin's `homebrew` module manages the
   *Brewfile* declaratively but requires `brew` to already exist.
3. **Nix** — installs via the
   [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer)
   in **upstream mode** (vanilla Nix, no `--determinate` flag). See
   [Nix on macOS: daemon vs Determinate](#nix-on-macos-daemon-vs-determinate).
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
   > role. **Do not `brew install pass`** — Homebrew's `cleanup = "zap"` would
   > later uninstall any manually-added formula, and a stray brew `pass` on
   > `PATH` can shadow the Nix one. The Nix `pass` is the single source of truth.

- **Open a fresh shell** so fish and the Nix profile are active.

### Subsequent updates

Just like NixOS, from the Mac:

```bash
nh os switch                    # rebuild + switch (uses hostname)
darwin-rebuild switch --flake .#<hostname>   # equivalent, explicit
```

### Nix on macOS: daemon vs Determinate

Issue [#204](https://github.com/aleks-sidorenko/nix-config/issues/204) asks which
Nix to run on macOS. There are two realistic choices:

| | **Upstream Nix, daemon managed by nix-darwin** *(current)* | **Determinate Nix** |
|---|---|---|
| Install | Determinate *installer* in upstream mode, or official installer | Determinate installer with `--determinate` |
| `nix.enable` | `true` — nix-darwin owns `nix.conf` + the daemon | must be `false` — `determinate-nixd` owns them |
| macOS major upgrades | daemon/`_nixbld` users can break; re-run the installer to repair | handled automatically by `determinate-nixd` |
| Config model | **one model across the whole fleet** (NixOS hosts use the same daemon) | macOS diverges from the Linux hosts |
| Extras | none | flakes-on by default, `determinate-nixd login`, lazy-trees |
| Lock-in | none (vanilla Nix) | vendor daemon layer |

**Recommendation: stay on upstream Nix with the daemon managed by nix-darwin.**
This repo already manages `nix.conf` and the daemon declaratively through
`nix.enable = true` and shares that exact model with every NixOS host — one
mental model, no vendor layer, and switching to Determinate would mean
`nix.enable = false` plus adopting the `determinate-nix-darwin` module. The main
thing Determinate buys you — surviving macOS *major* upgrades that wipe the
daemon — is a rare, recoverable event (re-run the installer). Using the
**Determinate _installer_ in upstream mode** (what `bootstrap-darwin` does) gives
the best of both: a far more robust macOS install/uninstall than the legacy
official installer, while still plain upstream Nix that nix-darwin manages.
Revisit Determinate only if macOS-upgrade breakage becomes a recurring pain.

---

## Adding a user to an existing host

Hosts can carry several accounts (e.g. `homebook` has `alexander` and `dima`).
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
| `just bootstrap-rpi-firmware <host> [user] [dir] [ver]` | Install RPi4 firmware |
| `just bootstrap-targets` | List available bootstrap targets |
| `just bootstrap-validate` | Shellcheck bootstrap scripts |
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

### Raspberry Pi 4 reference links

- [kotatsuyaki/rpi4-usb-uefi-nixos-config](https://codeberg.org/kotatsuyaki/rpi4-usb-uefi-nixos-config)
- [pftf/RPi4](https://github.com/pftf/RPi4)
- [Stunkymonkey/nixos](https://github.com/Stunkymonkey/nixos/tree/master/machines/serverle)
- [fredrikaverpil/dotfiles](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md)
- [NixOS on RPi4 with UEFI and ZFS](https://carlosvaz.com/posts/nixos-on-raspberry-pi-4-with-uefi-and-zfs/)
