{ lib, ... }:
let
  inherit (lib) types;
in
{
  den.schema.conf.options = {
    lanDomain = lib.mkOption {
      type = types.str;
      default = "lan";
      description = "Local network domain.";
    };
    tailnetDomain = lib.mkOption {
      type = types.str;
      default = "colobus-bramble.ts.net";
      description = "Tailnet MagicDNS domain.";
    };
  };

  den.aspects.system.networkmanager = {
    persist.directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
    ];
    installChecks = [ ''machine.succeed("systemctl is-active NetworkManager.service")'' ];

    nixos =
      { host, ... }:
      {
        networking = {
          networkmanager.enable = true;
          domain = host.lanDomain;
          search = [
            host.tailnetDomain
            host.lanDomain
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
