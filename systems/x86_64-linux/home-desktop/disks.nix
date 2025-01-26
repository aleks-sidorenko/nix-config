{
  
  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = "/dev/sdd";
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
                extraArgs = ["-n ESP"];
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
                  # https://github.com/hmajid2301/dotfiles/blob/a0b511c79b11d9b4afe2a5e2b7eedb2af23e288f/systems/x86_64-linux/framework/disks.nix#L36
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L root"]; # force overwrite + label
                  postCreateHook = ''
										MNTPOINT=$(mktemp -d)
										mount "/dev/mapper/root" "$MNTPOINT" -o subvol=/
										trap 'umount $MNTPOINT; rm -rf $MNTPOINT' EXIT
										btrfs subvolume snapshot -r $MNTPOINT/root $MNTPOINT/root-blank
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
                      mountOptions = ["subvol=log" "compress=zstd" "noatime"];
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
      persist = {
        type = "disk";
        device = "/dev/nvme0n1";
        name = "persist";
        content = {
          type = "gpt";
          partitions = {
            encryped = {
              size = "100%";
              label = "persist_encrypted";
              content = {
                type = "luks";
                name = "persist";                
                settings = {
                  allowDiscards = true;
                  # https://github.com/hmajid2301/dotfiles/blob/a0b511c79b11d9b4afe2a5e2b7eedb2af23e288f/systems/x86_64-linux/framework/disks.nix#L36
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L persist"]; # force overwrite + label
                  subvolumes = {
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