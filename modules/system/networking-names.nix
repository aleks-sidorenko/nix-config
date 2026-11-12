{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.networking-names).config;
in
{
  # Only the option, so a service can publish a name without taking on the
  # rest of the network setup.
  flake.modules.nixos.networking-names =
    { lib, ... }:
    {
      options.nix-config.networking.names = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "DNS names this host answers to, contributed by the services that own them.";
      };
    };

  evalTests.networking-names-default = {
    expr = c.nix-config.networking.names;
    expected = [ ];
  };
}
