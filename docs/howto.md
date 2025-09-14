# TODO - move everything to `justfile` & `scripts/`

# HOW TO
## Add new secret to SOPS
### User password for `$username`
* cd to nix config dir
    * `cd $FLAKE_DIR`
* Generate password hash
    * `mkpasswd -m SHA-512` 
    * `nix-shell -p mkpasswd --run 'mkpasswd -m SHA-512'`
* Add this hash to sops
    * `sops updatekeys ./modules/nixos/secrets.yaml` as `user-${username}-password`

## Bootstrap/Install remotely using `nixos-anywhere`
### Common
* Prerequisites
    * Target host/ip is assigned to `$hostname`
        * `export hostname=<your-host>`
    * Target user is assigned to `$username`:
        * `export username=<your-user>`

* Create user `$username` on target host
    * `sudo adduser $username`
    * `sudo usermod -aG sudo $username`
    * Make `$username` to have passwordless sudo 
        * `sudo visudo`
        * `$username ALL=(ALL) NOPASSWD: ALL`
* Configure ssh to target host
    * Copy your id `ssh-copy-id $username@$hostname`
    * `ssh $username$hostname` should work    

* Configure secrets 
    * `just bootstrap-secrets $hostname`
    * `export KEYSDIR=/tmp/tmp.xxxxxxxxx`

* Update secrets    
    *  Add the age key as a host entry for `$hostname` in the `$FLAKE_DIR/.sops.yaml` file.
    * Update the secrets with new key added
    `sops updatekeys ./modules/nixos/secrets.yaml`
    * Do this for every secret file
    
* Install using `nixos-anywhere`
    * `just bootstrap-deploy $hostname $username $KEYSDIR --build-on remote --phases disko`
    * `just bootstrap-deploy $hostname $username $KEYSDIR --build-on remote --phases install`

* Post-installation FIDO2 setup (optional)
    * After successful installation, you can set up a FIDO2 hardware token for automatic unlocking
    * SSH to the new system and run: `systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device_name>`
    * The system is already configured with `fido2-device=auto` in the LUKS settings

### Rasbperry PI 4 Model B

* Prerequisites
    * (Prepare RPI bootloader) [https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md#prepare-bootloader-on-raspberry-pi-5]
        * Update bootloader
        * Change boot order
* (Install)[#common]
* Post-install
    * `just bootstrap-rpi-firmware $hostname`

* Links
    * https://codeberg.org/kotatsuyaki/rpi4-usb-uefi-nixos-config
    * https://github.com/pftf/RPi4
    * https://github.com/Stunkymonkey/nixos/tree/master/machines/serverle
    * https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md    
    * https://github.com/NeilDarach/nix-config/blob/master/hosts/yellow
    * https://carlosvaz.com/posts/nixos-on-raspberry-pi-4-with-uefi-and-zfs/
    
    

### VM

VM is provisioned via Vagrant and has SSH enabled already with keys copied from GitHub.
```bash
vagrant up
vagrant ssh-config >> .ssh.config
```