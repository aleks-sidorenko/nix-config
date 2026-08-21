{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.virtualisation.vagrant;
in
{
  options.${namespace}.services.virtualisation.vagrant = {
    enable = mkEnableOption "Enable Vagrant";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.vagrant ];
  };
}
