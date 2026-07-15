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
      # A homebook is a desktop-class laptop: reuse the desktop role wholesale
      # plus the laptop role for power management.
      roles = {
        desktop = enabled;
        laptop = enabled;
      };
    };
  };
}
