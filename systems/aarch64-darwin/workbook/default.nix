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

    # KPI VPN, on demand via `vpn up kpi` / `vpn down kpi`.
    #
    # Full tunnel, because the server offers nothing else: its PUSH_REPLY
    # carries redirect-gateway plus its own gateway route, and no KPI subnet
    # routes at all. Resources there (e.g. teamcity.cloud.kpi.ua, hosted off
    # site on AWS) are allow-listed by source IP, so traffic has to exit
    # through KPI to be recognised.
    #
    # It therefore claims the default route and cannot share the host with
    # GlobalProtect: disconnect that first. Nesting the two fails on its own
    # terms anyway, since GlobalProtect's utun runs at MTU 1350 and openvpn's
    # handshake packets do not survive the fragmentation.
    services.networking.openvpn = {
      enable = true;
      connections.kpi = { };
    };
  };

  system.stateVersion = 5;
}
