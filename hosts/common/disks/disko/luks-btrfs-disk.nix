# NOTE: ... is needed because dikso passes diskoFile
{
  lib,
  pkgs,
  disk,
  swapSize,
  ...
}:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk;
        name = "main";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
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
              content = {
                type = "luks";
                name = "encrypted_${disko.devices.main.name}";
                # passwordFile = "/tmp/disko-password";
                askPassword = true;
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
                  extraArgs = [ "-f" "-L ${disko.devices.main.name}"]; # force overwrite + label
                  postCreateHook = ''
										MNTPOINT=$(mktemp -d)
										mount "/dev/mapper/${disko.devices.main.content.partitions.encrypted.name}" "$MNTPOINT" -o subvol=/
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
                    "@persist" = {
                      mountpoint = "/persist";
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
                    "@swap" = {
                      mountpoint = "/swap";
                      mountOptions = [
                        "noatime"
                      ];
                      swap.swapfile.size = "${swapSize}G";
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

  environment.systemPackages = [
    pkgs.yubikey-manager # For luks fido2 enrollment before full install
  ];
}