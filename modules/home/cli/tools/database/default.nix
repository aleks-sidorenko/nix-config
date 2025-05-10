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
  cfg = config.${namespace}.cli.tools.database;
in
{
  options.${namespace}.cli.tools.database = with types; {
    enable = mkBoolOpt false "Whether or not to manage database";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      dbeaver-bin
      termdbms
    ];
  };
}
