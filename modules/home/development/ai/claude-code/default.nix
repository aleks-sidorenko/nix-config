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
  settingsFile = (pkgs.formats.json { }).generate "claude-settings.json" {
    attribution = {
      commit = "";
      pr = "";
    };
    includeCoAuthoredBy = false;
    effortLevel = "high";
    enabledPlugins = {
      "superpowers@superpowers-marketplace" = true;
      "superpowers@claude-plugins-official" = true;
    };
    alwaysThinkingEnabled = true;
    skipDangerousModePermissionPrompt = true;
  };
in
{
  options.${namespace}.development.ai.claude-code = with types; {
    enable = mkEnableOption "Whether or not to enable claude-code";
  };

  config = mkIf cfg.enable {
    # Agent working docs (superpowers plugin default) — local, never committed
    programs.git.ignores = [ "docs/superpowers/" ];

    home = {
      packages = [
        pkgs.llm-agents.claude-code
      ];

      shellAliases = {
        cl = "claude";
        cly = "claude --dangerously-skip-permissions";
      };

      file.".claude/CLAUDE.md".text = ''
        # Global Guidelines

        ## Communication

        - Be concise and direct — lead with the answer, no filler or flattery.
        - Ask when genuinely ambiguous — prefer a quick clarifying question over guessing on decisions that are hard to reverse.

        ## Coding Principles

        - **DRY** — one source of truth; extract shared logic instead of duplicating it.
        - **YAGNI** — build for current needs, not speculative future ones.
        - **KISS** — prefer the simplest solution that works; boring over clever.
        - **SRP** — a module or function does one thing.
        - **Low coupling & high cohesion** — minimize dependencies between modules; keep related logic together in one place.

        ## Code Style

        - Match surrounding style — follow the conventions already in the file and repo rather than importing your own.
        - Prefer editing existing files over creating new ones; don't add files (docs, scripts) that weren't requested.
        - Avoid self-explanatory comments. Comment only when the reason is hard to guess from the code — explain WHY the code exists, not WHAT it does.

        ## Verification

        - Verify before claiming done — run the build, tests, and lint, and cite the output. Never assert "it works" without evidence.

        ## Safety

        - Never commit secrets — respect existing secret management (SOPS, env, etc.).
        - Confirm before irreversible or outward-facing actions (force-push, deleting data, publishing).

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
      '';

    };

    home.activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      target="${config.home.homeDirectory}/.claude/settings.json"
      run mkdir -p "$(dirname "$target")"
      run install -m 0644 ${settingsFile} "$target"
    '';
  };
}
