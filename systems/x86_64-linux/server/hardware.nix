{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ "kvm-intel" ];
    };

    # Alder Lake-N has only the low-power encoder, which needs HuC firmware
    # loaded through GuC.
    kernelParams = [ "i915.enable_guc=3" ];
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        # OpenCL, for Jellyfin's HDR tone mapping
        intel-compute-runtime
      ];
    };
  };

  # Codecs are what this iGPU decodes and encodes in hardware.
  services.jellyfin = {
    hardwareAcceleration = {
      enable = true;
      type = "qsv";
      device = "/dev/dri/renderD128";
    };
    transcoding = {
      enableHardwareEncoding = true;
      enableIntelLowPowerEncoding = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        hevcRExt10bit = true;
        hevcRExt12bit = true;
        mpeg2 = true;
        vc1 = true;
        vp9 = true;
        av1 = true;
      };
      hardwareEncodingCodecs.hevc = true;
    };
    # Without it these settings only seed a fresh encoding.xml.
    forceEncodingConfig = true;
  };
}
