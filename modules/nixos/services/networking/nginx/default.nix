{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.networking.nginx;
  defaults = lib.${namespace}.defaults;
in
{
  options.${namespace}.services.networking.nginx = {
    enable = mkEnableOption "Enable nginx web server";

    virtualHosts = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            port = mkOption {
              type = types.port;
              description = "Port to proxy to";
            };
            serverName = mkOption {
              type = types.str;
              description = "Server name for the virtual host";
            };
            locations = mkOption {
              type = types.attrsOf types.attrs;
              default = { };
              description = "Additional location configurations";
            };
          };
        }
      );
      default = { };
      description = "Virtual hosts configuration";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;      
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      
      proxyTimeout = "600s";
      
      appendHttpConfig = ''
        proxy_headers_hash_max_size 1024;
        proxy_headers_hash_bucket_size 128;
      '';

      virtualHosts = mapAttrs (name: vhost: {
        serverName = vhost.serverName;
        locations = vhost.locations // {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString vhost.port}";
            recommendedProxySettings = true;
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      }) cfg.virtualHosts;
    };

    # Open HTTP/HTTPS ports
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
