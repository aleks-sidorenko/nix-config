{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  ${namespace} = {
    roles = {
      home-server = enabled;

      # The plugs, heatpump and climate sensors its automations name stayed
      # with the old house.
      smart-home = disabled;
    };

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;

    services.backup =
      let
        listen = "127.0.0.1:${toString defaults.network.ports.restic.web}";
      in
      {
        # The `restic.local` alias names the Pi, which is gone. Client and REST
        # server are the same host here, so the repository is reached over
        # loopback — which is also the only address the server binds.
        restic.repository = "rest:http://${listen}";
        restic-server.listenAddress = listen;
      };

    # Bridged addressing follows whichever LAN the host Mac is on, so the
    # tailnet carries the guest's stable identity.
    services.networking.tailscale = enabled;
  };

  # Bridged onto whichever network the host Mac joins, including untrusted
  # ones, so this guest does not inherit the repo-wide off-by-default firewall
  # (see the TODO in modules/nixos/system/networking) that assumes a LAN behind
  # our own router. mkForce because that default is set at normal priority.
  networking.firewall.enable = mkForce true;

  # Without it tailscaled still connects, but only via a DERP relay.
  services.tailscale.openFirewall = true;

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
