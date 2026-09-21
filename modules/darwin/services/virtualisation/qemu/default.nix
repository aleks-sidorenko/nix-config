{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.virtualisation.qemu;

  vmnet = config.${namespace}.services.networking.socket-vmnet;

  guest = {
    options = with types; {
      cpus = mkOpt int 4 "Virtual CPUs assigned to the guest";
      memory = mkOpt str "8G" "Guest RAM, as a QEMU size string";
      rootDisk = mkOpt str "" "Path to the guest's root disk image";
      dataDisk = mkOpt str "" "Path to the guest's bulk data disk image";
      varsDisk = mkOpt str "" "Path to the guest's writable UEFI variable store";
      mac = mkOpt str "52:54:00:00:00:64" "Guest MAC address (QEMU OUI 52:54:00)";
      # llvmpipe at Retina resolution is the weak point of a software-rendered
      # guest, so the framebuffer is capped instead of matching the host panel.
      resolution = {
        width = mkOpt int 1920 "Guest framebuffer width in pixels";
        height = mkOpt int 1200 "Guest framebuffer height in pixels";
      };
    };
  };

  # "virt" carries no built-in firmware the way x86 carries SeaBIOS, so EDK2 is
  # mapped in by hand: unit 0 is the read-only code, unit 1 the guest's own
  # variable store, which it writes to (boot.loader.efi.canTouchEfiVariables).
  firmware = "${cfg.package}/share/qemu/edk2-aarch64-code.fd";

  # socket_vmnet_client opens the daemon's socket and hands QEMU fd 3.
  qemuArgs = g: [
    (homebrew.getOptExe "socket_vmnet" "socket_vmnet_client")
    vmnet.socket
    "${cfg.package}/bin/qemu-system-aarch64"
    "-machine"
    "virt,accel=hvf"
    "-cpu"
    "host"
    "-smp"
    (toString g.cpus)
    "-m"
    g.memory
    "-drive"
    "if=pflash,format=raw,unit=0,readonly=on,file=${firmware}"
    "-drive"
    "if=pflash,format=raw,unit=1,file=${g.varsDisk}"
    "-drive"
    "if=virtio,format=raw,file=${g.rootDisk}"
    "-drive"
    "if=virtio,format=raw,file=${g.dataDisk}"
    "-netdev"
    "socket,id=net0,fd=3"
    "-device"
    "virtio-net-pci,netdev=net0,mac=${g.mac}"
    "-device"
    "virtio-gpu-pci,xres=${toString g.resolution.width},yres=${toString g.resolution.height}"
    "-device"
    "virtio-rng-pci"
    "-device"
    "qemu-xhci"
    "-device"
    "usb-kbd"
    "-device"
    "usb-tablet"
    "-display"
    "cocoa"
  ];

  # An unset path yields `-drive file=`, which fails only at exec — into a log
  # file, with no retry. Catch it at eval instead.
  mkDiskAssertions =
    name: g:
    map
      (disk: {
        assertion = g.${disk} != "";
        message = "${namespace}.services.virtualisation.qemu.guests.${name}.${disk} must be a path to a disk image.";
      })
      [
        "rootDisk"
        "dataDisk"
        "varsDisk"
      ];
in
{
  options.${namespace}.services.virtualisation.qemu = with types; {
    enable = mkBoolOpt false "Whether to run QEMU guests under the Apple hypervisor";
    package = mkPackageOpt pkgs.qemu "The qemu package to use";
    guests = mkOpt (attrsOf (submodule guest)) { } "QEMU guests, keyed by hostname";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = vmnet.enable;
        message = "${namespace}.services.virtualisation.qemu needs ${namespace}.services.networking.socket-vmnet for guest networking.";
      }
    ]
    ++ concatLists (mapAttrsToList mkDiskAssertions cfg.guests);

    environment.systemPackages = [ cfg.package ];

    # A user agent, not a daemon: the guest owns a window in the GUI session.
    launchd.user.agents = mapAttrs' (
      name: g:
      nameValuePair "qemu-${name}" {
        serviceConfig = {
          ProgramArguments = qemuArgs g;
          RunAtLoad = true;
          KeepAlive = false;
          StandardOutPath = "/tmp/qemu-${name}.log";
          StandardErrorPath = "/tmp/qemu-${name}.error.log";
        };
      }
    ) cfg.guests;
  };
}
