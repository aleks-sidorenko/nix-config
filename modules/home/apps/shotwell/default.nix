{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.apps.shotwell;
in
{
  options.${namespace}.apps.shotwell = {
    enable = mkEnableOption "Enable shotwell program";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      shotwell
    ];
  };
}
