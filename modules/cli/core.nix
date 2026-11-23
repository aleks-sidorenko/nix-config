{
  config,
  den,
  lib,
  ...
}:
let
  # Enough to rescue, inspect or install a machine from a bare console.
  # htop is unconfigured here on purpose: `cli.htop` configures the user's.
  tools =
    pkgs:
    builtins.attrValues {
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
in
{
  den.aspects.cli.core.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = tools pkgs;
    };

  evalTests.cli-core-tools-installed = config.perHost (config.hostsWith den.aspects.cli.core) (
    name: _:
    let
      system = config.flake.nixosConfigurations.${name};
    in
    lib.subtractLists (map lib.getName system.config.environment.systemPackages) (
      map lib.getName (tools system.pkgs)
    )
  ) [ ];
}
