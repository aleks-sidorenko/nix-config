# Bootstrap & Installation

This guide walks through installing NixOS on a **new host** from start to finish,
using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and the
bootstrap scripts in this repository.

Follow the steps **in order** — each one depends on the previous. In particular,
the host must become a SOPS recipient *before* you deploy, because the system
decrypts user passwords and other secrets at boot (see
[Step 4](#step-4--generate-host-keys--register-with-sops)).

## The flow at a glance

```
1. Define the host in the flake        (systems/…, homes/…, users)
2. Prepare your local machine          (tools: pass, nix, ssh, nixos-anywhere)
3. Boot the target                     (installer ISO, verify SSH + sudo)
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

Boot the target from the USB stick and log in as **`nixos`** / **`nixos`**. The
ISO is defined by the `minimal` role (SSH, networking, locale, fish) in
`systems/x86_64-install-iso/minimal/`.

> **Raspberry Pi 4:** first
> [prepare the bootloader](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md#prepare-bootloader-on-raspberry-pi-5)
> (update firmware, change boot order), then continue here. Firmware is installed
> post-deploy — see [Raspberry Pi 4](#raspberry-pi-4).

> **VM (testing):** provision with Vagrant instead of an ISO:
> ```bash
> vagrant up
> vagrant ssh-config >> .ssh.config
> ```

### Verify connectivity

```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes <username>@<hostname> "sudo -n true"
```

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
`export KEYSDIR=…` from the recipe output — see [Step 6](#step-6--deploy)):

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

Examples:
```bash
just bootstrap myserver                                    # current user, no encryption
just bootstrap myserver alexander                          # specific user
just bootstrap myserver alexander MyPassword123            # with disk encryption
just bootstrap myserver alexander MyPassword123 --build-on-remote  # build on target
```

### Two-step (if you already ran `bootstrap-secrets`)

Reuse the keys directory printed by Step 4:

```bash
export KEYSDIR=/tmp/tmp.XXXXXXXX        # path from bootstrap-secrets output
just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]
```

`nixos-anywhere` formats the disks (via disko), copies the SSH host key into
`/persist/etc/ssh`, installs NixOS, and reboots. If `disk.key` is present it is
passed through as `--disk-encryption-keys`.

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
