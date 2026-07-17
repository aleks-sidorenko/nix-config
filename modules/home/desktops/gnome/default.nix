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
  imports = lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.desktops.gnome = {
    enable = mkEnableOption "Enable GNOME desktop environment";
    profile = mkOpt (types.enum [
      "adult"
      "child"
    ]) "adult" "GNOME setup preset: full adult desktop or minimal locked-down child desktop.";
    favoriteApps =
      mkOpt (types.listOf types.str) [ ]
        "Desktop file names (without .desktop) pinned to the dock on the adult profile.";
    allowedApps =
      mkOpt (types.listOf types.str) [ ]
        "Desktop file names (without .desktop) that make up the dock on the child profile.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services.kdeconnect.enable = lib.mkForce false;
      desktops = {
        addons = {
          gtk.enable = true;
          xdg.enable = true;
          nautilus.enable = true;
        };
        gnome.addons = {
          enable = true;
        };
      };
    };

    stylix.targets.gnome.enable = true; # Enable Stylix for GNOME

    # Configure GNOME display settings via dconf
    dconf.settings =
      let
        inherit (lib.gvariant) mkTuple;
        localeLayouts = config.${namespace}.system.locale.layouts;
        inputSources = map (
          layout:
          mkTuple [
            "xkb"
            layout
          ]
        ) localeLayouts;
      in
      {

        "org/gnome/desktop/interface" = {

          enable-animations = true;
          enable-hot-corners = false;

        };

        "org/gnome/desktop/input-sources" = {
          per-window = true;
          sources = inputSources;
          xkb-options = [ "grp:win_space_toggle" ];
        };

        "org/gnome/desktop/wm/preferences" = {
          focus-mode = "sloppy";
        };

        # Power management settings
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-timeout = 7200; # 2 hours (7200 seconds) when plugged in
          sleep-inactive-ac-type = "hibernate"; # hibernate when timeout is reached
          sleep-inactive-battery-timeout = 1800; # 30 minutes on battery
          sleep-inactive-battery-type = "hibernate"; # hibernate on battery timeout
        };

        "org/gnome/desktop/session" = {
          idle-delay = 900; # Screen blank/lock after 15 minutes (900 seconds)
        };

      };

    # ssh-agent workaround
    home.sessionVariables = {
      GSM_SKIP_SSH_AGENT_WORKAROUND = "1"; # Prevent clobbering SSH_AUTH_SOCK
    };

    # Disable gnome-keyring ssh-agent
    xdg.configFile."autostart/gnome-keyring-ssh.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=SSH Key Agent
      Comment=GNOME Keyring: SSH Agent
      Exec=/usr/bin/gnome-keyring-daemon --start --components=ssh
      OnlyShowIn=GNOME;Unity;
      Hidden=true
    '';

    xdg.portal = {
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
      ];
      configPackages = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
      ];
    };
  };
}
