# What sonarr, radarr and prowlarr share.
{ den }:
let
  vhost = name: port: {
    inherit name port;
    # config.xml sets External authentication: the app authenticates nobody
    # and serves its API key to whoever asks.
    requiresProxyAuth = true;
  };

  # An API key secret and a config.xml rendered from it, installed before each
  # start, the service user, and the package on PATH.
  common =
    {
      name,
      title,
      port,
      dataDir,
      group,
    }:
    { config, lib, ... }:
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

  # The aspect for one *arr app; `nixos` takes the media layout and returns
  # the app's own NixOS module.
  aspect =
    {
      name,
      title,
      port,
      dataDir,
      checks ? [ ],
      nixos,
    }:
    {
      includes = [ den.aspects.services.media ];
      persist.directories = [ dataDir ];
      installChecks = [ ''machine.wait_for_unit("${name}.service")'' ] ++ checks;
      vhosts = [ (vhost name port) ];
      nixos =
        { host, ... }:
        let
          media = import ./_media.nix host;
        in
        {
          imports = [
            (common {
              inherit
                name
                title
                port
                dataDir
                ;
              inherit (media) group;
            })
            (nixos media)
          ];
        };
    };
in
{
  inherit aspect;

  # sonarr and radarr, each managing one media category.
  manager =
    {
      name,
      title,
      port,
      category,
    }:
    let
      dataDir = "/var/lib/${name}";
    in
    aspect {
      inherit
        name
        title
        port
        dataDir
        ;
      nixos =
        media:
        { pkgs, ... }:
        {
          services.${name} = {
            enable = true;
            package = pkgs.unstable.${name};
            user = name;
            inherit (media) group;
            inherit dataDir;
            # nginx is the ingress; opening the port here would let clients bypass it.
            openFirewall = false;
            settings.server.port = port;
          };

          systemd.tmpfiles.rules = [
            "d ${dataDir} 0755 ${name} ${media.group} -"
            "d ${media.libraryRoot} 0775 ${name} ${media.group} -"
            "d ${media.mediaDir media.categories.${category}} 0775 ${name} ${media.group} -"
          ];
        };
    };
}
