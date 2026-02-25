{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.defaults;
in
{
  options.${namespace}.system.defaults = with types; {
    enable = mkBoolOpt false "Whether to manage Darwin (macOS) defaults (MDM may override)";
  };

  config = mkIf cfg.enable {
    # These may be overridden by MDM policies
    system.defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
        show-recents = false;
        tilesize = 48;
      };
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXEnableExtensionChangeWarning = false;
        _FXShowPosixPathInTitle = true;
      };
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
    };
  };
}
