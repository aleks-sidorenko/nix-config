{
  config,
  den,
  lib,
  ...
}:
let
  sv = config.flake.nixosConfigurations.server-vm.config;
  s = config.flake.nixosConfigurations.server.config;
  b = config.flake.nixosConfigurations.base-vm.config;
  inherit (import ../server/_parity.nix { inherit lib; }) declarative;

  # The only intended differences from `server`.
  withoutDevice =
    devices:
    lib.recursiveUpdate devices {
      disk.root = {
        device = null;
        content = {
          device = null;
          partitions.btrfs.content.subvolumes."@swap".swap.swapfile.size = null;
        };
      };
    };
in
{
  den.hosts.x86_64-linux.server-vm = {
    users.alexander = { };
    stateVersion = "26.05";
    settings.storage.disko = {
      device = "/dev/vda";
      encrypted = false;
    };
  };

  den.aspects.server-vm.includes = [
    den.aspects.roles.server
    den.aspects.hardware.qemu-guest
  ];

  evalTests = {
    server-vm-tailscale = {
      expr = sv.services.tailscale.enable;
      expected = true;
    };
    server-vm-persists-ts = {
      expr = lib.elem "/var/lib/tailscale" (
        map (d: d.dirPath) sv.environment.persistence."/persist".directories
      );
      expected = true;
    };
    base-vm-no-tailscale = {
      expr = b.services.tailscale.enable;
      expected = false;
    };
    server-vm-disk-like-server = {
      expr = withoutDevice (declarative sv.disko.devices);
      expected = withoutDevice (declarative s.disko.devices);
    };
    server-vm-headless = {
      expr = {
        docs = sv.documentation.enable;
        watchdog = sv.systemd.settings.Manager.RuntimeWatchdogSec;
      };
      expected = {
        docs = false;
        watchdog = "30s";
      };
    };
    server-vm-install-check = {
      expr = config.allSystems.x86_64-linux.checks ? install-server-vm;
      expected = true;
    };
    install-server-vm-evaluates = {
      expr = lib.isString config.allSystems.x86_64-linux.checks.install-server-vm.drvPath;
      expected = true;
    };
    server-builds = {
      expr = lib.isString s.system.build.toplevel.drvPath;
      expected = true;
    };
  };
}
