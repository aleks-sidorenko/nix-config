{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.common;
in
{
  options.${namespace}.roles.common = with types; {
    enable = mkEnableOption "Enable common darwin configuration";
    homebrew = {
      brews = mkOpt (listOf str) [ ] "Additional Homebrew formulae";
      casks = mkOpt (listOf str) [ ] "Additional Homebrew casks";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      system = {
        nix.enable = true;
        # Darwin (macOS) UI preferences (MDM may override some)
        defaults.enable = true;

        # Homebrew for CLI tools and GUI apps
        homebrew = {
          enable = true;
          brews = cfg.homebrew.brews;
          casks = cfg.homebrew.casks;
        };
      };

      cli = {
        terminals.ghostty.enable = true;

        tools.nh = {
          enable = true;
          clean.enable = true;
        };
      };

      user.enable = true;
    };
  };
}
