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
    favoriteApps =
      mkOpt (types.listOf types.str) [ ]
        "List of desktop file names (without .desktop) to add to GNOME dock";
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
            # "just-perfection-desktop@just-perfection"
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
          show-temperature = true; # CPU/GPU temp
          show-voltage = false; # Disable voltage (usually irrelevant)
          show-fan = true; # Fan speed (if supported)
          show-memory = true; # RAM usage
          show-processor = true; # CPU usage
          show-storage = true; # Disk usage
          hot-sensors = [ "CPU" ]; # Which temps to show (e.g., "CPU", "GPU")
          position-in-panel = "right"; # "left", "center", "right"
          refresh-time = 2; # Update interval (seconds)

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
