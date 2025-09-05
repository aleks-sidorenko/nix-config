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
    
    boot = {      
      # Switch to a compatible bootloader
      loader = {
        grub.enable = lib.mkForce false;
        generic-extlinux-compatible.enable = lib.mkForce true;
      };
    };

    # Only configure hardware.raspberry-pi if the nixos-hardware module is available
    hardware = lib.optionalAttrs (options.hardware ? raspberry-pi) {
      raspberry-pi."4" = {
        apply-overlays-dtmerge.enable = true;
        deviceTree.enable = true;
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
