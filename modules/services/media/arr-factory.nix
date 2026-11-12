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
      # Media category key whose library dir this arr creates, if any.
      category ? null,
      # Whether the upstream service is given the user, group and data dir.
      upstreamPaths ? true,
    }:
    { config, pkgs, ... }:
    let
      secret = "service-${name}-api-key";
      template = "${name}-config.xml";
      port = config.constants.network.ports.${name}.web;
      package = pkgs.unstable.${name};
      inherit (config.constants.media) group categories;
    in
    {
      imports = with inputs.self.modules.nixos; [
        media-library
        nginx
      ];

      nix-config.nginx.virtualHosts.${name} = {
        inherit port;
        # AuthenticationMethod below is External: this app authenticates
        # nobody and serves its API key to whoever asks.
        requiresProxyAuth = true;
      };

      nix-config.media.users.${name} = {
        home = dataDir;
        description = userDescription;
        extraGroups = [ "users" ];
        secrets = [ secret ];
        templates.${template} = ''
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
      };

      # Not mkIf: prowlarr's upstream module has no user or group options, and
      # even a false mkIf needs the options it sets to exist.
      services.${name} = {
        enable = true;
        inherit package;
        settings.server.port = port;
        # nginx is the ingress; opening the port here would let clients bypass it.
        openFirewall = false;
      }
      // lib.optionalAttrs upstreamPaths {
        user = name;
        inherit group dataDir;
      };

      systemd.tmpfiles.rules =
        lib.optional upstreamPaths "d ${dataDir} 0755 ${name} ${group} -"
        ++ lib.optional (category != null) "d ${categories.${category}.mediaDir} 0775 ${name} ${group} -";

      systemd.services.${name}.preStart = ''
        echo "Copying ${title} configuration XML with secrets..."
        # cp keeps the source's mode; the SOPS template is read-only, so an explicit
        # mode is required or ${title} can't rewrite its own config next start
        install -m 0600 ${config.sops.templates.${template}.path} ${dataDir}/config.xml
        echo "${title} configuration XML with secrets copied successfully"
      '';

      environment.systemPackages = [ package ];
    };

  # Instances built here, not the callers, so a caller's arguments can change
  # without touching these tests. The names must be real arr services.
  c =
    (config.builders.testNixos {
      imports = [
        (arr {
          name = "sonarr";
          title = "Probe";
          userDescription = "Probe user";
          category = "series";
        })
        (arr {
          name = "prowlarr";
          title = "Probe";
          userDescription = "Probe user";
          dataDir = "/var/lib/private/prowlarr";
          upstreamPaths = false;
        })
      ];
    }).config;
  template = c.sops.templates."sonarr-config.xml".content;
  rulesOf = user: lib.filter (lib.hasInfix " ${user} ") c.systemd.tmpfiles.rules;
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
        inherit (c.users.users.sonarr) extraGroups description;
      };
      expected = {
        extraGroups = [ "users" ];
        description = "Probe user";
      };
    };
    # One data dir: the service reads config.xml from where preStart puts it.
    arr-upstream-paths = {
      expr = {
        inherit (c.services.sonarr) user group dataDir;
      };
      expected = {
        user = "sonarr";
        group = "media";
        dataDir = "/var/lib/sonarr";
      };
    };
    arr-ports = {
      expr = map (n: c.services.${n}.settings.server.port) [
        "sonarr"
        "prowlarr"
      ];
      expected = [
        8989
        9696
      ];
    };
    arr-tmpfiles = {
      expr = map rulesOf [
        "sonarr"
        "prowlarr"
      ];
      expected = [
        [
          "d /var/lib/sonarr 0755 sonarr media -"
          "d /data/media/Series 0775 sonarr media -"
        ]
        [ ]
      ];
    };
    # Without upstreamPaths the service keeps its own paths, and preStart
    # still writes to the dataDir given.
    arr-no-upstream-paths = {
      expr = [
        (c.services.prowlarr.dataDir != "/var/lib/private/prowlarr")
        (lib.hasInfix "/var/lib/private/prowlarr/config.xml" c.systemd.services.prowlarr.preStart)
      ];
      expected = [
        true
        true
      ];
    };
  };
}
