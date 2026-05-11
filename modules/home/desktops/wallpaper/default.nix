{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.desktops.wallpaper;
in
{
  options.${namespace}.desktops.wallpaper = {
    enable = lib.mkEnableOption "Apply stylix.image as the desktop wallpaper on macOS";
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin && config.stylix.image != null) {
    home.activation.setWallpaper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      /usr/bin/osascript -e '
        tell application "System Events"
          tell every desktop to set picture to "${config.stylix.image}"
        end tell
      '
    '';
  };
}
