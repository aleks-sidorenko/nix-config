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
    home.packages = with pkgs; [
      claude-code
    ];

    home.file.".claude/CLAUDE.md".text = ''
      ## Git Commits

      Follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[(scope)][!]: <description>`

      Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`, `ci`, `perf`, `build`. Use `!` or `BREAKING CHANGE:` footer for breaking changes.
    '';
  };
}
