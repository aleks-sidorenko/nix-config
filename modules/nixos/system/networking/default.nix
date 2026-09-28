{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.networking;
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    domains = {
      lan = mkOpt str defaults.network.domains.lan "LAN domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };

  };

  config = mkIf cfg.enable {
    ${namespace} = {
      disks.impermanence.directories = [
        "/etc/NetworkManager/system-connections"
      ];
    };

    networking = {
      useDHCP = mkDefault true;
      # Let NetworkManager manage the network interfaces. It also manages
      # networking.wireless itself (enables wpa_supplicant under DBus control on
      # 26.05+), so don't set wireless.enable here.
      networkmanager.enable = true;

      # Set the domain to the LAN domain
      domain = mkForce cfg.domains.lan;

      # MagicDNS owns bare names; the router's lan zone is the on-LAN fallback
      # when the tailnet is unavailable.
      search = mkForce [
        defaults.network.domains.tailnet
        cfg.domains.lan
      ];

      firewall = {
        enable = false; # TODO: enable firewall
      };
    };

    boot.kernel.sysctl = {
      # TCP BBR significantly increases throughput and reduces latency
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

  };

}
