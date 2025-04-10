{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps.discord;
in
{
  options.${namespace}.apps.discord = with types; {
    enable = mkBoolOpt false "Whether or not to manage discord";
  };

  config = mkIf cfg.enable {
    xdg.configFile."BetterDiscord/data/stable/custom.css" = {
      source = ./custom.css;
    };
    home.packages = with pkgs; [ goofcord ];
  };
}
