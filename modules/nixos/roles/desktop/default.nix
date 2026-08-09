{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.desktop;
in
{
  options.${namespace}.roles.desktop = {
    enable = mkEnableOption "Enable the desktop host (root role)";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # A desktop is a graphical machine. Development lives on the home side
      # (see the home `desktop` role).
      roles = {
        graphical = enabled;
      };

      hardware.phone = enabled;

      # Virtualisation is desktop-specific (not wanted on the family laptop).
      services = {
        virtualisation = {
          virtualbox = enabled;
          podman = enabled;
        };
      };
    };
  };
}
