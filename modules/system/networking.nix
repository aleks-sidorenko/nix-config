{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.networking).config;
in
{
  flake.modules.nixos.networking =
    { config, lib, ... }:
    let
      inherit (config.constants.network) domains;
    in
    {
      options.nix-config.networking.names = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "DNS names this host answers to, contributed by the services that own them.";
      };

      config.networking = {
        useDHCP = lib.mkDefault true;
        networkmanager.enable = true;
        domain = lib.mkForce domains.lan;
        search = lib.mkForce [
          domains.tailnet
          domains.lan
        ];
        firewall.enable = lib.mkDefault false;
      };

      config.boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
    };

  evalTests.networking-names-default = {
    expr = c.nix-config.networking.names;
    expected = [ ];
  };
}
