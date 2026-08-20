{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.agent;
in
{
  options.${namespace}.roles.agent = with types; {
    enable = mkEnableOption "Enable the headless agent home suite (development + zellij + claude-code)";
    gitEmail = mkStringOpt "agent@users.noreply.github.com" "Git author email for the agent's commits";
    gitFullName = mkStringOpt "nix-config agent" "Git author name for the agent's commits";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles.common = enabled;

      # Keyless identity → unsigned commits (mirrors child accounts; honors the
      # single-GPG-root principle). "agent" has no identities/ folder on purpose.
      security.identity.name = "agent";

      roles.development = {
        enable = true;
        ai = {
          copilot = false;
          claude-code = true;
        };
        languages = {
          typescript = true;
          python = true;
        };
      };

      cli.tools.git = {
        email = cfg.gitEmail;
        fullName = cfg.gitFullName;
      };
    };

    # Keyless agent → push over HTTPS with GH_TOKEN (injected by the umbrella
    # role). Rewrite SSH remotes to HTTPS and let gh serve credentials.
    programs.git.settings = {
      url."https://github.com/".insteadOf = "git@github.com:";
      credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
    };

    programs.zellij.enable = true;
  };
}
