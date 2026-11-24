{
  config,
  den,
  lib,
  ...
}:
let
  lan = import ./_lan.nix { inherit lib; };
in
{
  den = {
    quirks.lan-leases.description = "A host's fixed address and MAC on the home LAN: { name; address; mac; }; the `router` stack gives each a static lease.";

    stacks.router = {
      settings.infra.router = {
        country = "Ukraine";
        apiUser = "alexander";
        importIds = {
          "routeros_interface_bridge.bridge" = "*9";
          "routeros_interface_bridge_port.wifi1" = "*0";
          "routeros_ip_address.lan" = "*1";
          "routeros_ip_dhcp_client.upstream" = "*1";
          "routeros_ip_dhcp_server.lan" = "*1";
          "routeros_ip_dhcp_server_network.lan" = "*1";
          "routeros_ip_pool.lan" = "*1";
          "routeros_wifi.wifi1" = "*2";
          "routeros_wifi.wifi2" = "*3";
          "routeros_wifi_configuration.home" = "*1";
          "routeros_wifi_security.home" = "*1";
        };
      };
      includes = [
        den.policies.lan-leases
        den.policies.published-names
      ];
    };

    # Only deployed hosts: a stand-in host shares its original's address.
    policies.lan-leases = _: [
      (den.lib.policy.pipe.from "lan-leases" [
        (den.lib.policy.pipe.collectAll ({ host, ... }: config.isDeployed host))
      ])
    ];

    aspects.infra.router = {
      includes = [
        den.aspects.infra.routeros
        den.aspects.system.networking
        den.aspects.system.locale
      ];

      settings = {
        country = lib.mkOption {
          type = lib.types.str;
          description = "Wi-Fi regulatory country, in the form RouterOS expects.";
        };
        apiUser = lib.mkOption {
          type = lib.types.str;
          description = "RouterOS API user the provider logs in as.";
        };
        importIds = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "routeros_interface_bridge.bridge" = "*1";
          };
          description = "RouterOS `.id` of each hand-made resource the first apply adopts, by resource address.";
        };
      };

      terranix =
        {
          stack,
          lan-leases,
          published-names,
          ...
        }:
        let
          inherit (stack.settings.infra) router;
          address = "10.0.0.1";
          unleased = lan.unleasedNames {
            leases = lan-leases;
            names = map (e: {
              host = e.source.host.name;
              name = e.value;
            }) published-names;
          };
          addressOf = host: (lib.findFirst (l: l.name == host) null lan-leases).address;
        in
        if unleased != [ ] then
          throw "infra/router: published name(s) whose host has no lan address: ${
            lib.concatStringsSep ", " (map (n: "${n.host} (${n.name})") unleased)
          }"
        else
          lib.optionalAttrs (router.importIds != { }) {
            import = lan.importBlocks router.importIds;
          }
          // {
            variable.wifi_password = {
              type = "string";
              sensitive = true;
            };

            _meta.secrets.TF_VAR_wifi_password = {
              file = "${stack.dir}/secrets.yaml";
              key = "wifi-password";
            };

            routeros = {
              device = "hap-ax3";
              connection = {
                inherit address;
                username = router.apiUser;
              };
              system = {
                identity = stack.name;
                timezone = stack.settings.system.locale.timeZone;
              };
              lan = {
                address = "${address}/24";
                dhcp.pool = "10.0.0.100-10.0.0.250";
                leases = lib.listToAttrs (
                  map (l: lib.nameValuePair l.name { inherit (l) address mac; }) lan-leases
                );
              };
              uplinks.upstream = {
                kind = "wifi-station";
                runtimeManaged = true;
                station.radio = "wifi2";
                distance = 1;
                check.host = "9.9.9.9";
              };
              wifi = {
                inherit (router) country;
                networks.home = {
                  ssid = "SWEET-HOME";
                  primary = true;
                  passphraseVariable = "wifi_password";
                };
              };
              dns = {
                upstream = [
                  "1.1.1.1"
                  "8.8.8.8"
                ];
                localDomain = stack.settings.system.networking.domains.lan;
                # The library sanitizes each key into a resource name.
                records = {
                  canary-application-dns = {
                    name = "use-application-dns.net";
                    type = "NXDOMAIN";
                  };
                }
                // lib.listToAttrs (
                  map (
                    e:
                    lib.nameValuePair e.value {
                      name = e.value;
                      address = addressOf e.source.host.name;
                    }
                  ) published-names
                );
              };
            };
          };
    };

  };

  evalTests = {
    infra-router-server-lease = {
      expr = config.infraStacks.router.config.resource.routeros_ip_dhcp_server_lease.server.address;
      expected = "10.0.0.10";
    };
    # server-vm shares server's config but must not claim its address.
    infra-router-leases-deployed-only = {
      expr = lib.attrNames config.infraStacks.router.config.resource.routeros_ip_dhcp_server_lease;
      expected = [ "server" ];
    };
    infra-router-split-horizon =
      let
        served = map (r: r.name) (
          lib.filter (r: r.hostname == "server") config.infraStacks.dns.config.locals.service_records
        );
        # The library adds a `lease_*` record per lease for the lan domain.
        records = lib.filterAttrs (
          k: _: !(lib.hasPrefix "lease_" k)
        ) config.infraStacks.router.config.resource.routeros_ip_dns_record;
      in
      {
        expr = lib.sort lib.lessThan (
          map (r: r.name) (lib.filter (r: r.type == "A" && r.address == "10.0.0.10") (lib.attrValues records))
        );
        expected = lib.sort lib.lessThan served;
      };
    infra-router-unleased-name = {
      expr = lan.unleasedNames {
        leases = [
          {
            name = "a";
            address = "10.0.0.2";
            mac = "aa";
          }
        ];
        names = [
          {
            host = "a";
            name = "a.x";
          }
          {
            host = "b";
            name = "b.x";
          }
        ];
      };
      expected = [
        {
          host = "b";
          name = "b.x";
        }
      ];
    };
    infra-router-doh-canary = {
      expr = lib.any (r: r.name == "use-application-dns.net" && r.type == "NXDOMAIN") (
        lib.attrValues config.infraStacks.router.config.resource.routeros_ip_dns_record
      );
      expected = true;
    };
    infra-router-imports = {
      expr = map (i: i.to) config.infraStacks.router.config.import;
      expected = [
        "routeros_interface_bridge.bridge"
        "routeros_interface_bridge_port.wifi1"
        "routeros_ip_address.lan"
        "routeros_ip_dhcp_client.upstream"
        "routeros_ip_dhcp_server.lan"
        "routeros_ip_dhcp_server_network.lan"
        "routeros_ip_pool.lan"
        "routeros_wifi.wifi1"
        "routeros_wifi.wifi2"
        "routeros_wifi_configuration.home"
        "routeros_wifi_security.home"
      ];
    };
    infra-router-import-blocks = {
      expr = lan.importBlocks {
        "routeros_interface_bridge.bridge" = "*1";
        "routeros_ip_address.lan" = "*2";
      };
      expected = [
        {
          to = "routeros_interface_bridge.bridge";
          id = "*1";
        }
        {
          to = "routeros_ip_address.lan";
          id = "*2";
        }
      ];
    };
    infra-router-secrets = {
      expr = lib.attrNames config.infraStacks.router.meta.secrets;
      expected = [
        "TF_VAR_routeros_password"
        "TF_VAR_state_passphrase"
        "TF_VAR_wifi_password"
      ];
    };
  };
}
