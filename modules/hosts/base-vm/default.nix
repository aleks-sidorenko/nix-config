{ config, den, ... }:
let
  system = config.flake.nixosConfigurations.base-vm;
  c = system.config;
in
{
  den.hosts.x86_64-linux.base-vm = {
    users.alexander = { };
    stateVersion = "26.05";
  };

  den.aspects.base-vm = {
    includes = [ den.aspects.hardware.qemu-guest ];

    # Stand-ins so the system evaluates until the boot and disk aspects land.
    nixos = {
      boot.loader.grub.enable = false;
      fileSystems."/" = {
        device = "/dev/vda";
        fsType = "ext4";
      };
    };
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
    unstable-overlay = {
      expr = system.pkgs ? unstable;
      expected = true;
    };
  };
}
