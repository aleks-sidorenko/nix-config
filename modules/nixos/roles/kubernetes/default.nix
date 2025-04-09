{
  lib,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.roles.kubernetes;
in {
  options.${namespace}.roles.kubernetes = {
    enable = mkEnableOption "Enable kubernetes configuration";
    role = mkOpt (types.nullOr types.str) "server" "Whether this node is a server or agent";
  };

  config = mkIf cfg.enable {
    roles = {
      server.enable = true;
    };

    services = {
      nix-config.k3s = {
        enable = true;
        inherit (cfg) role;
      };
    };

    networking.firewall = lib.mkForce {
      enable = true;
      allowedUDPPorts = [
        53
        8472
      ];

      allowedTCPPorts = [
        22
        53
        6443
        6444
        9000
      ];
    };
  };
}
