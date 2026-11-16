let
  webPort = 8200;
  discoveryPort = 1900;
in
{
  den.aspects.services.minidlna = {
    # Avoids rescanning the library each boot.
    persist.directories = [ "/var/cache/minidlna" ];
    installChecks = [ ''machine.wait_for_unit("minidlna.service")'' ];

    vhosts = [
      {
        name = "minidlna";
        port = webPort;
        # No login of its own, and the DLNA clients that need it
        # unauthenticated reach this port directly rather than through the
        # vhost, so guarding the vhost costs them nothing.
        requiresProxyAuth = true;
        # Its embedded HTTP server answers 400 to the Upgrade/Connection
        # headers the proxy adds by default.
        proxyWebsockets = false;
      }
    ];

    nixos =
      { host, lib, ... }:
      let
        media = import ./_media.nix host.mediaRoot;
      in
      {
        users.groups.${media.group} = { };

        services.minidlna = {
          enable = true;
          settings = {
            media_dir = [
              "V,${media.mediaDir media.categories.movies}"
              "V,${media.mediaDir media.categories.series}"
            ];
            friendly_name = "Media Server";
            port = webPort;
            announce_interval = 60;
            strict_dlna = "no";
            inotify = "yes";
            enable_tivo = "no";
            wide_links = "no";
            root_container = "B";
          };
        };

        # Clients find the server over SSDP, then fetch media straight from
        # this port rather than through the proxy, so both stay open.
        networking.firewall = {
          allowedTCPPorts = [ webPort ];
          allowedUDPPorts = [ discoveryPort ];
        };

        users.users.minidlna = {
          group = lib.mkForce media.group;
          extraGroups = [ "users" ];
        };
      };
  };
}
