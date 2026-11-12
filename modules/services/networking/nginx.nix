{
  config,
  inputs,
  lib,
  ...
}:
let
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        tailscale
        nginx
      ];
      nix-config.nginx.virtualHosts.probe.port = 1;
    }).config;
in
{
  flake.modules.nixos.nginx =
    { config, lib, ... }:
    let
      cfg = config.nix-config.nginx;
      htpasswd = config.sops.secrets."service-ingress-htpasswd".path;
      serverName = name: "${name}.${config.constants.network.domains.services}";
    in
    {
      imports = with inputs.self.modules.nixos; [
        networking-names
        sops
      ];

      options.nix-config.nginx.virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Port to proxy to";
              };
              clientMaxBodySize = lib.mkOption {
                type = lib.types.str;
                default = "10m";
                description = "Maximum allowed size of the client request body";
              };
              requiresProxyAuth = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "This backend performs no authentication of its own and expects the proxy to do it with the ingress htpasswd.";
              };
              proxyWebsockets = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Forward websocket upgrades. Off for backends whose HTTP server rejects an Upgrade header it never negotiated.";
              };
            };
          }
        );
        default = { };
        description = "Virtual hosts proxied to local backends, each served as `<name>` under the services domain.";
      };

      config = {
        assertions = [
          {
            assertion = !(cfg.virtualHosts ? _);
            message = "nix-config.nginx.virtualHosts: `_` is the catch-all vhost and can't be a service.";
          }
        ];

        # Every served vhost is a name this host answers to; deriving them here
        # means a removed service leaves no dangling record behind.
        nix-config.networking.names = map serverName (lib.attrNames cfg.virtualHosts);

        sops.secrets."service-ingress-htpasswd" = {
          owner = config.services.nginx.user;
          inherit (config.services.nginx) group;
          mode = "0400";
        };

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
            lib.mapAttrs (
              name: vhost:
              {
                serverName = serverName name;
                extraConfig = ''
                  client_max_body_size ${vhost.clientMaxBodySize};
                '';
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString vhost.port}";
                  recommendedProxySettings = true;
                  inherit (vhost) proxyWebsockets;
                  extraConfig = ''
                    proxy_buffering off;
                  '';
                };
              }
              // lib.optionalAttrs vhost.requiresProxyAuth { basicAuthFile = htpasswd; }
            ) cfg.virtualHosts
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
            # 443 before anything terminates TLS, so a client that upgraded the
            # scheme is refused rather than left waiting.
            ports = [
              80
              443
            ];
          in
          if config.services.tailscale.enable then
            { interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = ports; }
          else
            { allowedTCPPorts = ports; };
      };
    };

  evalTests = {
    nginx-servername = {
      expr = c.services.nginx.virtualHosts.probe.serverName;
      expected = "probe.home.sidorenko.me";
    };
    # `_` is the catch-all, not a name anything should resolve to.
    nginx-names-from-vhosts = {
      expr = c.nix-config.networking.names;
      expected = [ "probe.home.sidorenko.me" ];
    };
    nginx-default-444 = {
      expr = c.services.nginx.virtualHosts._.extraConfig;
      expected = "return 444;";
    };
    nginx-ports-tailnet-only = {
      expr = {
        tailnet = c.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
        global = lib.intersectLists [
          80
          443
        ] c.networking.firewall.allowedTCPPorts;
      };
      expected = {
        tailnet = [
          80
          443
        ];
        global = [ ];
      };
    };
    nginx-htpasswd-owner = {
      expr = c.sops.secrets."service-ingress-htpasswd".owner;
      expected = "nginx";
    };
  };
}
