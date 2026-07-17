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
  config = mkIf (cfg.enable && cfg.profile == "adult") {
    home.packages = with pkgs; [
      dconf-editor
      gnome-tweaks
      gnomeExtensions.user-themes
      gnomeExtensions.space-bar
      gnomeExtensions.hibernate-status-button
      gnomeExtensions.forge
      gnomeExtensions.appindicator
      gnomeExtensions.just-perfection
      gnomeExtensions.pano
      gnomeExtensions.search-light
      gnomeExtensions.gsconnect
      gnomeExtensions.caffeine
      gnomeExtensions.launch-new-instance
      gnomeExtensions.vitals
    ];

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        favorite-apps = [ "org.gnome.Nautilus.desktop" ] ++ map (app: "${app}.desktop") cfg.favoriteApps;
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
          "space-bar@luchrioh"
          "hibernate-status@dromi"
          "appindicatorsupport@rgcjonas.gmail.com"
          "forge@jmmaranan.com"
          "pano@elhan.io"
          "search-light@icedman.github.com"
          "gsconnect@andyholmes.github.io"
          "caffeine@patapon.info"
          "Vitals@CoreCoding.com"
        ];
      };

      "org/gnome/shell/extensions/appindicator" = {
        legacy-tray-enabled = true;
      };

      "org/gnome/shell/extensions/vitals" = {
        show-temperature = true;
        show-voltage = false;
        show-fan = true;
        show-memory = true;
        show-processor = true;
        show-storage = true;
        hot-sensors = [ "CPU" ];
        position-in-panel = "right";
        refresh-time = 2;
      };
    };
  };
}
