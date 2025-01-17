{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.syncthing;
in {
  options.services.nix-config.syncthing = {
    enable = mkEnableOption "Enable the syncthing service";
  };

  config = mkIf cfg.enable {
    services = {
      syncthing = {
        enable = true;
        guiAddress = "0.0.0.0:8384";
        dataDir = "/mnt/share/syncthing";
        group = "media";
        openDefaultPorts = true;
        relay = {
          enable = true;
        };
      };

      traefik = {
        dynamicConfigOptions = {
          http = {
            services = {
              syncthing.loadBalancer.servers = [
                {
                  url = "http://localhost:8384";
                }
              ];
            };

            routers = {
              syncthing = {
                entryPoints = ["websecure"];
                rule = "Host(`syncthing.homelab.haseebmajid.dev`)";
                service = "syncthing";
                tls.certResolver = "letsencrypt";
                middlewares = ["authentik"];
              };
            };
          };
        };
      };
    };
  };
}
