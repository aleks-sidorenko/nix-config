{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.kvm;
in
{
  options.${namespace}.services.virtualisation.kvm = {
    enable = lib.mkEnableOption "enable kvm virtualisation";
  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = !config.${namespace}.services.virtualisation.virtualbox.enable;
        message = "KVM and VirtualBox cannot be enabled simultaneously as they conflict with each other";
      }
    ];
    ${namespace}.user.extraGroups = [
      "kvm"
      "libvirtd"
    ];

    environment.systemPackages = with pkgs; [
      libguestfs
      virtio-win
      win-spice
      virt-manager
      virt-viewer
    ];

    virtualisation = {
      kvmgt.enable = true;
      spiceUSBRedirection.enable = true;

      libvirtd = {
        enable = true;
        allowedBridges = [
          "nm-bridge"
          "virbr0"
        ];
        onBoot = "ignore";
        onShutdown = "shutdown";
        qemu = {
          swtpm.enable = true;

        };
      };
    };

    # Declare KVM support for Nix builds
    nix.settings.system-features = [
      "kvm"
      "nixos-test"
    ];

    # Load KVM modules in initrd for early KVM support
    boot.initrd.kernelModules = [
      "kvm"
      "kvm-intel"
    ];
  };
}
