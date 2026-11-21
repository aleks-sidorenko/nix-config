{ lib, ... }:
let
  inherit (lib) types;
in
{
  den.aspects.system.networking = {
    settings = {
      domains = lib.mkOption {
        type = types.submodule {
          options = {
            lan = lib.mkOption {
              type = types.str;
              default = "lan";
              description = "Local network domain.";
            };
            tailnet = lib.mkOption {
              type = types.str;
              default = "colobus-bramble.ts.net";
              description = "Tailnet MagicDNS domain.";
            };
            public = lib.mkOption {
              type = types.str;
              default = "home.sidorenko.me";
              description = "Public DNS zone the proxied services are named under, as `<name>.<public>`.";
            };
          };
        };
        default = { };
        description = "The networks' DNS domains.";
      };
      knownNetworkServices = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "macOS network services whose DNS is managed.";
      };
    };

    # The DHCP client's leases and identity are re-acquired on every boot.
    persist.ignore = [ "/var/lib/dhcpcd" ];

    nixos.networking.firewall.enable = true;

    darwin =
      { host, ... }:
      let
        inherit (host.settings.system.networking) domains knownNetworkServices;
      in
      {
        networking = {
          inherit knownNetworkServices;
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          search = [
            domains.tailnet
            domains.lan
          ];
        };
      };
  };
}
