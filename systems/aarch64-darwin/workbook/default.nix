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

    # Override user name for this machine
    user.name = mkForce "oleksandrsy";

    # claude-code via Homebrew for latest version
    system.homebrew.casks = [ "claude-code" ];

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
