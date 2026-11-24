{
  config,
  den,
  lib,
  ...
}:
{
  den.stacks.router.settings.infra.router = {
    country = "Ukraine";
    apiUser = "alexander";
  };

  den.aspects.infra.router = {
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
    };

    terranix =
      { stack, ... }:
      let
        inherit (stack.settings.infra) router;
      in
      {
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
            address = "10.0.0.1";
            username = router.apiUser;
          };
          system = {
            identity = "router";
            timezone = stack.settings.system.locale.timeZone;
          };
          lan = {
            address = "10.0.0.1/24";
            dhcp.pool = "10.0.0.100-10.0.0.250";
          };
          uplinks = {
            isp = {
              kind = "ethernet";
              interface = "ether2";
              distance = 1;
              check.host = "1.0.0.1";
            };
            hotspot = {
              kind = "wifi-station";
              runtimeManaged = true;
              station.radio = "wifi2";
              distance = 2;
              check.host = "9.9.9.9";
            };
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
            records.canary-application-dns = {
              name = "use-application-dns.net";
              type = "NXDOMAIN";
            };
          };
        };
      };
  };

  evalTests.infra-router-secrets = {
    expr = lib.attrNames config.infraStacks.router.meta.secrets;
    expected = [
      "TF_VAR_routeros_password"
      "TF_VAR_state_passphrase"
      "TF_VAR_wifi_password"
    ];
  };
}
