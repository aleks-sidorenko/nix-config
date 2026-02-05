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
  cfg = config.${namespace}.communication.zoom;
in
{
  options.${namespace}.communication.zoom = {
    enable = mkEnableOption "Enable the Zoom video conferencing client";
  };

  # Linux only - Darwin uses homebrew casks via darwin/roles/work
  config = mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = [ pkgs.zoom-us ];
  };
}
