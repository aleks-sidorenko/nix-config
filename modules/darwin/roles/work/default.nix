{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.work;
in
{
  options.${namespace}.roles.work = with types; {
    enable = mkEnableOption "Enable work configuration";

    homebrew = {
      brews = mkOpt (listOf str) [ ] "Additional Homebrew formulae";
      casks = mkOpt (listOf str) [ ] "Additional Homebrew casks";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Inherit common configuration
      roles.common = enabled;

      # Homebrew for CLI tools and GUI apps
      system.homebrew = {
        enable = true;
        brews = cfg.homebrew.brews;
        casks = cfg.homebrew.casks;
      };

      # Enable claude-code CLI for development
      cli.tools.claude-code.enable = true;
    };
  };
}
