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
      # A homebook is a graphical laptop: the shared graphical suite plus the
      # laptop role for power management (no development).
      roles = {
        graphical = enabled;
        laptop = enabled;
      };
    };
  };
}
