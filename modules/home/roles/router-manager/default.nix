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
  cfg = config.${namespace}.roles.router-manager;
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.winbox4 ];
  };
}
