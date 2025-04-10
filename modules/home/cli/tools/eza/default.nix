{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.eza;
in
{
  options.${namespace}.cli.tools.eza = with types; {
    enable = mkBoolOpt false "Whether or not to enable eza";
  };

  config = mkIf cfg.enable {
    programs.eza = {
      enable = true;
    };
  };
}
