{ lib, ... }:
let
  inherit (lib) types;
in
{
  # Apart from `system.networking`: the router stack includes that aspect and
  # has no host to call `lan-leases` with.
  den.aspects.system.networking.lan = {
    settings = {
      address = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv4 address the router leases to the host; null for a host off the home LAN.";
      };
      mac = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "MAC address of the interface the host reaches the LAN on.";
      };
    };

    lan-leases =
      { host, ... }:
      let
        inherit (host.settings.system.networking.lan) address mac;
      in
      lib.optional (address != null) {
        inherit (host) name;
        inherit address;
        mac =
          if mac != null then mac else throw "host ${host.name}: system.networking.lan.address needs a mac";
      };
  };
}
