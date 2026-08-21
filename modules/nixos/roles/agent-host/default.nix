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
  tokenSecret = "user-agent-github-token";
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
      # A headless agent host needs the base system (sshd, sops, boot, networking,
      # impermanence). Idempotent on hosts that already enable common (e.g. desktop).
      roles.common = enabled;

      system.power.mode = cfg.powerMode;

      services.networking.tailscale = {
        enable = true;
        ssh = true;
      };

      # Dedicated, isolated account: admin = false → no wheel → cannot sudo.
      # (profile defaults to "adult"; non-primary by default.)
      users.${cfg.agentUser} = {
        admin = false;
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
    # GITHUB_TOKEN from the NixOS secret path.
    home-manager.users.${cfg.agentUser} = {
      _module.args.namespace = namespace;
      nix-config.roles.agent = enabled;
      home.stateVersion = "25.05";
      home.sessionVariables = mkIf sopsEnabled {
        GITHUB_TOKEN = "$(cat ${config.sops.secrets.${tokenSecret}.path})";
      };
    };
  };
}
