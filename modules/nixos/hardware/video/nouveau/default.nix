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
  cfg = config.${namespace}.hardware.video.nouveau;
in
{
  options.${namespace}.hardware.video.nouveau = with types; {
    enable = mkBoolOpt false "Enable or disable hardware video support using Nouveau drivers";
  };

  config = mkIf cfg.enable {
    # Enable nouveau driver
    services.xserver.videoDrivers = [ "nouveau" ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          mesa
          libvdpau
          libva-vdpau-driver
          vdpauinfo
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          mesa
          libvdpau
          libva-vdpau-driver
        ];
      };
    };

    boot = {
      # Ensure nouveau is loaded early in the boot process
      kernelModules = [ "nouveau" ];

      # Enable modesetting and configure nouveau parameters
      kernelParams = [
        # Essential for Wayland/Hyprland compatibility
        "nouveau.modeset=1" # Must be enabled for KMS
        "nouveau.atomic=1" # Required for proper compositing
        "drm.debug=0x0" # Silence DRM noise

        # GPU-specific tuning for Fermi (GTX 500 series)
        "nouveau.config=NvMSI=0" # MSI often causes issues on Fermi
        "nouveau.runpm=0" # Critical - Fermi has broken runtime PM

        # Memory management (helps with ttm_validate)
        "nouveau.tmem=0" # Try disabling TMEM if validation fails
      ];

      # Blacklist NVIDIA proprietary driver to prevent conflicts
      blacklistedKernelModules = [
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
        "nvidia_uvm"
      ];
    };

    environment.systemPackages = with pkgs; [
      mesa # Open source 3D graphics library
      libva # Video acceleration
      libvdpau # VDPAU library for hardware video decoding
      libva-vdpau-driver # VDPAU driver for VA-API
      libvdpau-va-gl # VDPAU backend for VA API
      vdpauinfo # VDPAU testing utility
      xorg.xrandr # For monitor configuration
      vulkan-tools # Vulkan utilities
      vulkan-loader # Vulkan loader
      vulkan-validation-layers # Vulkan validation layers
      mesa-demos # OpenGL demos and tools
    ];

    # Environment variables for Nouveau + VDPAU
    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = mkForce "1"; # Avoid cursor issues
      GBM_BACKEND = "nouveau-drm"; # Use Nouveau's DRM backend
      LIBVA_DRIVER_NAME = "nouveau"; # VA-API acceleration
      VDPAU_DRIVER = "nouveau"; # VDPAU acceleration via nouveau driver
    };
  };
}
