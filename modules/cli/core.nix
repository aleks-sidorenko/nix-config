{ config, lib, ... }:
{
  # Enough to rescue, inspect or install a machine from a bare console.
  den.aspects.cli.core.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          dnsutils
          ethtool
          git
          htop
          jq
          parted
          pciutils
          ripgrep
          rsync
          smartmontools
          usbutils
          vim
          ;
      };
    };

  evalTests.base-vm-has-core-tools = {
    expr =
      lib.subtractLists
        (map lib.getName config.flake.nixosConfigurations.base-vm.config.environment.systemPackages)
        [
          "git"
          "vim"
          "rsync"
          "jq"
          "ripgrep"
          "htop"
          "parted"
          "smartmontools"
          "pciutils"
          "usbutils"
          "ethtool"
          "bind"
        ];
    expected = [ ];
  };
}
