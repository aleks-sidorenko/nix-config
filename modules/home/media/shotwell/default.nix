{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.media.shotwell;
in
{
  options.${namespace}.media.shotwell = {
    enable = mkEnableOption "Enable shotwell program";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      shotwell
    ];
  };
}
