{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.homebook;
in
{
  options.${namespace}.roles.homebook = {
    enable = mkEnableOption "Enable homebook (shared desktop-class laptop) configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # A homebook is a desktop-class laptop: reuse the desktop role wholesale.
      roles.desktop = enabled;
    };

    # Laptop power management (stock NixOS, GNOME-compatible; not tlp, which
    # would conflict with power-profiles-daemon).
    services.power-profiles-daemon.enable = true;
  };
}
