{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.hardware.bluetooth;
in
{
  options.${namespace}.hardware.bluetooth = {
    enable = mkEnableOption "Enable bluetooth service and packages";
  };

  config = mkIf cfg.enable {
    services.blueman.enable = true;
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = false;
        settings = {
          General = {
            Experimental = true;
          };
        };
      };
    };
  };
}
