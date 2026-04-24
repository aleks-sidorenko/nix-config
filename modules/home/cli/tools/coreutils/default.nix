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
  cfg = config.${namespace}.cli.tools.coreutils;
in
{
  options.${namespace}.cli.tools.coreutils = with types; {
    enable = mkBoolOpt false "Whether or not to enable GNU coreutils";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      coreutils
    ];
  };
}
