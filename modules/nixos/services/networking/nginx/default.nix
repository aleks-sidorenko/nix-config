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
            clientMaxBodySize = mkOption {
              type = types.str;
              default = "10m";
              description = "Maximum allowed size of the client request body";
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

      virtualHosts =
        mapAttrs (_name: vhost: {
          inherit (vhost) serverName;
          extraConfig = ''
            client_max_body_size ${vhost.clientMaxBodySize};
          '';
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
        }) cfg.virtualHosts
        // {
          # An unmatched Host would otherwise fall through to whichever vhost
          # nginx defines first, silently serving the wrong service. 444 closes
          # the connection without a response, so a stale name fails visibly.
          "_" = {
            default = true;
            extraConfig = "return 444;";
          };
        };
    };

    # Reachable over the tailnet only. Service names resolve to tailnet
    # addresses, so a LAN client already needs Tailscale to use them, and
    # scoping the ingress here means a device on the same LAN as the host
    # cannot skip that. Falls back to opening globally on a host without
    # Tailscale, which would otherwise have no ingress at all.
    networking.firewall =
      let
        ports = [
          80
          443
        ];
      in
      if config.services.tailscale.enable then
        { interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = ports; }
      else
        { allowedTCPPorts = ports; };

    # Every declared vhost is a name this host answers to; deriving them here
    # means a disabled service cannot leave a dangling record behind.
    ${namespace}.system.networking.names = mapAttrsToList (_: v: v.serverName) cfg.virtualHosts;
  };
}
