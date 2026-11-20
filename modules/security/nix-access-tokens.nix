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
    includes = [ den.aspects.security.sops ];

    os =
      { config, ... }:
      {
        sops.secrets."system-github-token" = { };

        # Anonymous GitHub API calls hit the rate limit during flake updates.
        nix.extraOptions = ''
          !include ${config.sops.secrets."system-github-token".path}
        '';
      };

    # The client reads nix.conf as the user here, and `!include` silently
    # skips a file it cannot read; the secret's group is the users' one.
    darwin.sops.secrets."system-github-token".mode = "0440";

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
