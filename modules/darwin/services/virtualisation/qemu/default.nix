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

  guest =
    { name, config, ... }:
    {
      options = with types; {
        cpus = mkOpt int 4 "Virtual CPUs assigned to the guest";
        memory = mkOpt str "8G" "Guest RAM, as a QEMU size string";
        rootDisk = mkOpt str "" "Path to the guest's root disk image";
        dataDisk = mkOpt str "" "Path to the guest's bulk data disk image";
        varsDisk = mkOpt str "" "Path to the guest's writable UEFI variable store";
        mac = mkOpt str "52:54:00:00:00:64" "Guest MAC address (QEMU OUI 52:54:00)";
        display = mkOpt (enum [
          "cocoa"
          "none"
        ]) "cocoa" "Where the guest's display goes: a Cocoa window, or headless with a serial console";
        # llvmpipe at Retina resolution is the weak point of a software-rendered
        # guest, so the framebuffer is capped instead of matching the host panel.
        resolution = {
          width = mkOpt int 1920 "Guest framebuffer width in pixels";
          height = mkOpt int 1200 "Guest framebuffer height in pixels";
        };

        launcher = mkOption {
          type = package;
          readOnly = true;
          description = ''
            The guest's QEMU launcher. Derived, not settable: both callers — the
            launchd agent and `just vm-install` — take the command line from
            here, so an install boot and a steady-state boot cannot diverge.
            Exposed so the install script can realise it with `nix build`
            instead of only reading its path.
          '';
        };
      };

      config.launcher = mkLauncher name config;
    };

  # "virt" carries no built-in firmware the way x86 carries SeaBIOS, so EDK2 is
  # mapped in by hand: unit 0 is the read-only code, unit 1 the guest's own
  # variable store, which it writes to (boot.loader.efi.canTouchEfiVariables).
  firmware = "${cfg.package}/share/qemu/edk2-aarch64-code.fd";

  # One definition, two callers: the launchd agent runs this with no arguments,
  # and `just vm-install` runs it with `--install <iso>`. A second, hand-written
  # command line is how a disk path or MAC silently diverges between the two.
  mkLauncher =
    name: g:
    pkgs.writeShellApplication {
      name = "qemu-${name}";
      text = ''
        install_iso=""
        if [ "''${1:-}" = "--install" ]; then
          install_iso="''${2:?--install requires an ISO path}"
        elif [ -n "''${1:-}" ]; then
          echo "usage: $0 [--install <iso>]" >&2
          exit 2
        fi

        args=(
          "${cfg.package}/bin/qemu-system-aarch64"
          -machine "virt,accel=hvf"
          -cpu host
          -smp ${toString g.cpus}
          -m ${g.memory}
          -drive "if=pflash,format=raw,unit=0,readonly=on,file=${firmware}"
          -drive "if=pflash,format=raw,unit=1,file=${g.varsDisk}"
          -drive "if=virtio,format=qcow2,file=${g.rootDisk}"
          -drive "if=virtio,format=qcow2,file=${g.dataDisk}"
          -netdev "socket,id=net0,fd=3"
          -device "virtio-net-pci,netdev=net0,mac=${g.mac}"
          -device virtio-rng-pci
        )

        ${
          if g.display == "none" then
            ''
              # A headless guest with no console is silent exactly when it fails to
              # boot. Pairs with console=ttyAMA0 on the guest's kernel cmdline.
              args+=( -display none -serial "file:/tmp/qemu-${name}.console.log" )''
          else
            ''
              args+=(
                -device "virtio-gpu-pci,xres=${toString g.resolution.width},yres=${toString g.resolution.height}"
                -device qemu-xhci -device usb-kbd -device usb-tablet
                -display cocoa
              )''
        }

        # Install media is transient, exactly like a USB stick: it is never part
        # of the guest's steady-state definition, only of this one invocation.
        # `-boot order=d` is the legacy BIOS knob and advisory here — EDK2 takes
        # its order from its own varstore — so what makes a fresh guest boot the
        # ISO is having nothing else bootable. Redoing an install means deleting
        # the disks and varstore (see docs/bootstrap.md).
        if [ -n "$install_iso" ]; then
          args+=( -cdrom "$install_iso" -boot order=d )
        fi

        # socket-vmnet is a system daemon and this is a user agent, so this
        # can start before it; launchd's PathState KeepAlive (below) holds the
        # agent until the socket exists rather than retrying in-script.
        # socket_vmnet_client opens the daemon's socket and hands QEMU fd 3.
        exec ${homebrew.getOptExe "socket_vmnet" "socket_vmnet_client"} \
          ${vmnet.socket} "''${args[@]}"
      '';
    };

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

    # A user agent, not a daemon: disks live under the invoking user's home
    # (homeDir config), and in cocoa mode the guest also owns a GUI window.
    launchd.user.agents = mapAttrs' (
      name: g:
      nameValuePair "qemu-${name}" {
        serviceConfig = {
          ProgramArguments = [ "${g.launcher}/bin/qemu-${name}" ];
          RunAtLoad = true;
          # Restart a guest that died, leave one that was shut down on purpose.
          # Plain `KeepAlive = true` cannot tell the two apart and would fight
          # a deliberate `poweroff`; `false` leaves a crashed stand-in silently
          # down until the next login, which is the worse failure for something
          # standing in for an always-on server.
          # PathState also gates launch on socket-vmnet's socket existing, so
          # this agent isn't spun up racing the daemon on boot. Existence is
          # necessary but not sufficient proof the daemon is serving, so a
          # wedged NIC is still possible — this only narrows the window.
          KeepAlive = {
            SuccessfulExit = false;
            PathState."${vmnet.socket}" = true;
          };
          StandardOutPath = "/tmp/qemu-${name}.log";
          StandardErrorPath = "/tmp/qemu-${name}.error.log";
        };
      }
    ) cfg.guests;
  };
}
