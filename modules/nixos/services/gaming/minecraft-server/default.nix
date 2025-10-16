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
  };
}


