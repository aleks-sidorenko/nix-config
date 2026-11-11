{
  config,
  inputs,
  lib,
  ...
}:
let
  c =
    (config.builders.nixos "x86_64-linux" {
      imports = [ config.flake.modules.nixos.impermanence ];
      nix-config.impermanence.files = [ "/x" ];
      boot.initrd.systemd.enable = true;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      system.stateVersion = "26.05";
    }).config;
  persisted = c.environment.persistence."/persist";
  persistRoot = config.constants.persistence.root;
  rollback = c.boot.initrd.systemd.services.impermanence-rollback-root or { };
in
{
  flake.modules.nixos.impermanence =
    { config, lib, ... }:
    let
      cfg = config.nix-config.impermanence;
      inherit (cfg) device;
      wipeScript = ''
        mkdir /tmp -p
        MNTPOINT=$(mktemp -d)
        (
          # Mount with retry mechanism (up to 3 attempts)
          if ! mountpoint -q "$MNTPOINT"; then
            for attempt in 1 2 3; do
              if mount -t btrfs -o subvol=/ /dev/disk/by-label/${device} "$MNTPOINT"; then
                echo "Successfully mounted on attempt $attempt"
                break
              fi
              if [ $attempt -lt 3 ]; then
                echo "Mount attempt $attempt failed, device may be busy. Retrying in 1 second..."
                sleep 1
              else
                echo "Mount failed after 3 attempts"
                exit 1
              fi
            done
          else
            echo "Mount point already mounted"
          fi
          trap 'umount $MNTPOINT 2>/dev/null || true; rm -rf $MNTPOINT' EXIT
          echo "Cleaning root subvolume"
          btrfs subvolume list -o "$MNTPOINT/@root" | cut -f9 -d ' ' |
          while read -r subvolume; do
            btrfs subvolume delete "$MNTPOINT/$subvolume"
          done && btrfs subvolume delete "$MNTPOINT/@root"
          echo "Restoring blank subvolume"
          btrfs subvolume snapshot "$MNTPOINT/@root-blank" "$MNTPOINT/@root"
        )
      '';
    in
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      options.nix-config.impermanence = {
        device = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "Label of the btrfs filesystem whose @root subvolume is rolled back on boot.";
        };
        directories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Directories to persist across reboots, added by the features that own them.";
        };
        files = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Files to persist across reboots, added by the features that own them.";
        };
      };

      config = {
        security.sudo.extraConfig = ''
          # rollback results in sudo lectures after each reboot
          Defaults lecture = never
        '';

        programs.fuse.userAllowOther = true;

        boot.initrd = {
          supportedFilesystems = [ "btrfs" ];
          systemd.services.impermanence-rollback-root = {
            description = "Rollback btrfs rootfs for impermanence";
            wantedBy = [ "initrd.target" ];
            requires = [ "dev-disk-by\\x2dlabel-${device}.device" ];
            after = [
              "dev-disk-by\\x2dlabel-${device}.device"
              "systemd-cryptsetup@${device}.service"
            ];
            before = [ "sysroot.mount" ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = wipeScript;
          };
        };

        environment.persistence.${persistRoot} = {
          hideMounts = true;
          directories = [
            "/.cache/nix/"
            "/var/cache/"
            "/var/db/sudo/"
            "/var/lib/"
          ]
          ++ cfg.directories;
          files = [ "/etc/machine-id" ] ++ cfg.files;
        };
      };
    };

  evalTests = {
    impermanence-rollback-unit = {
      expr = rollback ? script;
      expected = true;
    };
    impermanence-wipes-label = {
      expr = lib.hasInfix "/dev/disk/by-label/root" (rollback.script or "");
      expected = true;
    };
    impermanence-dirs = {
      expr = map (d: d.directory) persisted.directories;
      expected = [
        "/.cache/nix/"
        "/var/cache/"
        "/var/db/sudo/"
        "/var/lib/"
      ];
    };
    impermanence-files-append = {
      expr = map (f: f.file) persisted.files;
      expected = [
        "/etc/machine-id"
        "/x"
      ];
    };
  };
}
