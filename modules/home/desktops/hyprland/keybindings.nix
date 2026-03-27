{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.hyprland;
  terminal = config.${namespace}.cli.terminals.default.package;
  laptop_lid_switch = pkgs.writeShellScriptBin "laptop_lid_switch" ''
    #!/usr/bin/env bash

    if grep open /proc/acpi/button/lid/LID0/state; then
    		hyprctl keyword monitor "eDP-1, 2256x1504@60, 0x0, 1"
    else
    		if [[ `hyprctl monitors | grep "Monitor" | wc -l` != 1 ]]; then
    				hyprctl keyword monitor "eDP-1, disable"
    		else
    				systemctl suspend
    		fi
    fi
  '';

  resize = pkgs.writeShellScriptBin "resize" ''
    #!/usr/bin/env bash

    # Initially inspired by https://github.com/exoess

    # Getting some information about the current window
    # windowinfo=$(hyprctl activewindow) removes the newlines and won't work with grep
    hyprctl activewindow > /tmp/windowinfo
    windowinfo=/tmp/windowinfo

    # Run slurp to get position and size
    if ! slurp=$(slurp); then
    		exit
    fi

    # Parse the output
    pos_x=$(echo $slurp | cut -d " " -f 1 | cut -d , -f 1)
    pos_y=$(echo $slurp | cut -d " " -f 1 | cut -d , -f 2)
    size_x=$(echo $slurp | cut -d " " -f 2 | cut -d x -f 1)
    size_y=$(echo $slurp | cut -d " " -f 2 | cut -d x -f 2)

    # Keep the aspect ratio intact for PiP
    if grep "title: Picture-in-Picture" $windowinfo; then
    		old_size=$(grep "size: " $windowinfo | cut -d " " -f 2)
    		old_size_x=$(echo $old_size | cut -d , -f 1)
    		old_size_y=$(echo $old_size | cut -d , -f 2)

    		size_x=$(((old_size_x * size_y + old_size_y / 2) / old_size_y))
    		echo $old_size_x $old_size_y $size_x $size_y
    fi

    # Resize and move the (now) floating window
    grep "fullscreen: 1" $windowinfo && hyprctl dispatch fullscreen
    grep "floating: 0" $windowinfo && hyprctl dispatch togglefloating
    hyprctl dispatch moveactive exact $pos_x $pos_y
    hyprctl dispatch resizeactive exact $size_x $size_y
  '';
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      bind = [
        "SUPER, T, exec, ${terminal}"
        "SUPER, D, exec, ${
          lib.getExe config.${namespace}.desktops.addons.rofi.package
        } -show drun -mode drun"
        "SUPER, Q, killactive,"
        "ALT, F4, killactive,"
        "SUPER, F, Fullscreen,0"
        "SUPER, M, fullscreen,1"
        "SUPER, R, exec, ${lib.getExe resize}"
        "SUPER, Space, keyboardlayoutnext,"
        "SUPER, V, exec, ${lib.getExe pkgs.pyprland} toggle pwvucontrol"
        "SUPER_SHIFT, T, exec, ${lib.getExe pkgs.pyprland} toggle term"
        "SUPER_SHIFT, Space, keyboardlayoutprev,"
        ",XF86Launch5, exec, ${lib.getExe pkgs.hyprlock}"
        ",XF86Launch4, exec, ${lib.getExe pkgs.hyprlock}"
        "SUPER,backspace, exec, ${lib.getExe pkgs.hyprlock}"
        "CTRL_SUPER,backspace, exec,wlogout --column-spacing 50 --row-spacing 50"
        ", Print, exec, grimblast --notify copysave area"
        "SHIFT, Print, exec, grimblast --notify copysave active"
        "CONTROL, Print, exec, grimblast --notify copysave screen"
        "SUPER,h, movefocus,l"
        "SUPER,l, movefocus,r"
        "SUPER,k, movefocus,u"
        "SUPER,j, movefocus,d"
        "SUPERCONTROL,h, movecurrentworkspacetomonitor,l"
        "SUPERCONTROL,l, movecurrentworkspacetomonitor,r"
        "SUPERCONTROL,k, movecurrentworkspacetomonitor,u"
        "SUPERCONTROL,j, movecurrentworkspacetomonitor,d"
        "SUPERCONTROL,Left, focusmonitor,l"
        "SUPERCONTROL,Right, focusmonitor,r"
        "SUPERCONTROL,Up, focusmonitor,u"
        "SUPERCONTROL,Down, focusmonitor,d"
        "SUPER,1, workspace,01"
        "SUPER,2, workspace,02"
        "SUPER,3, workspace,03"
        "SUPER,4, workspace,04"
        "SUPER,5, workspace,05"
        "SUPER,6, workspace,06"
        "SUPER,7, workspace,07"
        "SUPER,8, workspace,08"
        "SUPER,9, workspace,09"
        "SUPER,0, workspace,10"
        "SUPERSHIFT,1, movetoworkspacesilent,01"
        "SUPERSHIFT,2, movetoworkspacesilent,02"
        "SUPERSHIFT,3, movetoworkspacesilent,03"
        "SUPERSHIFT,4, movetoworkspacesilent,04"
        "SUPERSHIFT,5, movetoworkspacesilent,05"
        "SUPERSHIFT,6, movetoworkspacesilent,06"
        "SUPERSHIFT,7, movetoworkspacesilent,07"
        "SUPERSHIFT,8, movetoworkspacesilent,08"
        "SUPERSHIFT,9, movetoworkspacesilent,09"
        "SUPERSHIFT,0, movetoworkspacesilent,10"
        "SUPERSHIFT,h, movewindow,l"
        "SUPERSHIFT,l, movewindow,r"
        "SUPERSHIFT,k, movewindow,u"
        "SUPERSHIFT,j, movewindow,d"
        "SUPER,u, togglespecialworkspace"
        "SUPERSHIFT,u, movetoworkspace,special"
      ];
      bindi = [
        ",XF86MonBrightnessUp, exec,  ${lib.getExe pkgs.brightnessctl} +5%"
        ",XF86MonBrightnessDown, exec,  ${lib.getExe pkgs.brightnessctl} -5%"
        ",XF86AudioRaiseVolume, exec,  ${lib.getExe pkgs.pamixer} -i 5"
        ",XF86AudioLowerVolume, exec,  ${lib.getExe pkgs.pamixer} -d 5"
        ",XF86AudioMute, exec,  ${lib.getExe pkgs.pamixer} --toggle-mute"
        ",XF86AudioMicMute, exec,  ${lib.getExe pkgs.pamixer} --default-source --toggle-mute"
        ",XF86AudioNext, exec,playerctl next"
        ",XF86AudioPrev, exec,playerctl previous"
        ",XF86AudioPlay, exec,playerctl play-pause"
        ",XF86AudioStop, exec,playerctl stop"
      ];
      bindl = [
        ",switch:Lid Switch, exec, ${lib.getExe laptop_lid_switch}"
      ];
      binde = [
        "SUPERALT, h, resizeactive, -20 0"
        "SUPERALT, l, resizeactive, 20 0"
        "SUPERALT, k, resizeactive, 0 -20"
        "SUPERALT, j, resizeactive, 0 20"
      ];
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
