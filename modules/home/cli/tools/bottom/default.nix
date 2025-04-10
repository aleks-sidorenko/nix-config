{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.bottom;
in
{
  options.${namespace}.cli.tools.bottom = with types; {
    enable = mkBoolOpt false "Whether or not to enable bottom";
  };

  config = mkIf cfg.enable {
    programs.bottom = {
      enable = true;
    };
  };
}
