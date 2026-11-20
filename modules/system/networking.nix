{ lib, ... }:
let
  inherit (lib) types;
in
{
  den.aspects.system.networking = {
    settings = {
      lanDomain = lib.mkOption {
        type = types.str;
        default = "lan";
        description = "Local network domain.";
      };
      tailnetDomain = lib.mkOption {
        type = types.str;
        default = "colobus-bramble.ts.net";
        description = "Tailnet MagicDNS domain.";
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
        inherit (host.settings.system.networking) lanDomain tailnetDomain knownNetworkServices;
      in
      {
        networking = {
          inherit knownNetworkServices;
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          search = [
            tailnetDomain
            lanDomain
          ];
        };
      };
  };
}
