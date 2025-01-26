{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.immich;
in {
  options.services.nix-config.immich = {
    enable = mkEnableOption "Enable the immich photo service";
  };

  config = mkIf cfg.enable {
    services = {
      immich = {
        enable = true;
        host = "0.0.0.0";
        mediaLocation = "/mnt/nfs/homelab/immich";
      };

      traefik = {
        dynamicConfigOptions = {
          http = {
            services = {
              immich.loadBalancer.servers = [
                {
                  url = "http://localhost:2283";
                }
              ];
            };

            routers = {
              immich = {
                entryPoints = ["websecure"];
                rule = "Host(`immich.homelab.haseebmajid.dev`)";
                service = "immich";
                tls.certResolver = "letsencrypt";
              };
            };
          };
        };
      };
    };
  };
}
