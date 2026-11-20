{ den, lib, ... }:
{
  den.aspects.system.networkmanager = {
    includes = [ den.aspects.system.networking ];

    persist.directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
    ];
    installChecks = [ ''machine.succeed("systemctl is-active NetworkManager.service")'' ];

    nixos =
      { host, ... }:
      let
        inherit (host.settings.system.networking) lanDomain tailnetDomain;
      in
      {
        networking = {
          networkmanager.enable = true;
          domain = lanDomain;
          search = [
            tailnetDomain
            lanDomain
          ];
        };

        # Network control for every account on the host.
        users.users = lib.mapAttrs' (
          _: user: lib.nameValuePair user.userName { extraGroups = [ "networkmanager" ]; }
        ) host.users;

        boot.kernel.sysctl = {
          "net.core.default_qdisc" = "fq";
          "net.ipv4.tcp_congestion_control" = "bbr";
        };

        # Nothing waits on the network to come up, and these units stall boot
        # when the link is down.
        systemd = {
          services.NetworkManager-wait-online.enable = false;
          network.wait-online.enable = false;
        };
      };
  };
}
