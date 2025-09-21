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
  cfg = config.${namespace}.services.media.radarr;
in
{
  options.${namespace}.services.media.radarr = {
    enable = mkEnableOption "Enable Radarr movie management";

    user = mkOpt types.str "radarr" "User to run Radarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Radarr as";

    dataDir = mkOpt types.str "/var/lib/radarr" "Directory where Radarr stores its data";

    downloadDir = mkOpt types.str "/data/torrents/Movies" "Directory where downloads are stored";

    mediaDir = mkOpt types.str "/data/media/Movies" "Directory where movie files are stored";

    package = mkOpt types.package pkgs.radarr "Radarr package to use";

    webPort = mkOpt types.port defaults.ports.radarr.web "Port for the Radarr web interface";

  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
      createHome = true;
      description = "Radarr movie management user";
    };

    services.radarr = {
      enable = cfg.enable;
      package = cfg.package;
      user = cfg.user;
      group = cfg.group;
      settings.server.port = cfg.webPort;
      openFirewall = true;
      dataDir = cfg.dataDir;
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Radarr package to system packages
    environment.systemPackages = [ cfg.package ];

    # Persistence for important directories
    environment.persistence.${persistence.root config}.directories = [
      cfg.dataDir
      cfg.downloadDir
      cfg.mediaDir
    ];
  };
}
