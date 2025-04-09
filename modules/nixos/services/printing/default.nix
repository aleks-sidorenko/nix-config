{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.services.${namespace}.printing;
in {
  options.services.${namespace}.printing = with types; {
    enable = mkBoolOpt false "Whether or not to configure printing support.";
  };

  config = mkIf cfg.enable {services.printing.enable = true;};
}
