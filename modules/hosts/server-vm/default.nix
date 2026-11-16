{
  config,
  den,
  lib,
  ...
}:
let
  sv = config.flake.nixosConfigurations.server-vm.config;
  s = config.flake.nixosConfigurations.server.config;
  inherit (import ../server/_parity.nix { inherit lib; }) declarative;
  parityOf = import ../server/_parity-services.nix;

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
    timeZone = "UTC";
    locales = [ "en_US.UTF-8" ];
    layouts = [ "us" ];
    settings = {
      services.qbittorrent.webUser = "alexander";
      services.minecraft-server = import ../_minecraft.nix;
      storage.disko = {
        device = "/dev/vda";
        encrypted = false;
      };
    };
  };

  den.aspects.server-vm.includes = [
    den.aspects.roles.home-server
    den.aspects.hardware.qemu-guest
  ];

  evalTests = {
    server-vm-qbittorrent-secret = {
      expr = sv.sops.secrets ? service-qbittorrent-alexander-password;
      expected = true;
    };
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
    server-vm-disk-like-server = {
      expr = withoutDevice (declarative sv.disko.devices);
      expected = withoutDevice (declarative s.disko.devices);
    };
    server-vm-headless = {
      expr = {
        docs = sv.documentation.enable;
        watchdog = sv.systemd.settings.Manager.RuntimeWatchdogSec;
        rebootWatchdog = sv.systemd.settings.Manager.RebootWatchdogSec or null;
        emergencyMode = sv.systemd.enableEmergencyMode;
      };
      expected = {
        docs = false;
        watchdog = "20s";
        rebootWatchdog = "30s";
        emergencyMode = false;
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
    # Hosts never share a repository or its lock.
    server-vm-own-repository = {
      expr = lib.hasSuffix "/server-vm" sv.services.restic.backups.default.repository;
      expected = true;
    };
    # The guest stands in for server in CI, so it must run what server runs.
    server-vm-like-server =
      let
        sections = c: lib.getAttrs [ "units" "timers" "vhosts" "users" ] (parityOf c);
      in
      {
        expr = sections sv;
        expected = sections s;
      };
    # The full heap everywhere but the install test's small VM.
    server-vm-minecraft-heap = {
      expr = {
        real = sv.services.minecraft-server.jvmOpts;
        installed =
          (config.installedSystem den.hosts.x86_64-linux.server-vm).config.services.minecraft-server.jvmOpts;
      };
      expected = {
        real = "-Xms2G -Xmx2G";
        installed = "-Xms256M -Xmx512M";
      };
    };
    server-builds = {
      expr = lib.isString s.system.build.toplevel.drvPath;
      expected = true;
    };
  };
}
