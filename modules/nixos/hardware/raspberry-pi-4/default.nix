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

    


    # ========================================================================
    # SYSTEM METADATA
    # ========================================================================
    # System identification tags for the Raspberry Pi
    # These tags help identify the system variant and configuration
    # Following the nixos-raspberrypi project conventions
    system.nixos.tags = let
      cfg = config.boot.loader.raspberryPi;
    in [
      "raspberry-pi-${cfg.variant}" # e.g., "raspberry-pi-4"
      cfg.bootloader # Bootloader type
      config.boot.kernelPackages.kernel.version # Kernel version
    ];

  };
}
