{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.nix-config.couchdb;
in {
  options.services.nix-config.couchdb = {
    enable = mkEnableOption "Enable CouchDB";
  };

  config = mkIf cfg.enable {
    services = {
      couchdb = {
        enable = true;
        adminUser = "admin";
        adminPass = "admin";
      };

      traefik = {
        dynamicConfigOptions = {
          http = {
            services = {
              couchdb.loadBalancer.servers = [
                {
                  url = "http://localhost:5984";
                }
              ];
            };

            routers = {
              couchdb = {
                entryPoints = ["websecure"];
                rule = "Host(`couchdb.homelab.haseebmajid.dev`)";
                service = "couchdb";
                tls.certResolver = "letsencrypt";
              };
            };
          };
        };
      };
    };
  };
}
