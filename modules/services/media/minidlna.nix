{
  config,
  inputs,
  ...
}:
let
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        minidlna
        sops
        nginx
      ];
    }).config;
in
{
  flake.modules.nixos.minidlna =
    { config, lib, ... }:
    let
      media = config.nix-config.media;
      inherit (config.services.minidlna.settings) port;
      # SSDP
      discoveryPort = 1900;
    in
    {
      imports = [ inputs.self.modules.nixos.media-library ];

      nix-config.nginx.virtualHosts.minidlna = {
        inherit port;
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
          media_dir = map (category: "V,${media.mediaDir category}") (
            with media.categories;
            [
              movies
              series
            ]
          );
          friendly_name = "Media Server";
          port = 8200;
          announce_interval = 60;
          strict_dlna = "no";
          inotify = "yes";
          enable_tivo = "no";
          wide_links = "no";
          # Ensure read-only access
          root_container = "B";
        };
      };

      # DLNA clients discover the server over SSDP and then fetch media straight
      # from this port, not through the nginx vhost, so it stays open -- closing
      # it would leave the server announcing itself but unable to serve.
      networking.firewall.allowedTCPPorts = [ port ];

      # SSDP is UDP-only; minidlna never listens for discovery on TCP.
      networking.firewall.allowedUDPPorts = [ discoveryPort ];

      users.users.minidlna = {
        group = lib.mkForce media.group;
        extraGroups = [
          "users"
        ]; # so minidlna can access the files.
        description = "MiniDLNA daemon user";
      };
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
