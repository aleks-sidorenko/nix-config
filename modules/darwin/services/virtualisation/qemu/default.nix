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
      mac = mkOpt str "52:54:00:00:00:64" "Guest MAC address (QEMU OUI 52:54:00)";
      gui = mkBoolOpt true "Open the guest in a Cocoa window";
    };
  };

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
    "if=virtio,format=raw,file=${g.rootDisk}"
    "-drive"
    "if=virtio,format=raw,file=${g.dataDisk}"
    "-netdev"
    "socket,id=net0,fd=3"
    "-device"
    "virtio-net-pci,netdev=net0,mac=${g.mac}"
    "-device"
    "virtio-gpu-pci"
    "-device"
    "qemu-xhci"
    "-device"
    "usb-kbd"
    "-device"
    "usb-tablet"
    "-display"
    (if g.gui then "cocoa" else "none")
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
    ];

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
