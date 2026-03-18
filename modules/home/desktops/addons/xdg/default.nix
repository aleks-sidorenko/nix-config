{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.addons.xdg; # TODO - use media.offices.default.writer # TODO - use media.offices.default.calc # TODO - use media.offices.default.impress

  # Extensive list of associations here:
  # https://github.com/iggut/GamiNiX/blob/8070528de419703e13b4d234ef39f05966a7fafb/system/desktop/home-main.nix#L77

in
{
  options.${namespace}.desktops.addons.xdg = with types; {
    enable = mkBoolOpt false "Enable XDG config. This includes user directories, session variables, and MIME type associations";
    associations = mkOption {
      type = attrsOf (listOf str);
      default = { };
      description = "MIME type associations to add";
    };
    removals = mkOption {
      type = attrsOf (listOf str);
      default = { };
      description = "MIME type associations to remove";
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      GTK2_RC_FILES = lib.mkForce "${config.xdg.configHome}/gtk-2.0/gtkrc";
    };

    xdg = {
      enable = true;
      cacheHome = config.home.homeDirectory + "/.local/cache";

      configFile."mimeapps.list".force = true;

      mimeApps = {
        enable = true;

        associations = {
          added = cfg.associations;
          removed = cfg.removals;
        };
        defaultApplications = cfg.associations;

      };

      userDirs = {
        enable = true;
        createDirectories = true;
        extraConfig = {
          XDG_SCREENSHOTS_DIR = "${config.xdg.userDirs.pictures}/Screenshots";
        };
      };

      autostart.enable = true;
      portal = {
        enable = true;
      };
    };
  };
}
