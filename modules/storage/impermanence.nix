{ inputs, lib, ... }:
let
  inherit (import ./_layout.nix) label root blank;

  merge = entries: {
    directories = lib.unique (lib.concatMap (e: e.directories or [ ]) entries);
    files = lib.unique (lib.concatMap (e: e.files or [ ]) entries);
  };

  rollback = ''
    mkdir /tmp -p
    MNTPOINT=$(mktemp -d)
    (
      # The device may still be settling right after it appears.
      for attempt in 1 2 3; do
        if mount -t btrfs -o subvol=/ /dev/disk/by-label/${label} "$MNTPOINT"; then
          break
        fi
        if [ $attempt -lt 3 ]; then
          echo "Mount attempt $attempt failed, retrying in 1 second..."
          sleep 1
        else
          echo "Mount failed after 3 attempts"
          exit 1
        fi
      done
      trap 'umount $MNTPOINT 2>/dev/null || true; rm -rf $MNTPOINT' EXIT

      # btrfs refuses to delete a subvolume that still holds others.
      btrfs subvolume list -o "$MNTPOINT/${root}" | cut -f9 -d ' ' |
      while read -r subvolume; do
        btrfs subvolume delete "$MNTPOINT/$subvolume"
      done && btrfs subvolume delete "$MNTPOINT/${root}"

      btrfs subvolume snapshot "$MNTPOINT/${blank}" "$MNTPOINT/${root}"
    )
  '';
in
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  den.aspects.storage.impermanence = {
    settings.root = lib.mkOption {
      type = lib.types.str;
      default = "/persist";
      description = "Where impermanent hosts keep state that survives a reboot.";
    };

    nixos =
      {
        config,
        host,
        options,
        persist,
        ...
      }:
      let
        persistRoot = host.settings.storage.impermanence.root;
        state = merge persist;
      in
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];

        config = {
          boot.initrd = {
            supportedFilesystems = [ "btrfs" ];
            systemd.services.impermanence-rollback-root =
              let
                device = "dev-disk-by\\x2dlabel-${label}.device";
              in
              {
                description = "Roll the btrfs root back to its blank snapshot";
                wantedBy = [ "initrd.target" ];
                requires = [ device ];
                after = [
                  device
                  "systemd-cryptsetup@${label}.service"
                ];
                before = [ "sysroot.mount" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = rollback;
              };
          };

          # Every boot would otherwise be the first sudo, with its lecture.
          security.sudo.extraConfig = ''
            Defaults lecture = never
          '';

          environment.persistence.${persistRoot} = {
            hideMounts = true;
            directories = [ "/var/lib/nixos" ] ++ state.directories;
            files = [ "/etc/machine-id" ] ++ state.files;
          };
        }
        # Secrets decrypt before the bind mounts exist, so read the key where it really lives.
        // lib.optionalAttrs (options ? sops) {
          sops.age.sshKeyPaths = map (key: persistRoot + key.path) (
            lib.filter (key: key.type == "ed25519") config.services.openssh.hostKeys
          );
        };
      };

    # A host's own `homeManager` content never reaches its users; this reads each user's pool.
    provides.to-users =
      { host, ... }:
      {
        homeManager =
          { persistHome, ... }:
          {
            home.persistence.${host.settings.storage.impermanence.root} = merge persistHome;
          };
      };
  };
}
