{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.video.nvidia;
in
{
  options.${namespace}.hardware.video.nvidia = with types; {
    enable = mkBoolOpt false "Enable or disable hardware video support for NVidia GPUs.";
  };

  config = mkIf cfg.enable {
    # Enable the correct legacy driver branch
    services.xserver.videoDrivers = [ "nvidiaLegacy390" ];

    hardware = {
      graphics.enable = true;

      nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_390;
        modesetting.enable = true;

        # Power management (may help with stability)
        powerManagement.enable = true;

        nvidiaSettings = true;
        open = false; # Use proprietary driver
      };
    };

    boot = {
      # Use older kernel https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/default.nix#L202
      kernelPackages = mkForce pkgs.linuxPackages_6_12;
      blacklistedKernelModules = ["nouveau"];
      
      # Ensure NVIDIA modules are loaded early in the boot process
      kernelModules = [ "nvidia" "nvidia_drm" "nvidia_uvm" "nvidia_modeset" ];
      extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.legacy_390 ];
    };

    environment.systemPackages = with pkgs; [
      config.boot.kernelPackages.nvidiaPackages.legacy_390.bin
    ];

  };

}
