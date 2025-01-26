{
  config,
  lib,
  ...
}:
with lib;
with lib.nix-config; let
  cfg = config.services.nix-config.k3s;
in {
  options.services.nix-config.k3s = {
    enable = mkEnableOption "Enable The k3s service";
    role = mkOpt (types.nullOr types.str) "server" "Whether this node is a server or agent";
  };

  config = mkIf cfg.enable {
    sops.secrets.k3s_token = {
      sopsFile = ../../roles/kubernetes/secrets.yaml;
    };

    services = {
      k3s = {
        enable = true;
        tokenFile = config.sops.secrets.k3s_token.path;
        extraFlags = ''--kubelet-arg "node-ip=0.0.0.0"'';
        role = mkIf (cfg.role == "agent") "agent";
        # TODO: how can we set this programmatically
        serverAddr = mkIf (cfg.role == "agent") "https://ms01:6443";
      };
    };
  };
}
