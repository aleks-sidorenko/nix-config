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
  userName = lib.${namespace}.userName config;
  mediaRoot = dirOf cfg.mediaPath;
  downloadRoot = dirOf cfg.downloadPath;

in
{
  options.${namespace}.services.media.radarr = {
    enable = mkEnableOption "Enable Radarr movie management";

    user = mkOpt types.str "radarr" "User to run Radarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Radarr as";

    dataDir = mkOpt types.str "/var/lib/radarr" "Directory where Radarr stores its data";

    downloadPath = mkOpt types.str "/data/torrents/Movies" "Directory for downloads";

    mediaPath = mkOpt types.str "/data/media/Movies" "Directory for media storage";

    package = mkOpt types.package pkgs.radarr "Radarr package to use";

    webPort = mkOpt types.port defaults.network.ports.radarr.web "Port for the Radarr web interface";

    config = {
      logLevel = mkOption {
        type = types.enum [
          "info"
          "debug"
          "trace"
          "warn"
          "error"
        ];
        default = "info";
        description = "Log level for Radarr";
      };

      bindAddress = mkOption {
        type = types.str;
        default = "*";
        description = "Bind address for Radarr web interface";
      };

      instanceName = mkOption {
        type = types.str;
        default = "Radarr";
        description = "Instance name for Radarr";
      };
    };

  };

  config = mkIf cfg.enable {
    # SOPS secret for Radarr API key
    sops.secrets."service-radarr-api-key" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    # SOPS template for Radarr configuration with secret substitution
    sops.templates."radarr-config.xml" = {
      content = ''
        <Config>
          <BindAddress>${cfg.config.bindAddress}</BindAddress>
          <Port>${toString cfg.webPort}</Port>
          <ApiKey>${config.sops.placeholder."service-radarr-api-key"}</ApiKey>
          <AuthenticationMethod>External</AuthenticationMethod>
          <LogLevel>${cfg.config.logLevel}</LogLevel>
          <AnalyticsEnabled>False</AnalyticsEnabled>
          <LogDbEnabled>False</LogDbEnabled>
          <InstanceName>${cfg.config.instanceName}</InstanceName>
          <!-- <SslPort>9898</SslPort> -->
          <!-- <EnableSsl>False</EnableSsl> -->
          <!-- <LaunchBrowser>True</LaunchBrowser> -->
          <!-- <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired> -->
          <!-- <Branch>master</Branch> -->
          <!-- <SslCertPath></SslCertPath> -->
          <!-- <SslCertPassword></SslCertPassword> -->
          <!-- <UrlBase></UrlBase> -->
        </Config>
      '';
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

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

    # Add preStart script to copy SOPS-generated configuration
    systemd.services.radarr = {
      preStart = ''
        echo "Copying Radarr configuration XML with secrets..."        
        cp ${config.sops.templates."radarr-config.xml".path} ${cfg.dataDir}/config.xml        
        echo "Radarr configuration XML with secrets copied successfully"
      '';
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      # Create root directories
      "d ${mediaRoot} 0755 ${cfg.user} ${cfg.group} -"
      # Create category-specific directories
      "d ${cfg.mediaPath} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Radarr package to system packages
    environment.systemPackages = [ cfg.package ];

  };
}
