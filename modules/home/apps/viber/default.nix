{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.viber;
in
{
  options.${namespace}.apps.viber = {
    enable = mkEnableOption "Enable the Viber desktop client.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.viber ];
  };
}


