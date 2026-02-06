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
    autoUpdate = mkBoolOpt true "Whether to auto-update Homebrew on activation";
    upgrade = mkBoolOpt true "Whether to upgrade packages on activation";
    cleanup = mkOpt str "zap" "Cleanup strategy: 'none', 'uninstall', or 'zap'";
    brews = mkOpt (listOf str) [ ] "Homebrew formulae to install";
    casks = mkOpt (listOf str) [ ] "Homebrew casks to install";
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = cfg.autoUpdate;
        cleanup = cfg.cleanup;
        upgrade = cfg.upgrade;
      };
      brews = cfg.brews;
      casks = cfg.casks;
    };
  };
}
