# Bootstrap & Installation

This guide covers installing NixOS on a new host using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and the bootstrap scripts in this repository.

## Prerequisites

- SSH access to target host with **passwordless sudo**
- [`pass`](https://www.passwordstore.org/) configured with file storage (for SSH key backup)
- Target host configuration exists in flake (`systems/<arch>/<hostname>/`)
- For disk encryption: a LUKS password
- Required tools on your local machine: `ssh-keygen`, `pass`, `nix`, `mktemp`

Verify SSH connectivity:
```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes <username>@<hostname> "sudo -n true"
```

## Build & Use the Installer ISO

For a fresh machine with no OS (or to boot into a NixOS live environment), build
the custom minimal installer ISO from this flake and write it to a USB stick.

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
`systems/x86_64-install-iso/minimal/`. Once booted and reachable over SSH,
continue with the bootstrap flow below.

## Quick Start

### Complete Bootstrap (Recommended)

```bash
just bootstrap <hostname> [username] [disk_password] [extra_opts...]
```

Examples:
```bash
just bootstrap myserver                                    # Current user, no encryption
just bootstrap myserver alexander                          # Specific user
just bootstrap myserver alexander MyPassword123            # With disk encryption
just bootstrap myserver alexander MyPassword123 --build-on-remote  # Build on target
```

### Two-Step Bootstrap (Advanced)

For more control, split secrets generation and deployment:

```bash
# Step 1: Generate SSH keys and age keys
just bootstrap-secrets <hostname> [disk_password]

# Step 2: Export the keys directory path from step 1 output
export KEYSDIR=/tmp/tmp.XXXXXXXX

# Step 3: Deploy
just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]
```

## What Bootstrap Does

1. **Checks prerequisites** - verifies SSH connectivity and required tools
2. **Generates SSH host keys** (Ed25519) - or retrieves existing keys from `pass` at `Infra/Host/<hostname>/ssh`
3. **Converts SSH public key to age format** using `ssh-to-age`
4. **Stores keys in `pass`** and pushes to git (for new keys)
5. **Prompts to update `.sops.yaml`** - add the new host's age key, then run `sops updatekeys`
6. **Runs nixos-anywhere** - deploys NixOS to the target with the prepared keys and optional disk encryption

The keys are placed in a temporary directory structure:
```
$KEYSDIR/extra/persist/etc/ssh/
├── ssh_host_ed25519_key
└── ssh_host_ed25519_key.pub
```

## Adding a New Host to SOPS

After bootstrap generates the age key for a new host:

1. Add the age key to `.sops.yaml`:
   ```yaml
   keys:
     - &hosts:
       - &myhost age1xxxx...xxxx   # Add this line
   ```

2. Add the host to the relevant creation rules:
   ```yaml
   creation_rules:
     - path_regex: modules/nixos/secrets.ya?ml$
       key_groups:
         - pgp:
             - *alexander
           age:
             - *myhost              # Add this line
   ```

3. Re-encrypt secrets with the new key:
   ```bash
   sops updatekeys modules/nixos/secrets.yaml
   sops updatekeys modules/home/secrets.yaml
   ```

## Adding a User

Hosts can carry several accounts (e.g. the shared `homebook` laptop with
`alexander` and `dima`). Adding one is three small steps:

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

Every account expects a `user-<name>-password` secret in
`modules/nixos/secrets.yaml`:

```bash
# Generate a password hash
nix-shell -p mkpasswd --run 'mkpasswd -m SHA-512'

# Edit secrets and add it as user-<name>-password (one per account)
just secrets-edit nixos
```

> Because `neededForUsers = true`, the **host itself** decrypts these at boot, so
> the host must already be a SOPS recipient (see "Adding a New Host to SOPS"
> above) and `sops updatekeys` must have run.

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

## Disk Formatting with Disko

Each system defines its disk layout in `systems/<arch>/<hostname>/disks.nix`. Use disko to format disks:

```bash
# Preview changes (dry-run)
just bootstrap-disk <hostname>

# Apply and format disks (DESTROYS ALL DATA)
just bootstrap-disk <hostname> --apply

# Then deploy to apply mount configuration
just deploy <hostname>
```

### Manual Formatting (Single Data Disk)

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

## Raspberry Pi 4

### Prerequisites

1. [Prepare the RPi4 bootloader](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md#prepare-bootloader-on-raspberry-pi-5): update bootloader and change boot order
2. Follow the [standard bootstrap process](#quick-start)

### Post-Install: Firmware

```bash
just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]
```

Examples:
```bash
just bootstrap-rpi-firmware myrpi                          # Defaults: current user, /mnt/boot, v1.42
just bootstrap-rpi-firmware myrpi pi /boot v1.50           # Custom settings
just bootstrap-rpi-firmware 192.168.1.100 root             # By IP
```

This downloads [RPi4 UEFI firmware](https://github.com/pftf/RPi4) and extracts it to the target directory.

### RPi4 Reference Links

- [kotatsuyaki/rpi4-usb-uefi-nixos-config](https://codeberg.org/kotatsuyaki/rpi4-usb-uefi-nixos-config)
- [pftf/RPi4](https://github.com/pftf/RPi4)
- [Stunkymonkey/nixos](https://github.com/Stunkymonkey/nixos/tree/master/machines/serverle)
- [fredrikaverpil/dotfiles](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md)
- [NixOS on RPi4 with UEFI and ZFS](https://carlosvaz.com/posts/nixos-on-raspberry-pi-4-with-uefi-and-zfs/)

## VM (Testing)

The VM configuration is provisioned via Vagrant with SSH keys from GitHub:

```bash
vagrant up
vagrant ssh-config >> .ssh.config
```

Then bootstrap as normal:
```bash
just bootstrap vm
```

## Post-Installation: FIDO2 Setup

After a successful installation with LUKS encryption, you can optionally set up a FIDO2 hardware token for automatic unlocking:

```bash
ssh <username>@<hostname>
systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device_name>
```

The system is pre-configured with `fido2-device=auto` in the LUKS settings.

## Bootstrap Command Reference

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

### nixos-anywhere Options

Common options passed via `extra_opts`:

| Option | Description |
|--------|-------------|
| `--build-on-remote` | Build the system on the target host |
| `--phases <phases>` | Run specific phases: `kexec`, `disko`, `install`, `reboot` |
| `--debug` | Enable debug output |
| `--no-reboot` | Don't reboot after installation |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `KEYSDIR` | Keys directory (set by bootstrap-secrets, used by bootstrap-deploy) |
| `AUTO_APPROVE` | Skip interactive SOPS update confirmation |
