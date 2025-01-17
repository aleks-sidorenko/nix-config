{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.gotify;
in {
  options.services.nix-config.gotify = {
    enable = mkEnableOption "Enable the notify service";
  };

  config = mkIf cfg.enable {
    services = {
      gotify = {
        enable = true;
        environment = {
          GOTIFY_SERVER_PORT = "8051";
        };
      };

      traefik = {
        dynamicConfigOptions = {
          http = {
            services = {
              notify.loadBalancer.servers = [
                {
                  url = "http://localhost:8051";
                }
              ];
            };

            routers = {
              notify = {
                entryPoints = ["websecure"];
                rule = "Host(`notify.homelab.haseebmajid.dev`)";
                service = "notify";
                tls.certResolver = "letsencrypt";
              };
            };
          };
        };
      };
    };
  };
}
