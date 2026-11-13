# deploy-rs nodes for the NixOS hosts that opt in with `deploy`.
{
  config,
  den,
  inputs,
  lib,
  ...
}:
let
  deployHosts = lib.concatMap (
    hosts: lib.filter (host: host.class == "nixos" && host.deploy != null) (lib.attrValues hosts)
  ) (lib.attrValues den.hosts);

  nodesOf =
    system:
    lib.listToAttrs (
      map (host: lib.nameValuePair host.name config.flake.deploy.nodes.${host.name}) (
        lib.filter (host: host.system == system) deployHosts
      )
    );
in
{
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.schema.host.options.deploy = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Address deploy-rs connects to; the host's name when null.";
          };
          sshUser = lib.mkOption {
            type = lib.types.str;
            description = "User deploy-rs logs in as.";
          };
        };
      }
    );
    default = null;
    description = "deploy-rs target; null keeps the host out of `flake.deploy.nodes`.";
  };

  flake.deploy.nodes = lib.listToAttrs (
    map (
      host:
      lib.nameValuePair host.name {
        inherit (host.deploy) sshUser;
        hostname = lib.defaultTo host.name host.deploy.hostname;
        profiles.system = {
          user = "root";
          # A password-protected sudo can't be answered over non-interactive
          # SSH; deploy-rs then prompts locally and pipes it in.
          interactiveSudo =
            config.flake.nixosConfigurations.${host.name}.config.security.sudo.wheelNeedsPassword;
          path =
            inputs.deploy-rs.lib.${host.system}.activate.nixos
              config.flake.nixosConfigurations.${host.name};
        };
      }
    ) deployHosts
  );

  perSystem =
    { system, ... }:
    {
      # deploy-rs only ships a lib for some systems; darwin has none for x86_64.
      checks = lib.optionalAttrs (inputs.deploy-rs.lib ? ${system}) (
        inputs.deploy-rs.lib.${system}.deployChecks { nodes = nodesOf system; }
      );
    };
}
