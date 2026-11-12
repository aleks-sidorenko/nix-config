{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.hosts = mkOption {
    type = types.lazyAttrsOf (
      types.submodule {
        options.deploy = mkOption {
          type = types.nullOr (
            types.submodule {
              options.sshUser = mkOption {
                type = types.str;
                description = "User deploy-rs connects as before activating as root.";
              };
            }
          );
          default = null;
          description = "deploy-rs settings. A host without them is left out of `deploy.nodes`.";
        };
      }
    );
  };

  config = {
    flake.deploy.nodes = lib.mapAttrs (name: host: {
      hostname = name;
      profiles.system = {
        user = "root";
        # No interactiveSudo: deployed hosts are system-server, whose wheel is
        # passwordless.
        inherit (host.deploy) sshUser;
        path = inputs.deploy-rs.lib.${host.system}.activate.nixos config.flake.nixosConfigurations.${name};
      };
    }) (lib.filterAttrs (_: host: host.deploy != null) config.hosts);

    perSystem =
      { system, ... }:
      let
        nodes = lib.filterAttrs (name: _: config.hosts.${name}.system == system) config.flake.deploy.nodes;
      in
      {
        checks = lib.optionalAttrs (nodes != { }) (
          inputs.deploy-rs.lib.${system}.deployChecks { inherit nodes; }
        );
      };
  };
}
