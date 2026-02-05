{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.homebrew;
in
{
  options.${namespace}.system.homebrew = with types; {
    enable = mkBoolOpt false "Whether to manage Homebrew";
    brews = mkOpt (listOf str) [ ] "Homebrew formulae to install";
    casks = mkOpt (listOf str) [ ] "Homebrew casks to install";
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false; # Don't auto-update on activation
        cleanup = "zap"; # Remove unlisted casks
        upgrade = false; # Don't auto-upgrade
      };
      brews = cfg.brews;
      casks = cfg.casks;
    };
  };
}
