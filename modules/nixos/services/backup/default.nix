{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.backup;
in
{
  options.${namespace}.services.backup = {
    # Common backup group for all backup services
    group = lib.mkOption {
      type = types.str;
      default = "backup";
      description = "Group for backup services";
    };
  };

  config = {
    # Create backup group if any backup service is enabled
    users.groups.${cfg.group} = mkIf (
      config.${namespace}.services.backup.restic.enable
      || config.${namespace}.services.backup.restic-server.enable
    ) { };
  };
}
