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
    terminal = mkOption {
      type = types.str;
      default = "ghostty";
      description = "Default terminal to use in GNOME";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services.kdeconnect.enable = lib.mkForce false;
      desktops = {
        addons = {
          gtk.enable = true;
        };
        gnome.addons = {
          gnome.enable = true;
        };
      };
    };

    home.packages = with pkgs; [
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
    ];

    dconf.settings = {

      "org/gnome/desktop/interface" = {
        enable-hot-corners = false;
      };

      "org/gnome/shell" = {
        disable-user-extensions = false;

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
        ];
      };

      "org/gnome/shell/extensions/appindicator" = {
        legacy-tray-enabled = true;
      };

      "org/gnome/desktop/wm/preferences" = {
        focus-mode = "sloppy";
      };

      "org/gnome/shell/keybindings/toggle-application-view" = {
        "@as" = [ ];
      };

    };

    home.sessionVariables = {
      GSM_SKIP_SSH_AGENT_WORKAROUND = 1; # Skip workaround for SSH agent in GNOME
    };

  };
}
