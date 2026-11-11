{
  config,
  inputs,
  lib,
  ...
}:
let
  # radarr, sonarr and prowlarr share this shape: an API key from SOPS baked
  # into config.xml, a system user in the media group, and nginx in front.
  arr =
    {
      name,
      title,
      userDescription,
      dataDir ? "/var/lib/${name}",
    }:
    { config, pkgs, ... }:
    let
      secret = "service-${name}-api-key";
      template = "${name}-config.xml";
      port = config.services.${name}.settings.server.port;
      package = pkgs.unstable.${name};
      media = config.nix-config.media.group;
    in
    {
      imports = [ inputs.self.modules.nixos.media-library ];

      nix-config.nginx.virtualHosts.${name} = {
        inherit port;
        # AuthenticationMethod below is External: this app authenticates
        # nobody and serves its API key to whoever asks.
        requiresProxyAuth = true;
      };

      sops.secrets.${secret} = {
        owner = name;
        group = media;
        mode = "0400";
      };

      sops.templates.${template} = {
        content = ''
          <Config>
            <BindAddress>127.0.0.1</BindAddress>
            <Port>${toString port}</Port>
            <ApiKey>${config.sops.placeholder.${secret}}</ApiKey>
            <AuthenticationMethod>External</AuthenticationMethod>
            <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
            <LogLevel>info</LogLevel>
            <AnalyticsEnabled>False</AnalyticsEnabled>
            <LogDbEnabled>False</LogDbEnabled>
            <InstanceName>${title}</InstanceName>
            <!-- <SslPort>9898</SslPort> -->
            <!-- <EnableSsl>False</EnableSsl> -->
            <!-- <LaunchBrowser>True</LaunchBrowser> -->          
            <!-- <Branch>master</Branch> -->
            <!-- <SslCertPath></SslCertPath> -->
            <!-- <SslCertPassword></SslCertPassword> -->
            <!-- <UrlBase></UrlBase> -->
          </Config>
        '';
        owner = name;
        group = media;
        mode = "0400";
      };

      users.users.${name} = {
        isSystemUser = true;
        group = lib.mkForce media;
        extraGroups = [ "users" ];
        home = dataDir;
        createHome = true;
        description = userDescription;
      };

      services.${name} = {
        enable = true;
        inherit package;
        # nginx is the ingress; opening the port here would let clients bypass it.
        openFirewall = false;
      };

      systemd.services.${name}.preStart = ''
        echo "Copying ${title} configuration XML with secrets..."
        # cp keeps the source's mode; the SOPS template is read-only, so an explicit
        # mode is required or ${title} can't rewrite its own config next start
        install -m 0600 ${config.sops.templates.${template}.path} ${dataDir}/config.xml
        echo "${title} configuration XML with secrets copied successfully"
      '';

      environment.systemPackages = [ package ];
    };
  sonarr = config.factory.arr {
    name = "sonarr";
    title = "Sonarr";
    userDescription = "Sonarr TV show management user";
  };
  host =
    module:
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        module
        sops
        nginx
      ];
    }).config;
  # As the sonarr feature sets it.
  upstream = {
    services.sonarr = {
      user = "sonarr";
      group = "media";
      dataDir = "/var/lib/sonarr";
    };
  };
  c = host {
    imports = [
      sonarr
      upstream
    ];
  };
  template = c.sops.templates."sonarr-config.xml".content;
  private = host {
    imports = [
      (config.factory.arr {
        name = "sonarr";
        title = "Sonarr";
        userDescription = "x";
        dataDir = "/var/lib/private/x";
      })
      upstream
      { services.sonarr.dataDir = lib.mkForce "/var/lib/private/x"; }
    ];
  };
in
{
  factory = { inherit arr; };

  evalTests = {
    arr-secret = {
      expr = {
        inherit (c.sops.secrets."service-sonarr-api-key") owner group mode;
      };
      expected = {
        owner = "sonarr";
        group = "media";
        mode = "0400";
      };
    };
    arr-template-bind = {
      expr = lib.hasInfix "<BindAddress>127.0.0.1</BindAddress>" template;
      expected = true;
    };
    arr-template-port = {
      expr = lib.hasInfix "<Port>8989</Port>" template;
      expected = true;
    };
    arr-prestart-install = {
      expr =
        lib.hasInfix "install -m 0600" c.systemd.services.sonarr.preStart
        && lib.hasInfix "/var/lib/sonarr/config.xml" c.systemd.services.sonarr.preStart;
      expected = true;
    };
    arr-vhost-auth = {
      expr = c.nix-config.nginx.virtualHosts.sonarr.requiresProxyAuth;
      expected = true;
    };
    arr-firewall-closed = {
      expr = c.services.sonarr.openFirewall;
      expected = false;
    };
    arr-user = {
      expr = {
        inherit (c.users.users.sonarr)
          isSystemUser
          group
          extraGroups
          home
          createHome
          description
          ;
      };
      expected = {
        isSystemUser = true;
        group = "media";
        extraGroups = [ "users" ];
        home = "/var/lib/sonarr";
        createHome = true;
        description = "Sonarr TV show management user";
      };
    };
    arr-data-dir = {
      expr = lib.hasInfix "/var/lib/private/x/config.xml" private.systemd.services.sonarr.preStart;
      expected = true;
    };
  };
}
