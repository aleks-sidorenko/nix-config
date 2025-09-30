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
  cfg = config.${namespace}.services.media.prowlarr;
  userName = lib.${namespace}.userName config;

in
{
  options.${namespace}.services.media.prowlarr = {
    enable = mkEnableOption "Enable Prowlarr indexer manager";

    user = mkOpt types.str "prowlarr" "User to run Prowlarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Prowlarr as";

    dataDir = mkOpt types.str "/var/lib/private/prowlarr" "Directory where Prowlarr stores its data";

    package = mkOpt types.package pkgs.prowlarr "Prowlarr package to use";

    webPort =
      mkOpt types.port defaults.network.ports.prowlarr.web
        "Port for the Prowlarr web interface";

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
        description = "Log level for Prowlarr";
      };

      bindAddress = mkOption {
        type = types.str;
        default = "*";
        description = "Bind address for Prowlarr web interface";
      };

      instanceName = mkOption {
        type = types.str;
        default = "Prowlarr";
        description = "Instance name for Prowlarr";
      };
    };

  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services.networking.nginx = {        
        virtualHosts = {
          prowlarr = {
            serverName = "prowlarr.local";
            port = cfg.webPort;
          };
        };
      };
    };

    # SOPS secret for Prowlarr API key
    # Note: You need to manually add 'service-prowlarr-api-key' to modules/nixos/secrets.yaml
    # using: sops modules/nixos/secrets.yaml
    sops.secrets."service-prowlarr-api-key" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    # SOPS template for Prowlarr configuration with secret substitution
    sops.templates."prowlarr-config.xml" = {
      content = ''
        <Config>
          <BindAddress>${cfg.config.bindAddress}</BindAddress>
          <Port>${toString cfg.webPort}</Port>
          <ApiKey>${config.sops.placeholder."service-prowlarr-api-key"}</ApiKey>
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
      group = cfg.group;
      mode = "0400";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
      createHome = true;
      description = "Prowlarr indexer manager user";
    };

    services.prowlarr = {
      enable = cfg.enable;
      package = cfg.package;
      settings.server.port = cfg.webPort;
      openFirewall = true;
      # TODO: enable once https://github.com/NixOS/nixpkgs/issues/445983 is fixed
      # dataDir = cfg.dataDir;
    };

    systemd.services.prowlarr = {
      preStart = ''
        echo "Copying Prowlarr configuration XML with secrets..."        
        cp ${config.sops.templates."prowlarr-config.xml".path} ${cfg.dataDir}/config.xml        
        echo "Prowlarr configuration XML with secrets copied successfully"
      '';
    };

    # Add Prowlarr package to system packages
    environment.systemPackages = [ cfg.package ];

  };
}
