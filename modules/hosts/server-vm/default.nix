{
  config,
  den,
  lib,
  ...
}:
let
  sv = config.flake.nixosConfigurations.server-vm.config;
  s = config.flake.nixosConfigurations.server.config;
in
{
  # Shared with server in ../home-servers.nix.
  den.hosts.x86_64-linux.server-vm.settings.storage.disko.device = "/dev/vda";

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
    # The full heap everywhere but the install test's small VM.
    server-vm-minecraft-heap = {
      expr = {
        real = sv.services.minecraft-server.jvmOpts;
        installed =
          (config.installTests.installedSystem den.hosts.x86_64-linux.server-vm)
          .config.services.minecraft-server.jvmOpts;
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
