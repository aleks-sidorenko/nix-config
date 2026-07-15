{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    # Use work role (includes common + homebrew + defaults)
    roles.work = {
      enable = true;
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
