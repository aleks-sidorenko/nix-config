{ inputs, ... }:
{
  flake.modules.nixos.networking =
    { config, lib, ... }:
    let
      inherit (config.constants.network) domains;
    in
    {
      imports = [ inputs.self.modules.nixos.networking-names ];

      networking = {
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
        domain = lib.mkForce domains.lan;
        search = lib.mkForce [
          domains.tailnet
          domains.lan
        ];
        firewall.enable = lib.mkDefault false;
      };

      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
    };
}
