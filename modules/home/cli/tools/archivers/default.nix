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
  cfg = config.${namespace}.cli.tools.archivers;
in
{
  options.${namespace}.cli.tools.archivers = with types; {
    enable = mkBoolOpt false "Whether or not to enable archivers";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      zip
      unzip
      xz
    ];
  };
}
