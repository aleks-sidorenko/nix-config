{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.raspberry-pi-4;
in
{
  options.${namespace}.hardware.raspberry-pi-4 = {
    enable = mkEnableOption "Enable The raspberry-pi-4 config";
  };

  config = mkIf cfg.enable {
    ${namespace}.disks.boot.enable = mkForce false;
    
    hardware = {
      raspberry-pi."4" = {
        leds = {
          eth.disable = true;
          act.disable = true;
          pwr.disable = false;
        };        
      };
    };
    
    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
    ];
  };
}
