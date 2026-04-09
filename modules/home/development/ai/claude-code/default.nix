{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.development.ai.claude-code;
in
{
  options.${namespace}.development.ai.claude-code = with types; {
    enable = mkEnableOption "Whether or not to enable claude-code";
  };

  config = mkIf cfg.enable {
    home = {
      packages = [
        pkgs.llm-agents.claude-code
      ];

      shellAliases = {
        cl = "claude";
        cly = "claude --dangerously-skip-permissions";
      };

      file.".claude/CLAUDE.md".text = ''
        ## Git Commits

        Follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[(scope)][!]: <description>`

        Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`, `ci`, `perf`, `build`. Use `!` or `BREAKING CHANGE:` footer for breaking changes.

        ## Git Branches

        Branch names MUST follow: `<type>/<short-description>`

        - Name the branch after the primary goal of the work, not individual commits
        - Use the same `type` prefixes as commits: `feat/`, `fix/`, `docs/`, `refactor/`, `chore/`, `test/`, `ci/`, `perf/`, `build/`
        - Use kebab-case for the description: `feat/add-wifi-module`, `fix/hyprland-crash`

        ## Pull Requests

        - PR title follows Conventional Commits format, reflecting the primary goal of the work
        - PR branch should be based off `master`

        ## Documentation Structure

        - `docs/specs/` - Feature specifications and requirements
        - `docs/plans/` - Implementation plans
      '';

      file.".claude/settings.json".text = lib.generators.toJSON { } {
        attribution = {
          commit = "";
          pr = "";
        };
        model = "claude-opus-4-6";
        enabledPlugins = {
          "superpowers@superpowers-marketplace" = true;
          "superpowers@claude-plugins-official" = true;
        };
        alwaysThinkingEnabled = true;
        skipDangerousModePermissionPrompt = true;
      };
    };
  };
}
