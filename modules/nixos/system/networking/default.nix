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
      local = mkOpt str defaults.network.domains.local "Local domain for intranet resolution";
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

      # Set the domain to the local domain
      domain = mkForce cfg.domains.local;

      search = mkForce [
        cfg.domains.local
      ];

      hosts = mkForce (
        lib.mapAttrs' (
          host: ip:
          lib.nameValuePair ip [
            host
            "${host}.${cfg.domains.local}"
          ]
        ) defaults.network.hosts
      );

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
