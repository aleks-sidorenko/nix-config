{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.aerospace;
in
{
  options.${namespace}.desktops.aerospace = with types; {
    enable = mkBoolOpt false "Enable AeroSpace tiling window manager";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.homebrew = {
      taps = [ "nikitabobko/tap" ];
      casks = [ "nikitabobko/tap/aerospace" ];
    };

    # Disable macOS Sequoia's built-in window tiling to prevent conflicts
    # with AeroSpace and terminal emulator keybindings (e.g. Ghostty tab switching)
    system.defaults.CustomUserPreferences."com.apple.WindowManager" = {
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      EnableTilingOptionAccelerator = false;
    };
  };
}
