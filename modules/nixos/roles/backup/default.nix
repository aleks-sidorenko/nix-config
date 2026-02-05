{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.backup;
in
{
  options.${namespace}.roles.backup = {
    enable = mkEnableOption "Enable backup client role";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services = {
        backup = {
          restic.enable = true;
        };
      };
    };
  };
}
