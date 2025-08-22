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

## Install remotely using `nixos-anywhere`
### Phisical or virtual host x86-64
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
* Genereate new ssh key for target host (on source host):
    * `KEYSDIR=$(mktemp -d)`
    * `cd $KEYSDIR`
    * `ssh-keygen -t ed25519 -f ssh_host_ed25519_key -C root@$hostname`
* Backup the ssh keys with `pass`
    * `pass file add $KEYSDIR/ssh_host_ed25519_key Infra/Host/$hostname/ssh`
    * `pass file add $KEYSDIR/ssh_host_ed25519_key.pub Infra/Host/$hostname/ssh`
    * `pass git push`
* Copy ssh key to target host
    * `scp -i ssh_host_ed25519_key* $username@$hostname:/etc/ssh/`
* Remove the keys from source host
    * `cd $FLAKE_DIR`
    * `rm -rf $KEYSDIR`
* Remove entries of target host from `.ssh/known_hosts`
    * `ssh-keygen -R $hostname`
    * `ssh $username@$hostname` - get updated target host key

* Generate age keys
    * `nix-shell -p ssh-to-age --run 'cat ssh_host_ed25519_key.pub | ssh-to-age'`
    *  Add the age key as a host entry in the `$FLAKE_DIR/.sops.yaml` file.
    * Update the secrets with new key added
    `sops updatekeys ./modules/nixos/secrets.yaml`
    * Do this for every secret file
    

* Install using `nixos-anywhere`
    * `nix run github:nix-community/nixos-anywhere -- --flake '.#$hostname' $username@$hostname`


### Rasbperry PI 4 Model B

* Prerequisites
* Links
    * https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md
    * https://github.com/nvmd/nixos-raspberrypi
    * https://github.com/NeilDarach/nix-config/blob/master/hosts/yellow
    * https://codeberg.org/kotatsuyaki/rpi4-usb-uefi-nixos-config
    * https://carlosvaz.com/posts/nixos-on-raspberry-pi-4-with-uefi-and-zfs/
    
    

