{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.system.impermanence;
  device = config.${namespace}.system.boot.device;

  wipeScript = ''
    mkdir /tmp -p
    MNTPOINT=$(mktemp -d)
    (
      mount -t btrfs -o subvol=/ /dev/disk/by-label/${device} "$MNTPOINT"
      trap 'umount "$MNTPOINT"' EXIT

      echo "Creating needed directories"
      mkdir -p "$MNTPOINT"/persist/var/{log,lib/{nixos,systemd}}
      if [ -e "$MNTPOINT/persist/dont-wipe" ]; then
        echo "Skipping wipe"
      else
        echo "Cleaning root subvolume"
        btrfs subvolume list -o "$MNTPOINT/root" | cut -f9 -d ' ' |
        while read -r subvolume; do
          btrfs subvolume delete "$MNTPOINT/$subvolume"
        done && btrfs subvolume delete "$MNTPOINT/root"

        echo "Restoring blank subvolume"
        btrfs subvolume snapshot "$MNTPOINT/root-blank" "$MNTPOINT/root"
      fi
    )
  '';
  phase1Systemd = config.boot.initrd.systemd.enable;

in {
  options.${namespace}.system.impermanence = with types; {
    enable = mkBoolOpt false "Enable impermanence";    
  };

  config = mkIf cfg.enable {
    security.sudo.extraConfig = ''
      # rollback results in sudo lectures after each reboot
      Defaults lecture = never
    '';

    programs.fuse.userAllowOther = true;

    boot.initrd = {            
      supportedFilesystems = ["btrfs"];
      postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
      systemd.services.restore-root = lib.mkIf phase1Systemd {
        description = "Rollback btrfs rootfs";
        wantedBy = ["initrd.target"];
        requires = ["dev-disk-by\\x2dlabel-${device}.device"];
        after = [
          "dev-disk-by\\x2dlabel-${device}.device"
          "systemd-cryptsetup@${device}.service"
        ];
        before = ["sysroot.mount"];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = wipeScript;
      };
    };

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [        
        "/.cache/nix/"
        "/etc/NetworkManager/system-connections"        
        "/var/db/sudo/"
        "/var/lib/"
        "/var/lib/systemd"
        "/var/lib/nixos"
        "/var/log"  
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
