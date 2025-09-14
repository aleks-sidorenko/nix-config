{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  options,
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
    
    boot.loader = {
      efi.canTouchEfiVariables = true;    
      systemd-boot.enable = true;
      generic-extlinux-compatible.enable = mkForce false;
    };
      

    # Only configure hardware.raspberry-pi if the nixos-hardware module is available
    hardware = lib.optionalAttrs (options.hardware ? raspberry-pi) {
            
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
