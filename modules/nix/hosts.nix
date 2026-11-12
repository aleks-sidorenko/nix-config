{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  classOf = host: if lib.hasSuffix "-darwin" host.system then "darwin" else "nixos";
  ofClass = class: lib.filterAttrs (_: host: classOf host == class) config.hosts;
  build =
    name: host:
    config.builders.${classOf host} host.system {
      imports = [
        config.flake.modules.${classOf host}.${name}
        { networking.hostName = lib.mkDefault name; }
      ];
    };
  checksOf =
    system:
    lib.attrNames (lib.filterAttrs (n: _: lib.hasPrefix "host-" n) config.allSystems.${system}.checks);
in
{
  options.hosts = mkOption {
    type = types.lazyAttrsOf (
      types.submodule {
        options.system = mkOption {
          type = types.str;
          description = "Platform the host runs on, such as `x86_64-linux`. A `-darwin` one makes it a darwin host.";
        };
      }
    );
    default = { };
    description = "Machines by name. Each builds `flake.modules.<class>.<name>` into `flake.<class>Configurations.<name>` and a `host-<name>` check.";
  };

  config = {
    flake = {
      nixosConfigurations = lib.mapAttrs build (ofClass "nixos");
    }
    // lib.optionalAttrs (ofClass "darwin" != { }) {
      darwinConfigurations = lib.mapAttrs build (ofClass "darwin");
    };

    perSystem =
      { system, ... }:
      {
        checks = lib.mapAttrs' (
          name: host:
          lib.nameValuePair "host-${name}"
            config.flake."${classOf host}Configurations".${name}.config.system.build.toplevel
        ) (lib.filterAttrs (_: host: host.system == system) config.hosts);
      };

    evalTests.hosts-checked-on-their-system = {
      expr = map checksOf [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      expected = [
        [
          "host-installer"
          "host-server"
        ]
        [ ]
      ];
    };
  };
}
