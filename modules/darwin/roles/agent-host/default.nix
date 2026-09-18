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
in
{
  # Power only, for now: macOS cannot host the rest of the always-on agent
  # setup. Accounts are org-managed and darwin cannot create them (see
  # modules/darwin/users), so there is no dedicated agent user to provision and
  # nothing to apply roles.agent to; the Tailscale SSH server is Linux-only.
  options.${namespace}.roles.agent-host = with types; {
    enable = mkEnableOption "Enable the always-on agent host role";
    powerMode = mkOpt (enum [
      "no-sleep"
      "default"
    ]) "no-sleep" "Power behavior for this host (see nix-config.system.power).";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles.common = enabled;

      system.power.mode = cfg.powerMode;
    };
  };
}
