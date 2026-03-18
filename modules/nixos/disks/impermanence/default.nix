# TODO - move to nixos/disks/
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.disks.impermanence;
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
  phase1Systemd = config.boot.initrd.systemd.enable;

in
{
  options.${namespace}.disks.impermanence = with types; {
    enable = mkBoolOpt false "Enable impermanence";
    root = mkStringOpt defaults.persistence.root "The root path for persistent storage";
    device = mkStringOpt defaults.disks.root "The root device name";
    directories = mkOption {
      type = types.listOf types.str;
      default = [
      ];
      description = "Directories to persist across reboots";
    };
    files = mkOption {
      type = types.listOf types.str;
      default = [
      ];
      description = "Files to persist across reboots";
    };
  };

  config = mkIf cfg.enable {
    security.sudo.extraConfig = ''
      # rollback results in sudo lectures after each reboot
      Defaults lecture = never
    '';

    programs.fuse.userAllowOther = true;

    boot.initrd = {
      supportedFilesystems = [ "btrfs" ];
      postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
      systemd.services.impermanence-rollback-root = lib.mkIf phase1Systemd {
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

    environment.persistence.${cfg.root} = {
      hideMounts = true;
      directories = [
        "/.cache/nix/"
        "/var/cache/"
        "/var/db/sudo/"
        "/var/lib/"

      ]
      ++ cfg.directories;
      files = [
        "/etc/machine-id"
      ]
      ++ cfg.files;
    };
  };
}
