{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome;
in
{
  imports = lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.desktops.gnome = {
    enable = mkEnableOption "Enable GNOME desktop environment";
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
    dconf.settings = {

      "org/gnome/desktop/interface" = {

        enable-animations = true;
        enable-hot-corners = false;

      };

      "org/gnome/desktop/wm/preferences" = {
        focus-mode = "sloppy";
      };

      "org/gnome/shell" = {
        disable-user-extensions = false;

        favorite-apps =
          let
          in
          [ "org.gnome.Nautilus.desktop" ]
          ++
            optional config.${namespace}.browsers.default.enable
              "${config.${namespace}.browsers.default.name}.desktop"
          ++
            optional config.${namespace}.cli.terminals.default.enable
              "${config.${namespace}.cli.terminals.default.name}.desktop";

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

    };

    # ssh-agent workaround
    home.sessionVariables = {
      GSM_SKIP_SSH_AGENT_WORKAROUND = "1"; # Prevent clobbering SSH_AUTH_SOCK
    };

    # Disable gnome-keyring ssh-agent
    xdg.configFile."autostart/gnome-keyring-ssh.desktop".text = ''
      ${lib.fileContents "${pkgs.gnome-keyring}/etc/xdg/autostart/gnome-keyring-ssh.desktop"}
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
