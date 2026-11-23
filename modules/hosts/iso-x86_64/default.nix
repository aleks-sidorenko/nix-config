{
  config,
  den,
  lib,
  ...
}:
let
  c = config.flake.nixosConfigurations.iso-x86_64.config;
  me = config.den.hosts.x86_64-linux.iso-x86_64.users.alexander;
in
{
  den.hosts.x86_64-linux.iso-x86_64 = {
    users.alexander = { };
    stateVersion = "26.05";
  };

  den.aspects.iso-x86_64 = {
    includes = [
      den.aspects.roles.core
      den.aspects.system.iso
    ];
    # The image holds no host key, so it can decrypt nothing.
    excludes = [ den.aspects.security.user-password ];
  };

  evalTests = {
    iso-autologins-primary-user = {
      expr = c.services.getty.autologinUser;
      expected = "alexander";
    };
    iso-root-takes-owner-key = {
      expr = lib.elem me.identity.sshKey c.users.users.root.openssh.authorizedKeys.keys;
      expected = true;
    };
    iso-root-key-only = {
      expr = c.services.openssh.settings.PermitRootLogin;
      expected = "prohibit-password";
    };
    iso-no-secrets = {
      expr = {
        sops = c ? sops;
        pw = c.users.users.alexander.hashedPasswordFile;
      };
      expected = {
        sops = false;
        pw = null;
      };
    };
    iso-networkmanager = {
      expr = {
        nm = c.networking.networkmanager.enable;
        wpa = c.networking.wireless.enable;
      };
      expected = {
        nm = true;
        wpa = false;
      };
    };
    iso-passwordless-sudo = {
      expr = c.security.sudo.wheelNeedsPassword;
      expected = false;
    };
    iso-boots-uefi-and-bios = {
      expr = {
        inherit (c.isoImage) makeEfiBootable makeUsbBootable;
      };
      expected = {
        makeEfiBootable = true;
        makeUsbBootable = true;
      };
    };
    iso-file-name = {
      expr = c.image.fileName;
      expected = "nixos-iso-x86_64.iso";
    };
    iso-no-persistence = {
      expr = c ? disko || c.environment ? persistence;
      expected = false;
    };
    iso-core-tools = {
      expr = lib.elem "parted" (map lib.getName c.environment.systemPackages);
      expected = true;
    };
  };
}
