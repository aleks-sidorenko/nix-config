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
  cfg = config.${namespace}.apps.telegram;
in
{
  options.${namespace}.apps.telegram = {
    enable = mkEnableOption "Enable the Telegram desktop client.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.telegram-desktop ];
  };
}


