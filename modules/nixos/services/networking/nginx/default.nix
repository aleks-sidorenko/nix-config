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
  sopsEnabled = config.${namespace}.security.sops.enable;

  # A backend that delegates authentication to the proxy is unauthenticated
  # until the proxy actually performs it, so it is not published before then.
  withheld = filterAttrs (_: v: v.requiresProxyAuth && cfg.authFile == null) cfg.virtualHosts;
  published = removeAttrs cfg.virtualHosts (attrNames withheld);
in
{
  options.${namespace}.services.networking.nginx = {
    enable = mkEnableOption "Enable nginx web server";

    authFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "htpasswd file guarding every vhost that sets `requiresProxyAuth`.";
    };

    authFromSecret = mkOption {
      type = types.bool;
      default = false;
      description = "Point authFile at the SOPS secret `service-ingress-htpasswd` (modules/nixos/secrets.yaml). Opt-in because the secret is not provisioned on every host; enabling it before the secret exists breaks activation.";
    };

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
            requiresProxyAuth = mkOption {
              type = types.bool;
              default = false;
              description = "This backend performs no authentication of its own and expects the proxy to do it. Publishing it without `authFile` would expose it unauthenticated, so the vhost is withheld until one is set.";
            };
            proxyWebsockets = mkOption {
              type = types.bool;
              default = true;
              description = "Forward websocket upgrades. Off for backends whose HTTP server rejects an Upgrade header it never negotiated.";
            };
          };
        }
      );
      default = { };
      description = "Virtual hosts configuration";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Opt-in: sops-nix fails activation if the secret is absent from
      # modules/nixos/secrets.yaml, so this must not be unconditional.
      services.networking.nginx.authFile = mkIf cfg.authFromSecret (
        mkDefault config.sops.secrets."service-ingress-htpasswd".path
      );

      # Every served vhost is a name this host answers to; deriving them here
      # means neither a disabled service nor a withheld one leaves a dangling
      # record behind.
      system.networking.names = mapAttrsToList (_: v: v.serverName) published;
    };

    sops.secrets."service-ingress-htpasswd" = mkIf (cfg.authFromSecret && sopsEnabled) {
      sopsFile = ../../../secrets.yaml;
      owner = config.services.nginx.user;
      inherit (config.services.nginx) group;
      mode = "0400";
    };

    warnings = optional (withheld != { }) ''
      nginx is withholding vhost(s) ${concatStringsSep ", " (attrNames withheld)}:
      their backends expect the proxy to authenticate and no authFile is set.
      Add the htpasswd secret and set services.networking.nginx.authFromSecret.
    '';

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
        mapAttrs (
          _name: vhost:
          {
            inherit (vhost) serverName;
            extraConfig = ''
              client_max_body_size ${vhost.clientMaxBodySize};
            '';
            locations = vhost.locations // {
              "/" = {
                proxyPass = "http://127.0.0.1:${toString vhost.port}";
                recommendedProxySettings = true;
                inherit (vhost) proxyWebsockets;
                extraConfig = ''
                  proxy_buffering off;
                '';
              };
            };
          }
          // optionalAttrs vhost.requiresProxyAuth { basicAuthFile = cfg.authFile; }
        ) published
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
        # 443 stays shut while no vhost terminates TLS. Cosmetic for tailnet
        # traffic, which `tailscaled` accepts ahead of this chain — the tailnet
        # ACL is where that port is really withheld — but it is what a host
        # without Tailscale falls back to below.
        ports = [ 80 ];
      in
      if config.services.tailscale.enable then
        { interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = ports; }
      else
        { allowedTCPPorts = ports; };
  };
}
