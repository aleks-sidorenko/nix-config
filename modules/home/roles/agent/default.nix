{
  config,
  lib,
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
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles.common = enabled;

      # Keyless identity → unsigned commits (mirrors child accounts; honors the
      # single-GPG-root principle). "agent" has no identities/ folder on purpose.
      # Git AUTHOR is inherited from cli.tools.git defaults (the operator's
      # name/email) so commits on shared repos read as the person the agent acts
      # for; they stay unsigned and are re-signed at merge if the repo requires it.
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

      cli.tools.git.urlRewrites = {
        "git@github.com:" = "https://github.com/";
      };
    };

    # Keyless agent → push over HTTPS with GITHUB_TOKEN (injected by the umbrella
    # role). SSH remotes are rewritten to HTTPS via urlRewrites above; gh
    # (from roles.development) already wires programs.gh's credential helper
    # for the HTTPS remote.
    programs.zellij.enable = true;
  };
}
