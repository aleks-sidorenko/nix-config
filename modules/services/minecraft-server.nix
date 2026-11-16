{ lib, ... }:
let
  user = "minecraft";
  group = "gaming";
  dataDir = "/var/lib/minecraft";
  worldName = "world";
  # Must match the server's Minecraft version (48 is 1.21.x).
  datapackFormat = 48;

  operatorType = lib.types.submodule {
    options = {
      uuid = lib.mkOption {
        type = lib.types.str;
        description = "Player UUID.";
      };
      name = lib.mkOption {
        type = lib.types.str;
        description = "Player Minecraft username.";
      };
      level = lib.mkOption {
        type = lib.types.ints.between 1 4;
        default = 4;
        description = "Operator level; 4 is full access.";
      };
      bypassesPlayerLimit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this operator can join a full server.";
      };
    };
  };

  # `toString` turns true into "1" and false into "".
  valueToString = value: if lib.isBool value then lib.boolToString value else toString value;
in
{
  den.aspects.services.minecraft-server = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("minecraft-server.service")'' ];

    settings = {
      ops = lib.mkOption {
        type = lib.types.listOf operatorType;
        default = [ ];
        description = "Server operators.";
      };
      whitelist = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Whitelisted players as username -> UUID; enables the whitelist when non-empty.";
      };
      serverProperties = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "server.properties key-value map.";
      };
      gamerules = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.oneOf [
            lib.types.str
            lib.types.bool
            lib.types.int
          ]
        );
        default = { };
        description = "Gamerules applied by a datapack on world load.";
      };
    };

    nixos =
      {
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.minecraft-server;

        opsJson = builtins.toJSON (
          map (op: {
            inherit (op)
              uuid
              name
              level
              bypassesPlayerLimit
              ;
          }) cfg.ops
        );

        datapack = pkgs.runCommand "nix-gamerules-datapack" { } ''
          mkdir -p $out/data/nixconfig/function $out/data/minecraft/tags/function
          cat > $out/pack.mcmeta <<'EOF'
          ${builtins.toJSON {
            pack = {
              pack_format = datapackFormat;
              description = "NixOS managed gamerules";
            };
          }}
          EOF
          cat > $out/data/nixconfig/function/gamerules.mcfunction <<'EOF'
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (rule: value: "gamerule ${rule} ${valueToString value}") cfg.gamerules
          )}
          EOF
          cat > $out/data/minecraft/tags/function/load.json <<'EOF'
          ${builtins.toJSON { values = [ "nixconfig:gamerules" ]; }}
          EOF
        '';
      in
      {
        # The server package is unfree.
        nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "minecraft-server";

        services.minecraft-server = {
          enable = true;
          eula = true;
          inherit dataDir;
          jvmOpts = "-Xms2G -Xmx2G";
          package = pkgs.unstable.minecraft-server;
          openFirewall = true;
          declarative = true;
          inherit (cfg) whitelist;
          serverProperties =
            cfg.serverProperties // lib.optionalAttrs (cfg.whitelist != { }) { white-list = "true"; };
        };

        # Overrides the upstream user, which has its own group and no fixed home.
        users.users.${user} = lib.mkForce {
          isSystemUser = true;
          inherit group;
          home = dataDir;
          createHome = true;
          description = "Minecraft server user";
        };
        users.groups.${group} = lib.mkDefault { };

        environment.etc."minecraft/ops.json" = lib.mkIf (cfg.ops != [ ]) {
          text = opsJson;
          mode = "0644";
        };

        systemd.services.minecraft-server = {
          serviceConfig = {
            User = user;
            Group = lib.mkForce group;
          };
          preStart = lib.mkIf (cfg.ops != [ ] || cfg.gamerules != { }) ''
            ${lib.optionalString (cfg.ops != [ ]) ''
              ln -sf /etc/minecraft/ops.json ${dataDir}/ops.json
            ''}
            ${lib.optionalString (cfg.gamerules != { }) ''
              mkdir -p ${dataDir}/${worldName}/datapacks
              rm -rf ${dataDir}/${worldName}/datapacks/nix-gamerules
              cp -r ${datapack} ${dataDir}/${worldName}/datapacks/nix-gamerules
              chmod -R u+w ${dataDir}/${worldName}/datapacks/nix-gamerules
            ''}
          '';
        };

        systemd.tmpfiles.rules = [ "d ${dataDir} 0755 ${user} ${group} -" ];

        # The install test VM is too small for the full heap.
        installTest.extraConfig.services.minecraft-server.jvmOpts = lib.mkForce "-Xms256M -Xmx512M";
      };
  };
}
