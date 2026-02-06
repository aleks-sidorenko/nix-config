{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.rancher;
in
{
  options.${namespace}.services.virtualisation.rancher = with types; {
    enable = mkBoolOpt false "Enable Rancher kubernetes and container management on macOS";

  };

  config = mkIf cfg.enable {
    environment.variables.PATH = "$HOME/.rd/bin:$PATH";

    ${namespace} = {

      services.virtualisation = {
        docker = enabled;
        lima = enabled;
      };

      system.homebrew = {
        casks = [
          "rancher"
        ];
      };
    };
  };

}
