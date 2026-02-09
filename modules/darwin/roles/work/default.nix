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
      roles.common = {
        enable = true;
        homebrew.casks = [
        ];
      };

      communication = {
        viber = enabled;
        telegram = enabled;
        zoom = enabled;
        slack = enabled;
      };

      browsers = {
        chromium = enabled;
      };

      # Virtualisation
      services.virtualisation.rancher.enable = true;
    };
  };
}
