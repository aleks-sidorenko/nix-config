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
          kb_layout = config.${namespace}.system.locale.layouts;
          kb_options = "grp:win_space_toggle";
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

        monitor =
          let
            waybarSpace =
              let
                inherit (config.wayland.windowManager.hyprland.settings.general) gaps_in gaps_out;
                inherit (config.programs.waybar.settings.primary) position height width;
                gap = gaps_out - gaps_in;
              in
              {
                top = if (position == "top") then height + gap else 0;
                bottom = if (position == "bottom") then height + gap else 0;
                left = if (position == "left") then width + gap else 0;
                right = if (position == "right") then width + gap else 0;
              };
          in
          [
            # ",addreserved,${toString waybarSpace.top},${toString waybarSpace.bottom},${toString waybarSpace.left},${toString waybarSpace.right}"
          ]
          ++ (map (
            m:
            "${m.name},${
              if m.enabled then
                "${toString m.width}x${toString m.height}@${toString m.refreshRate},${m.position},${m.scale}"
              else
                "disable"
            }"
          ) monitors);

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
        ]
        ++ cfg.execOnceExtras;
      };
    };
  };
}
