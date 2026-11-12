{
  config,
  inputs,
  ...
}:
let
  c = (config.builders.testNixos config.flake.modules.nixos.jellyfin).config;
in
{
  flake.modules.nixos.jellyfin =
    { config, pkgs, ... }:
    let
      user = "jellyfin";
      inherit (config.constants.media) group;
      root = "/var/lib/jellyfin";
      configDir = "${root}/config";
      cacheDir = "${root}/cache";
      logDir = "${root}/log";
      dataDir = "${root}/data";
    in
    {
      imports = with inputs.self.modules.nixos; [
        media-library
        nginx
      ];

      nix-config.nginx.virtualHosts.jellyfin.port = config.constants.network.ports.jellyfin.web;

      services.jellyfin = {
        enable = true;
        package = pkgs.jellyfin;
        inherit user group;
        # nginx is the ingress; opening the port here would let clients bypass it.
        openFirewall = false;
        inherit
          logDir
          cacheDir
          dataDir
          configDir
          ;
      };

      systemd.tmpfiles.rules = [
        "d ${root} 0755 ${user} ${group} -"
        "d ${configDir} 0755 ${user} ${group} -"
        "d ${cacheDir} 0755 ${user} ${group} -"
        "d ${logDir} 0755 ${user} ${group} -"
      ];

      environment.systemPackages = [ pkgs.jellyfin ];
    };

  evalTests.jellyfin-dirs = {
    expr = with c.services.jellyfin; [
      dataDir
      cacheDir
      configDir
      logDir
      openFirewall
    ];
    expected = [
      "/var/lib/jellyfin/data"
      "/var/lib/jellyfin/cache"
      "/var/lib/jellyfin/config"
      "/var/lib/jellyfin/log"
      false
    ];
  };
}
