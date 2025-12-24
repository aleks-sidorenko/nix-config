{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.backup-server;
in
{
  options.${namespace}.roles.backup-server = {
    enable = mkEnableOption "Enable backup server role.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      services = {
        backup = {
          restic-server = {
            enable = true;
            auth.enable = true;
          };
        };
      };
    };
  };
}
