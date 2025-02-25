{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.cli.tools.bat;
in {
  options.${namespace}.cli.tools.bat = with types; {
    enable = mkBoolOpt false "Whether or not to enable bat";
  };

  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;
    };
  };
}
