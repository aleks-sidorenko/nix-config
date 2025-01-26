{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.netdata;
in {
  options.services.nix-config.netdata = {
    enable = mkEnableOption "Enable the netdata service";
  };

  config = mkIf cfg.enable {
    services = {
      netdata = {
        enable = true;
      };

      traefik = {
        dynamicConfigOptions = {
          http = {
            services = {
              netdata.loadBalancer.servers = [
                {
                  url = "http://localhost:19999";
                }
              ];
            };

            routers = {
              netdata = {
                entryPoints = ["websecure"];
                rule = "Host(`netdata.homelab.haseebmajid.dev`)";
                service = "netdata";
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
