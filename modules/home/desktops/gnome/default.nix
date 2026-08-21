{
  config,
  # Optional: absent in standalone homeConfigurations (no NixOS). Defaults to {}
  # so the power-mode read below falls back to "default" outside NixOS.
  osConfig ? { },
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

  # Profile-specific dock options (favoriteApps / allowedApps) are declared by
  # their sole consumer: profiles/adult and profiles/child respectively.
  options.${namespace}.desktops.gnome = {
    enable = mkEnableOption "Enable GNOME desktop environment";
    profile = mkOpt (types.enum [
      "adult"
      "child"
    ]) "adult" "GNOME setup preset: full adult desktop or minimal locked-down child desktop.";
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

        # Power management — driven by nix-config.system.power.mode (single source
        # of truth; see modules/nixos/system/power). An always-on "no-sleep" host
        # must not hibernate on idle.
        "org/gnome/settings-daemon/plugins/power" =
          let
            noSleep = (osConfig.${namespace}.system.power.mode or "default") == "no-sleep";
          in
          {
            sleep-inactive-ac-timeout = if noSleep then 0 else 7200;
            sleep-inactive-ac-type = if noSleep then "nothing" else "hibernate";
            sleep-inactive-battery-timeout = if noSleep then 0 else 1800;
            sleep-inactive-battery-type = if noSleep then "nothing" else "hibernate";
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
