{
  lib,
  config,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.roles.laptop;
in
{
  options.${namespace}.roles.laptop = {
    enable = mkEnableOption "Enable laptop-specific configuration (power management)";
  };

  config = mkIf cfg.enable {
    # Power management tuned for laptops (GNOME-compatible; not tlp, which would
    # conflict with power-profiles-daemon).
    services.power-profiles-daemon.enable = true;

    # Battery/lid awareness for the desktop session.
    services.upower.enable = true;
  };
}
