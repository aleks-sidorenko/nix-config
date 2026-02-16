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
  cfg = config.${namespace}.services.teamviewer;
in
{
  options.${namespace}.services.teamviewer = {
    enable = mkEnableOption "Enable TeamViewer remote desktop client";
  };

  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [ pkgs.teamviewer ];
  };
}
