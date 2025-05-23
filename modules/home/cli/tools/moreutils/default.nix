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
  cfg = config.${namespace}.cli.tools.moreutils;
in
{
  options.${namespace}.cli.tools.moreutils = with types; {
    enable = mkBoolOpt false "Whether or not to enable moreutils";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      moreutils      
    ];
  };
}
