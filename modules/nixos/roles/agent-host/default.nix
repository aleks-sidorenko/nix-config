{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.agent-host;
  operatorKey = (resolveIdentity config).sshPublicKey;
  sopsEnabled = config.${namespace}.security.sops.enable;
  tokenSecret = "agent-gh-token";
in
{
  options.${namespace}.roles.agent-host = with types; {
    enable = mkEnableOption "Enable the always-on agent host role";
    agentUser = mkStringOpt "agent" "Name of the dedicated, non-admin agent account";
    powerMode = mkOpt (enum [
      "no-sleep"
      "default"
    ]) "no-sleep" "Power behavior for this host (see nix-config.system.power).";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      system.power.mode = cfg.powerMode;

      services.networking.tailscale = {
        enable = true;
        ssh = true;
      };

      # Dedicated, isolated account. Non-admin → no wheel → cannot sudo.
      users.${cfg.agentUser} = {
        primary = false;
        admin = false;
        profile = "adult";
      };
    };

    # Operator SSH *public* key → agent authorized_keys (ssh agent@host with the
    # operator key, over LAN / tailnet IP, alongside Tailscale SSH).
    users.users.${cfg.agentUser}.openssh.authorizedKeys.keys = optional (
      operatorKey != null
    ) operatorKey;

    # Agent GitHub token via NixOS SOPS (host age key), owned by the agent user.
    sops.secrets.${tokenSecret} = mkIf sopsEnabled {
      sopsFile = ../../secrets.yaml;
      owner = cfg.agentUser;
      mode = "0400";
    };

    # Provision the agent home inline (no per-host homes/ file needed) and inject
    # GH_TOKEN from the NixOS secret path.
    home-manager.users.${cfg.agentUser} = {
      nix-config.roles.agent = enabled;
      home.stateVersion = "25.05";
      home.sessionVariables = mkIf sopsEnabled {
        GH_TOKEN = "$(cat ${config.sops.secrets.${tokenSecret}.path})";
      };
    };
  };
}
