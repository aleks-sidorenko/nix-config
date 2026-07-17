{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.child;
in
{
  options.${namespace}.roles.child = {
    enable = mkEnableOption "Enable a restricted child account (Minecraft only, no browser)";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "The child role is only supported on NixOS (Linux) systems";
      }
    ];

    ${namespace} = {
      roles = {
        common = enabled;
      };

      # Reuse the existing Minecraft module (installs Prism Launcher).
      games.minecraft = enabled;

      # Minimal, locked-down GNOME (profile = "child"): only the allow-listed
      # apps are pinned to the dock; the app grid + search are hidden and system
      # toggles are locked down (see modules/home/desktops/gnome/profiles/child).
      # The allow-list is sourced from the enabled app modules rather than
      # hardcoded — extend it by enabling more modules that expose a desktop id
      # (or appending literal ids here).
      desktops.gnome = {
        enable = true;
        profile = "child";
        allowedApps =
          optional config.${namespace}.games.minecraft.enable
            config.${namespace}.games.minecraft.desktopId;
      };
    };

    # No browsers, development, communication, or media. Combined with the
    # no-sudo child account, this keeps the child from installing a browser.
    # GNOME is enabled directly (not via roles.graphical) to avoid pulling in
    # browsers/teamviewer/media.
  };
}
