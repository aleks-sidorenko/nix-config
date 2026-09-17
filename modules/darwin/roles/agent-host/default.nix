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
  # Darwin counterpart of modules/nixos/roles/agent-host. Same option surface,
  # but for now only the power side is implemented: the machine stays awake so a
  # long-running agent session isn't cut short by idle sleep (and the VPN with
  # it). The NixOS role's other pieces are deliberately absent because macOS
  # can't host them as-is:
  #   * the dedicated keyless `agent` account — darwin cannot create accounts
  #     (they are macOS/org-managed; see modules/darwin/users), so there is no
  #     home to apply roles.agent to;
  #   * Tailscale SSH — the Tailscale SSH *server* is Linux-only;
  #   * the SOPS `user-agent-github-token` — it exists to serve that account.
  options.${namespace}.roles.agent-host = with types; {
    enable = mkEnableOption "Enable the always-on agent host role";
    powerMode = mkOpt (enum [
      "no-sleep"
      "default"
    ]) "no-sleep" "Power behavior for this host (see nix-config.system.power).";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Idempotent on hosts that already enable common (e.g. work).
      roles.common = enabled;

      system.power.mode = cfg.powerMode;
    };
  };
}
