{
  config,
  den,
  lib,
  ...
}:
let
  # Hosts whose install test boots this aspect.
  installTested = lib.filterAttrs (
    _: host:
    host.hasAspect den.aspects.security.nix-access-tokens
    && host.hasAspect den.aspects.hardware.qemu-guest
  ) den.hosts.x86_64-linux;

  includesToken = system: lib.hasInfix "!include" system.config.nix.extraOptions;
in
{
  den.aspects.security.nix-access-tokens.nixos =
    { config, lib, ... }:
    {
      sops.secrets."system-github-token" = { };

      # Anonymous GitHub API calls hit the rate limit during flake updates.
      nix.extraOptions = ''
        !include ${config.sops.secrets."system-github-token".path}
      '';

      # The install test's placeholder secret is no nix.conf line, and nix
      # refuses to run with it included.
      disko.tests.extraConfig.nix.extraOptions = lib.mkForce "";
    };

  evalTests.install-skips-access-token = {
    expr = lib.mapAttrs (name: host: {
      installed = includesToken (config.installedSystem host);
      real = includesToken config.flake.nixosConfigurations.${name};
    }) installTested;
    expected = lib.mapAttrs (_: _: {
      installed = false;
      real = true;
    }) installTested;
  };
}
