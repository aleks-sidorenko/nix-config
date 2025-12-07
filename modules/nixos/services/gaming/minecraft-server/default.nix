{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.gaming.minecraft-server;
  dataDir = cfg.dataDir;

  # Type for operator entries
  operatorType = types.submodule {
    options = {
      uuid = mkOption {
        type = types.str;
        description = "Player UUID (get from mcuuid.net)";
        example = "550e8400-e29b-41d4-a716-446655440000";
      };
      name = mkOption {
        type = types.str;
        description = "Player Minecraft username";
      };
      level = mkOption {
        type = types.ints.between 1 4;
        default = 4;
        description = "Operator level (1-4). Level 4 is full access.";
      };
      bypassesPlayerLimit = mkOption {
        type = types.bool;
        default = true;
        description = "Whether this operator can join even when the server is full";
      };
    };
  };

  # Generate ops.json content
  opsJson = builtins.toJSON (map (op: {
    inherit (op) uuid name level bypassesPlayerLimit;
  }) cfg.ops);
in
{
  options.${namespace}.services.gaming.minecraft-server = {
    enable = mkEnableOption "Enable Minecraft Java Edition server";

    user = mkOpt types.str "minecraft" "User to run the Minecraft server as";
    
    group = mkOpt types.str config.${namespace}.services.gaming.group "Group to run the Minecraft server as";

    port = mkOpt types.port defaults.network.ports.minecraft.server "Port for the Minecraft server";

    dataDir = mkOpt types.str "/var/lib/minecraft" "Data directory for world and config";

    eula = mkBoolOpt true "Accept Minecraft EULA (required to run).";

    jvmOpts = mkOpt types.str "-Xms2G -Xmx2G" "JVM options for the server process";

    # For vanilla server; overrideable to e.g. pkgs.paper, pkgs.fabric-server, etc.
    package = mkOpt types.package pkgs.minecraft-server "Minecraft server package to use";

    ops = mkOption {
      type = types.listOf operatorType;
      default = [ ];
      description = "List of server operators";
      example = literalExpression ''
        [
          {
            uuid = "550e8400-e29b-41d4-a716-446655440000";
            name = "PlayerName";
            level = 4;
            bypassesPlayerLimit = true;
          }
        ]
      '';
    };

    serverProperties = mkOption {
      type = types.attrsOf types.str;
      default = {
        motd = "Nix Minecraft Server";
        online-mode = "true";
        difficulty = "normal";
        gamemode = "survival";
        enable-command-block = "false";
        spawn-monsters = "true";
        view-distance = "10";
        simulation-distance = "10";
        white-list = "false";
        server-port = toString cfg.port;
        server-ip = "";
        max-players = "5";
      };
      description = "server.properties key-value map";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.eula == true;
        message = "You must accept the Minecraft EULA by setting eula = true";
      }
    ];

    services.minecraft-server = {
      enable = true;
      eula = cfg.eula;
      dataDir = dataDir;
      jvmOpts = cfg.jvmOpts;
      package = cfg.package;
      openFirewall = true;
      declarative = true;
      serverProperties = cfg.serverProperties;
    };

    # Ensure runtime user/group exist and bind the service to them
    users.users.${cfg.user} = mkForce {
      isSystemUser = true;
      group = cfg.group;
      home = dataDir;
      createHome = true;
      description = "Minecraft server user";
    };

    users.groups.${cfg.group} = mkDefault { };

    systemd.services.minecraft-server.serviceConfig = {
      User = cfg.user;
      Group = mkForce cfg.group;
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"      
    ];

    # Write ops.json if operators are defined
    environment.etc."minecraft/ops.json" = mkIf (cfg.ops != [ ]) {
      text = opsJson;
      mode = "0644";
    };

    # Symlink ops.json to dataDir before server starts
    systemd.services.minecraft-server.preStart = mkIf (cfg.ops != [ ]) ''
      ln -sf /etc/minecraft/ops.json ${cfg.dataDir}/ops.json
    '';
  };
}


