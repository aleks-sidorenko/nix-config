{
  config,
  den,
  lib,
  ...
}:
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
      den.aspects.roles.base
    ];
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
    systemd-boot = {
      expr = {
        loader = c.boot.loader.systemd-boot.enable;
        initrd = c.boot.initrd.systemd.enable;
      };
      expected = {
        loader = true;
        initrd = true;
      };
    };
    persist-collects-ssh-key = {
      expr = lib.elem "/etc/ssh/ssh_host_ed25519_key" (
        map (f: f.filePath) c.environment.persistence."/persist".files
      );
      expected = true;
    };
    rollback-unit = {
      expr = c.boot.initrd.systemd.services ? impermanence-rollback-root;
      expected = true;
    };
    rollback-restores-blank = {
      expr = lib.hasInfix ''btrfs subvolume snapshot "$MNTPOINT/@root-blank" "$MNTPOINT/@root"'' c.boot.initrd.systemd.services.impermanence-rollback-root.script;
      expected = true;
    };
    sops-key-under-persist = {
      expr = c.sops.age.sshKeyPaths;
      expected = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    };
    sops-default-file = {
      expr = baseNameOf (toString c.sops.defaultSopsFile);
      expected = "nixos.yaml";
    };
    home-persistence-reaches-user = {
      expr = builtins.attrNames c.home-manager.users.alexander.home.persistence;
      expected = [ "/persist" ];
    };
    base-vm-builds = {
      expr = lib.isString c.system.build.toplevel.drvPath;
      expected = true;
    };
  };
}
