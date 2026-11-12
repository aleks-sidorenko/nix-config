{
  config,
  inputs,
  ...
}:
let
  c = (config.builders.testNixos config.flake.modules.nixos.minidlna).config;
in
{
  flake.modules.nixos.minidlna =
    { config, ... }:
    let
      inherit (config.constants.media) group categories;
      inherit (config.constants.network.ports.dlna) web discovery;
    in
    {
      imports = with inputs.self.modules.nixos; [
        media-library
        nginx
      ];

      nix-config.nginx.virtualHosts.minidlna = {
        port = web;
        # No login of its own, and the DLNA clients that need it
        # unauthenticated reach this port directly rather than through the
        # vhost, so guarding the vhost costs them nothing.
        requiresProxyAuth = true;
        # Its embedded HTTP server answers 400 to the Upgrade/Connection
        # headers the proxy adds by default.
        proxyWebsockets = false;
      };

      services.minidlna = {
        enable = true;
        settings = {
          media_dir = map (category: "V,${category.mediaDir}") (
            with categories;
            [
              movies
              series
            ]
          );
          friendly_name = "Media Server";
          port = web;
          announce_interval = 60;
          strict_dlna = "no";
          inotify = "yes";
          enable_tivo = "no";
          wide_links = "no";
          root_container = "B";
        };
      };

      # DLNA clients discover the server over SSDP and then fetch media straight
      # from this port, not through the nginx vhost, so it stays open -- closing
      # it would leave the server announcing itself but unable to serve.
      networking.firewall.allowedTCPPorts = [ web ];

      # SSDP is UDP-only; minidlna never listens for discovery on TCP.
      networking.firewall.allowedUDPPorts = [ discovery ];

      # Upstream pins Group=, so the account's primary group never reaches
      # the process.
      systemd.services.minidlna.serviceConfig.SupplementaryGroups = [ group ];
    };

  evalTests = {
    minidlna-dirs = {
      expr = c.services.minidlna.settings.media_dir;
      expected = [
        "V,/data/media/Movies"
        "V,/data/media/Series"
      ];
    };
    # Clients fetch media straight from 8200, not through nginx.
    minidlna-firewall = {
      expr = [
        (builtins.elem 8200 c.networking.firewall.allowedTCPPorts)
        (builtins.elem 1900 c.networking.firewall.allowedUDPPorts)
      ];
      expected = [
        true
        true
      ];
    };
  };
}
