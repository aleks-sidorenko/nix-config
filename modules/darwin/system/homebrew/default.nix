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
    autoUpdate = mkBoolOpt false "Whether to auto-update Homebrew on activation";
    upgrade = mkBoolOpt false "Whether to upgrade packages on activation";
    cleanup = mkOpt str "zap" "Cleanup strategy: 'none', 'uninstall', or 'zap'";
    taps = mkOpt (listOf str) [ ] "Homebrew taps to add";
    brews = mkOpt (listOf str) [ ] "Homebrew formulae to install";
    casks = mkOpt (listOf (either str attrs)) [ ] "Homebrew casks to install";
  };

  config = mkIf cfg.enable {
    homebrew = {
      enable = true;
      onActivation = {
        inherit (cfg) autoUpdate;
        inherit (cfg) cleanup;
        inherit (cfg) upgrade;
      };
      inherit (cfg) taps;
      inherit (cfg) brews;
      inherit (cfg) casks;
    };

    environment.systemPath = [ "${homebrew.binPath}" ];
  };
}
