{ den, lib, ... }:
let
  withDefaults =
    vhost:
    {
      requiresProxyAuth = false;
      proxyWebsockets = true;
      clientMaxBodySize = "10m";
      locations = { };
    }
    // vhost;

  # Backends start slowly, so a vhost is polled until it answers. Only an
  # unreachable ingress (000) or a failing backend (5xx) is wrong; a vhost
  # that needs proxy auth must refuse a request carrying no credentials.
  checkFor =
    serverName: requiresProxyAuth:
    let
      status = "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${serverName}' http://127.0.0.1/";
      command =
        if requiresProxyAuth then
          ''[ "$(${status})" = 401 ]''
        else
          ''c=$(${status}); [ "$c" -gt 0 ] && [ "$c" -lt 500 ]'';
    in
    "machine.wait_until_succeeds(${builtins.toJSON command})";

  duplicateNames =
    vhosts: lib.attrNames (lib.filterAttrs (_: vs: lib.length vs > 1) (lib.groupBy (v: v.name) vhosts));
in
{
  den.quirks.vhosts.description = "Services nginx proxies to: { name; port; requiresProxyAuth ? false; proxyWebsockets ? true; clientMaxBodySize ? \"10m\"; locations ? { }; }, served at `<name>.<public>`, the `system.networking.domains.public` setting.";

  den.aspects.services.nginx = {
    # Ingress is scoped to the tailnet interface.
    includes = [
      den.aspects.security.sops
      den.aspects.services.tailscale
      den.aspects.system.networking
    ];

    # Read back from the rendered vhosts, so a record exists for each name
    # nginx serves and for no other.
    published-names =
      { config, ... }:
      lib.mapAttrsToList (_: vhost: vhost.serverName) (
        removeAttrs config.services.nginx.virtualHosts [ "_" ]
      );

    # Read back from the rendered vhosts, so each check tests what nginx serves.
    installChecks =
      { config, ... }:
      lib.mapAttrsToList (_: vhost: checkFor vhost.serverName (vhost.basicAuthFile != null)) (
        removeAttrs config.services.nginx.virtualHosts [ "_" ]
      );

    nixos =
      {
        config,
        host,
        pkgs,
        vhosts,
        ...
      }:
      let
        published = map withDefaults vhosts;
        htpasswd = config.sops.secrets."service-ingress-htpasswd".path;
      in
      {
        # listToAttrs would keep one of two same-named vhosts and drop the other.
        assertions = [
          {
            assertion = duplicateNames vhosts == [ ];
            message = "vhosts: ${lib.concatStringsSep ", " (duplicateNames vhosts)} contributed more than once; vhost names must be unique.";
          }
        ];

        # Always declared, so a host can't gain an auth-requiring vhost without it.
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
            lib.listToAttrs (
              map (
                vhost:
                lib.nameValuePair vhost.name (
                  {
                    serverName = "${vhost.name}.${host.settings.system.networking.domains.public}";
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
                  // lib.optionalAttrs vhost.requiresProxyAuth { basicAuthFile = htpasswd; }
                )
              ) published
            )
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

        # Service names resolve to tailnet addresses, so ingress is scoped to
        # the tailnet: a device on the same LAN can't skip it. 443 is open
        # before anything terminates TLS so an upgraded scheme is refused, not
        # left waiting.
        networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
          80
          443
        ];

        installTest.extraConfig.environment.systemPackages = [ pkgs.curl ];
      };
  };

  evalTests.nginx-duplicate-vhosts = {
    expr = duplicateNames [
      { name = "a"; }
      { name = "b"; }
      { name = "a"; }
    ];
    expected = [ "a" ];
  };

  evalTests.nginx-vhost-checks = {
    expr = [
      (checkFor "open.example.test" false)
      (checkFor "guarded.example.test" true)
    ];
    expected = [
      ''machine.wait_until_succeeds("c=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: open.example.test' http://127.0.0.1/); [ \"$c\" -gt 0 ] && [ \"$c\" -lt 500 ]")''
      ''machine.wait_until_succeeds("[ \"$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: guarded.example.test' http://127.0.0.1/)\" = 401 ]")''
    ];
  };
}
