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
    # Headless account: no D-Bus session bus, so home-manager's dconf activation
    # (pulled in by stylix theming via roles.common) can't reach ca.desrt.dconf
    # and aborts activation. The agent has no GUI, so skip dconf load entirely;
    # the settings stylix declares simply become a no-op.
    dconf.enable = false;

    ${namespace} = {
      roles.common = enabled;

      # Keyless identity → unsigned commits (mirrors child accounts; honors the
      # single-GPG-root principle). Reference the account name via home-manager
      # instead of hardcoding; it resolves to the agent user, which has no
      # identities/ folder, so no key material is pulled in. Git AUTHOR is
      # inherited from cli.tools.git defaults (the operator's name/email) so
      # commits on shared repos read as the person the agent acts for; they stay
      # unsigned and are re-signed at merge if the repo requires it.
      security.identity.name = config.home.username;

      roles.development = {
        enable = true;
        ai = {
          copilot = false;
          claude-code = true;
        };
        # Languages are NOT hardcoded here — the agent-host umbrella role mirrors
        # the primary user's development languages so the agent's toolchain
        # matches the operator it acts for.
      };

      # Keyless agent → push over HTTPS with GITHUB_TOKEN (injected by the
      # umbrella role); rewrite ssh remotes to https and let gh (from
      # roles.development) serve credentials.
      cli.tools.git.urlRewrites = {
        "git@github.com:" = "https://github.com/";
      };
    };

    # Keyless account has no ssh key, so gh must clone/operate over https
    # (matches the git urlRewrites above and the agent-host credential helper).
    programs.gh.settings.git_protocol = "https";
  };
}
