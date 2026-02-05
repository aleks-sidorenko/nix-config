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
  cfg = config.${namespace}.development.database.mysql;
in
{
  options.${namespace}.development.database.mysql = with types; {
    enable = mkEnableOption "Whether or not to enable MySQL database client";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      mariadb.client
    ];
  };
}
