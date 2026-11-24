{ lib, ... }:
{
  # Not in `system.networking`: the router stack includes that aspect and has no host to call this with.
  den.aspects.system.lan.lan-leases =
    { host, ... }:
    lib.optional (host.lan != null) {
      inherit (host) name;
      inherit (host.lan) address mac;
    };
}
