{
  config,
  den,
  lib,
  ...
}:
let
  inherit (config.installTests) perTestedHost;

  includesToken = system: lib.hasInfix "!include" system.config.nix.extraOptions;
in
{
  den.aspects.security.nix-access-tokens = {
    os =
      { config, ... }:
      {
        sops.secrets."system-github-token" = { };

        # Anonymous GitHub API calls hit the rate limit during flake updates.
        nix.extraOptions = ''
          !include ${config.sops.secrets."system-github-token".path}
        '';
      };

    # The install test's placeholder secret is no nix.conf line, and nix
    # refuses to run with it included.
    nixos.installTest.extraConfig.nix.extraOptions = lib.mkForce "";
  };

  evalTests.install-skips-access-token =
    perTestedHost den.aspects.security.nix-access-tokens
      (name: host: {
        installed = includesToken (config.installTests.installedSystem host);
        real = includesToken config.flake.nixosConfigurations.${name};
      })
      {
        installed = false;
        real = true;
      };
}
