{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./disks.nix
  ];
  nixpkgs.overlays = [
    (_final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # Example: https://github.com/Stunkymonkey/nixos/tree/master/machines/serverless

  ${namespace} = {
    # The Pi this config describes is at a house nobody lives in anymore —
    # unreachable, not on the tailnet, not getting rebuilt soon. `server-vm`
    # is its stand-in and the only host actually running these services, so
    # `home-server` stays off here to avoid declaring service names this host
    # can't back; `common` alone keeps it a real, evaluating machine
    # definition (ssh, sops, tailnet) for whenever the Pi comes back.
    # Two hosts declaring the same name is now a build-time error (see
    # infra/dns), so bringing the Pi back means BOTH halves of the swap in
    # the same change: enable `home-server` here AND remove it from
    # `server-vm` — not just one.
    roles = {
      common = enabled;
    };

    hardware.raspberry-pi-4 = enabled;

    # `home-server` used to carry `tag:server` via `roles.server`; dropping
    # the role also dropped the tag, and an OAuth-secret registration is
    # rejected with no tags. Set it directly so this host keeps joining the
    # tailnet unattended and still matches `tag:server` ACL rules, without
    # claiming the service names `home-server` would.
    services.networking.tailscale.tags = [ "tag:server" ];
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
