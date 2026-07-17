{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.gnome;
in
{
  config = mkIf (cfg.enable && cfg.profile == "child") {
    # Minimal extension set: user-theme for stylix shell theming, and
    # just-perfection to hide the app-grid button + overview search.
    home.packages = with pkgs; [
      gnomeExtensions.user-themes
      gnomeExtensions.just-perfection
    ];

    # Hide GNOME Settings (Control Center) from the app grid / search.
    xdg.desktopEntries."org.gnome.Settings" = {
      name = "Settings";
      exec = "gnome-control-center";
      noDisplay = true;
    };

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        favorite-apps = map (app: "${app}.desktop") cfg.allowedApps;
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "just-perfection-desktop@just-perfection"
        ];
      };

      # Hide the app grid button and overview search: only the pinned
      # allowedApps (dock) are reachable.
      "org/gnome/shell/extensions/just-perfection" = {
        show-apps-button = false;
        search = false;
      };

      # Also drop the default Super+A binding so the app grid can't be reached
      # by keyboard (just-perfection only hides the button/search).
      "org/gnome/shell/keybindings" = {
        toggle-application-view = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };

      # Lockdown: no Alt+F2 run dialog, no user administration.
      "org/gnome/desktop/lockdown" = {
        disable-command-line = true;
        user-administration-disabled = true;
      };
    };
  };
}
