let
  # An API key secret and a config.xml rendered from it, installed before each
  # start, the service user, and the package on PATH.
  common =
    {
      lib,
      name,
      title,
      port,
      dataDir,
      group,
    }:
    config:
    let
      secret = "service-${name}-api-key";
      template = "${name}-config.xml";
    in
    {
      sops.secrets.${secret} = {
        owner = name;
        inherit group;
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
          </Config>
        '';
        owner = name;
        inherit group;
        mode = "0400";
      };

      users.users.${name} = {
        isSystemUser = true;
        group = lib.mkForce group;
        extraGroups = [ "users" ];
        home = dataDir;
        createHome = true;
        description = "${title} user";
      };

      # cp keeps the source's mode; the template is read-only, so an explicit mode
      # is required or the app can't rewrite its own config next start.
      systemd.services.${name}.preStart = ''
        install -m 0600 ${config.sops.templates.${template}.path} ${dataDir}/config.xml
      '';

      environment.systemPackages = [ config.services.${name}.package ];
    };
in
# What sonarr, radarr and prowlarr share.
{
  inherit common;

  vhost = name: port: {
    inherit name port;
    # config.xml sets External authentication: the app authenticates nobody
    # and serves its API key to whoever asks.
    requiresProxyAuth = true;
  };

  # sonarr and radarr, each managing one media category.
  manager =
    {
      name,
      title,
      port,
      dataDir,
      category,
    }:
    {
      config,
      host,
      lib,
      pkgs,
      ...
    }:
    let
      media = import ./_media.nix host.mediaRoot;
      inherit (media) group;
      mediaDir = media.mediaDir media.categories.${category};
    in
    lib.mkMerge [
      (common {
        inherit
          lib
          name
          title
          port
          dataDir
          group
          ;
      } config)
      {
        users.groups.${group} = { };

        services.${name} = {
          enable = true;
          package = pkgs.unstable.${name};
          user = name;
          inherit group dataDir;
          # nginx is the ingress; opening the port here would let clients bypass it.
          openFirewall = false;
          settings.server.port = port;
        };

        systemd.tmpfiles.rules = [
          "d ${dataDir} 0755 ${name} ${group} -"
          "d ${media.mediaRoot} 0775 ${name} ${group} -"
          "d ${mediaDir} 0775 ${name} ${group} -"
        ];
      }
    ];
}
