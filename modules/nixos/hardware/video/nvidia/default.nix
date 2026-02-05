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
    enable = mkBoolOpt false "Enable or disable hardware video support for NVidia GPUs";
  };

  config = mkIf cfg.enable {
    # Enable modern NVIDIA drivers for GTX 1650
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      graphics.enable = true;

      nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        modesetting.enable = true;

        # Power management for modern cards
        powerManagement.enable = true;
        powerManagement.finegrained = false;

        # Enable nvidia-settings and modern features
        nvidiaSettings = true;

        # Use proprietary driver (open source drivers not mature enough yet)
        open = false;
      };
    };

    boot = {

      blacklistedKernelModules = [ "nouveau" ];

      # Ensure NVIDIA modules are loaded early in the boot process
      kernelModules = [
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
        "nvidia_uvm"
      ];

      # Load nvidia modules in initrd for early display
      initrd.kernelModules = [
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
      ];
      extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.stable ];

      # Enable kernel mode setting and modern features for GTX 1650
      kernelParams = [
        "nvidia-drm.modeset=1"
        "nvidia-drm.fbdev=1"
        # Enable hardware video acceleration
        "nvidia.NVreg_EnableGpuFirmware=1"
        # Improve display detection and stability
        "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
        "nvidia.NVreg_UsePageAttributeTable=1"
      ];
    };

    environment.systemPackages = with pkgs; [
      config.boot.kernelPackages.nvidiaPackages.stable.bin
      # Additional NVIDIA utilities
      nvtopPackages.nvidia
    ];

    # Environment variables for Nvidia + Wayland compatibility
    environment.sessionVariables = {
      # Enable Wayland support for Nvidia
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      # Improve Wayland compatibility
      WLR_NO_HARDWARE_CURSORS = "1";
    };

  };

}
