{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.work;
in
{
  options.${namespace}.roles.work = with types; {
    enable = mkEnableOption "Enable work configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Inherit common configuration
      roles = {
        common = {
          homebrew = {
            taps = [
              "akeylesslabs/tap" # Akeyless CLI tap
            ];
            brews = [
              "akeyless" # Akeyless secrets management CLI
            ];
            casks = [
            ];
          };
        };

        macbook = enabled;
      };

      communication = {
        zoom = enabled;
        slack = enabled;
      };

      # Virtualisation
      services.virtualisation.rancher.enable = true;
    };
  };
}
