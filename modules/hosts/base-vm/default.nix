{ config, den, ... }:
let
  system = config.flake.nixosConfigurations.base-vm;
  c = system.config;
in
{
  den.hosts.x86_64-linux.base-vm = {
    users.alexander = { };
    stateVersion = "26.05";
    settings.storage.disko.device = "/dev/vda";
  };

  den.aspects.base-vm = {
    includes = [
      den.aspects.hardware.qemu-guest
      den.aspects.storage.disko
    ];

    # Stand-in until system.boot provides a boot loader.
    nixos.boot.loader.grub.enable = false;
  };

  evalTests = {
    base-vm-hostname = {
      expr = c.networking.hostName;
      expected = "base-vm";
    };
    base-vm-timezone = {
      expr = c.time.timeZone;
      expected = "Europe/Kyiv";
    };
    base-vm-locale = {
      expr = c.i18n.defaultLocale;
      expected = "en_US.UTF-8";
    };
    base-vm-state = {
      expr = c.system.stateVersion;
      expected = "26.05";
    };
    base-vm-hm-state = {
      expr = c.home-manager.users.alexander.home.stateVersion;
      expected = "26.05";
    };
    sshd-hardened = {
      expr = {
        inherit (c.services.openssh.settings) PasswordAuthentication PermitRootLogin;
      };
      expected = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    base-vm-encrypted = {
      expr = c.disko.devices.disk.root.content.partitions ? encrypted;
      expected = true;
    };
    unstable-overlay = {
      expr = system.pkgs ? unstable;
      expected = true;
    };
  };
}
