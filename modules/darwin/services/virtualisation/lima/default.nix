{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.lima;
in
{
  options.${namespace}.services.virtualisation.lima = with types; {
    enable = mkBoolOpt false "Enable Lima VM manager for Docker support on macOS";
  };

  config = mkIf cfg.enable {
    ${namespace} = {

      system.homebrew = {
        brews = [
          "lima"
        ];
      };
    };
  };
}
