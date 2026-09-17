{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    roles = {
      # Use work role (includes common + homebrew + defaults)
      work = {
        enable = true;
      };

      # Always-on host: keeps the machine from idle-sleeping so long-running
      # agent sessions (and the VPN they rely on) survive being left unattended.
      agent-host = enabled;
    };

    # This machine's macOS account (declared like NixOS hosts).
    users.oleksandrsy = {
      primary = true;
      admin = true;
    };

    system.networking = {
      knownNetworkServices = [
        "Wi-Fi"
        "USB 10/100/1000 LAN"
        "ThinkPad TBT 3 Dock"
        "Thunderbolt Bridge"
      ];
    };
  };

  system.stateVersion = 5;
}
