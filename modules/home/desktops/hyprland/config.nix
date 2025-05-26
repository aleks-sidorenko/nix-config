{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
#with lib.${namespace};
let
  cfg = config.${namespace}.desktops.hyprland;
  inherit (config.lib.stylix) colors;

  monitors =
    let
      cfg = config.${namespace}.desktops.monitors;
    in
    lib.optionals cfg.enable cfg.devices;

in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;

      systemd.enable = true;
      systemd.enableXdgAutostart = true;
      xwayland.enable = true;

      settings = {
        input = {
          kb_layout = config.${namespace}.system.locale.layout;
          touchpad = {
            disable_while_typing = false;
          };
        };

        general = {
          gaps_in = 3;
          gaps_out = 5;
          border_size = 3;
        };

        decoration = {
          rounding = 5;
        };

        misc =
          let
            FULLSCREEN_ONLY = 2;
          in
          {
            vrr = FULLSCREEN_ONLY;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            force_default_wallpaper = 0;
          };

        monitor = (
          map (
            m:
            "${m.name},${
              if m.enabled then
                "${toString m.width}x${toString m.height}@${toString m.refreshRate},${m.position},${m.scale}"
              else
                "disable"
            }"
          ) monitors
        );

        workspace = map (m: "name:${m.workspace},monitor:${m.name}") (
          filter (m: m.enabled && m.workspace != null) monitors
        );

        exec-once = [
          "dbus-update-activation-environment --systemd --all"
          "systemctl --user import-environment QT_QPA_PLATFORMTHEME"
          "${pkgs.kanshi}/bin/kanshi"
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
          "${pkgs.pyprland}/bin/pypr"
          "${pkgs.clipse}/bin/clipse -listen"
          "${pkgs.solaar}/bin/solaar -w hide"
          "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator"
        ] ++ cfg.execOnceExtras;
      };
    };
  };
}
