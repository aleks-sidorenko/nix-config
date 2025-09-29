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
  cfg = config.${namespace}.services.media.jellyfin;
  configDir = "${cfg.dataDir}/config";
  cacheDir = "${cfg.dataDir}/cache";
  logDir = "${cfg.dataDir}/log";
  dataDir = "${cfg.dataDir}/data";
in
{
  options.${namespace}.services.media.jellyfin = {
    enable = mkEnableOption "Enable Jellyfin media server";

    user = mkOpt types.str "jellyfin" "User to run Jellyfin as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Jellyfin as";

    dataDir = mkOpt types.str "/var/lib/jellyfin" "Data directory for Jellyfin";

    mediaDir = mkOpt types.str "/data/media" "Directory where media files are stored";

    package = mkOpt types.package pkgs.jellyfin "Jellyfin package to use";

    webPort =
      mkOpt types.port defaults.network.ports.jellyfin.web
        "Port for the Jellyfin web interface";

    discoveryPort =
      mkOpt types.port defaults.network.ports.jellyfin.discovery
        "Port for Jellyfin discovery";
  };

  config = mkIf cfg.enable {
    services.jellyfin = {
      enable = cfg.enable;
      package = cfg.package;
      user = cfg.user;
      group = cfg.group;
      openFirewall = true;
      logDir = logDir;
      cacheDir = cacheDir;
      dataDir = dataDir;
      configDir = configDir;
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${configDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cacheDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${logDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Jellyfin package to system packages
    environment.systemPackages = [ cfg.package ];

  };
}
