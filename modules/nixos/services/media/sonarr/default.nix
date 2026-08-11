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
  cfg = config.${namespace}.services.media.sonarr;
  mediaRoot = dirOf cfg.mediaDir;

in
{
  options.${namespace}.services.media.sonarr = {
    enable = mkEnableOption "Enable Sonarr TV show management";

    user = mkOpt types.str "sonarr" "User to run Sonarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Sonarr as";

    dataDir = mkOpt types.str "/var/lib/sonarr" "Directory where Sonarr stores its data";

    downloadDir = mkOpt types.str "/data/torrents/Series" "Directory for downloads";

    mediaDir = mkOpt types.str "/data/media/Series" "Directory for media storage";

    package = mkOpt types.package pkgs.unstable.sonarr "Sonarr package to use";

    webPort = mkOpt types.port defaults.network.ports.sonarr.web "Port for the Sonarr web interface";

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
        description = "Log level for Sonarr";
      };

      bindAddress = mkOption {
        type = types.str;
        default = "*";
        description = "Bind address for Sonarr web interface";
      };

      instanceName = mkOption {
        type = types.str;
        default = "Sonarr";
        description = "Instance name for Sonarr";
      };
    };

  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services.networking.nginx = {
        virtualHosts = {
          sonarr = {
            serverName = hosts.local "sonarr";
            port = cfg.webPort;
          };
        };
      };
    };

    # SOPS secret for Sonarr API key
    sops.secrets."service-sonarr-api-key" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
    };

    # SOPS template for Sonarr configuration with secret substitution
    sops.templates."sonarr-config.xml" = {
      content = ''
        <Config>
          <BindAddress>${cfg.config.bindAddress}</BindAddress>
          <Port>${toString cfg.webPort}</Port>
          <ApiKey>${config.sops.placeholder."service-sonarr-api-key"}</ApiKey>
          <AuthenticationMethod>External</AuthenticationMethod>
          <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
          <LogLevel>${cfg.config.logLevel}</LogLevel>
          <AnalyticsEnabled>False</AnalyticsEnabled>
          <LogDbEnabled>False</LogDbEnabled>
          <InstanceName>${cfg.config.instanceName}</InstanceName>
          <!-- <SslPort>9898</SslPort> -->
          <!-- <EnableSsl>False</EnableSsl> -->
          <!-- <LaunchBrowser>True</LaunchBrowser> -->          
          <!-- <Branch>master</Branch> -->
          <!-- <SslCertPath></SslCertPath> -->
          <!-- <SslCertPassword></SslCertPassword> -->
          <!-- <UrlBase></UrlBase> -->
        </Config>
      '';
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
      createHome = true;
      description = "Sonarr TV show management user";
    };

    services.sonarr = {
      inherit (cfg) enable;
      inherit (cfg) package;
      inherit (cfg) user;
      inherit (cfg) group;
      openFirewall = true;
      inherit (cfg) dataDir;
    };

    # Add preStart script to copy SOPS-generated configuration
    systemd.services.sonarr = {
      preStart = ''
        echo "Copying Sonarr configuration XML with secrets..."        
        cp ${config.sops.templates."sonarr-config.xml".path} ${cfg.dataDir}/config.xml        
        echo "Sonarr configuration XML with secrets copied successfully"
      '';
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      # Create root directories
      "d ${mediaRoot} 0775 ${cfg.user} ${cfg.group} -"
      # Create category-specific directories
      "d ${cfg.mediaDir} 0775 ${cfg.user} ${cfg.group} -"
    ];

    # Add Sonarr package to system packages
    environment.systemPackages = [ cfg.package ];

  };
}
