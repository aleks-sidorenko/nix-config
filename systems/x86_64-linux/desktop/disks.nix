{
 # Move to reusable module
  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = "/dev/sdc";
        name = "root";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              label = "boot";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                extraArgs = [ "-nESP" ];
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            encryped = {
              size = "100%";
              label = "root_encrypted";
              content = {
                type = "luks";
                name = "root";
                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-f"  # force overwrite
                    "-L root" # label we use later on in postCreateHook
                  ];
                  # Create snapshot regardless of if impermanence is enabled
                  # This way we can enable impermanence later on if we want
                  postCreateHook = ''
                      mkdir /tmp -p
                      MNTPOINT=$(mktemp -d)
                      mount -t btrfs /dev/disk/by-label/root "$MNTPOINT"
                      trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
                      btrfs subvolume snapshot -r $MNTPOINT/@root $MNTPOINT/@root-blank
                      '';
                  subvolumes = {
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };

                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [
                        "subvol=log"
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@swap" = {
                      mountpoint = "/swap";
                      mountOptions = [
                        "noatime"
                      ];
                      swap.swapfile.size = "36G";
                    };
                  };
                };
              };
            };
          };
        };
      };
      data = {
        type = "disk";
        device = "/dev/nvme0n1";
        name = "data";
        content = {
          type = "gpt";
          partitions = {
            encryped = {
              size = "100%";
              label = "data_encrypted";
              content = {
                type = "luks";
                name = "data";
                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-f"
                    "-L data"
                  ]; # force overwrite + label
                  subvolumes = {
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [
                        "subvol=home"
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = [
                        "compress=zstd"
                        "noatime"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;

}
