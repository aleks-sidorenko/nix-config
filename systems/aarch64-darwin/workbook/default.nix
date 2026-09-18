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

      # Always-on: long-running agent sessions, and the VPN they rely on, must
      # survive the machine being left unattended.
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

    # KPI VPN. Split-tunnel by default, so it installs only its own routes and
    # GlobalProtect keeps the default route: both stay connected, nothing to
    # toggle. On demand via `vpn up kpi` / `vpn down kpi`.
    services.networking.openvpn = {
      enable = true;
      connections.kpi = { };
    };
  };

  system.stateVersion = 5;
}
