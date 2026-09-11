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
    # Homebrew 6 removed `brew bundle --cleanup` ("no replacement"), and any
    # value other than "none" makes nix-darwin pass that now-fatal switch during
    # activation. Keep "none" until nix-darwin adapts to Homebrew 6. Safe here
    # because our managed tools (e.g. pass) come from Nix, not manual brews.
    cleanup =
      mkOpt str "none"
        "Cleanup strategy: 'none', 'uninstall', or 'zap' (see note: >none breaks on Homebrew 6)";
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
