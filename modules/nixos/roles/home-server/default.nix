{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.home-server;
in
{
  options.${namespace}.roles.home-server = {
    enable = mkEnableOption "Enable home server role.";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      roles = {
        common = enabled;
        server = enabled;
        media-server = enabled;
        smart-home = enabled;
        gaming-server = enabled;
        backup-server = enabled;
        # backup = enabled;
      };
    };

  };
}
