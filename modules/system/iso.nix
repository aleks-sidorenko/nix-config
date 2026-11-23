{
  config,
  den,
  lib,
  ...
}:
let
  images = lib.filterAttrs (_: host: host.hasAspect den.aspects.system.iso) (
    lib.mergeAttrsList (lib.attrValues den.hosts)
  );

  # An eval test that `probe host config` is `expected` on every image host;
  # with none it fails instead of passing vacuously.
  perImage = probe: expected: {
    expr = {
      built = images != { };
      hosts = lib.mapAttrs (
        name: host: probe host config.flake.nixosConfigurations.${name}.config
      ) images;
    };
    expected = {
      built = true;
      hosts = lib.mapAttrs (_: _: expected) images;
    };
  };
in
{
  # A bootable live image: the host's users on a stick, ready to rescue or install a machine.
  den.aspects.system.iso = {
    includes = [
      den.aspects.system.networkmanager
      den.aspects.security.sudo.passwordless
    ];
    # The image holds no host key, so it can decrypt nothing.
    excludes = [ den.aspects.security.user-password ];

    nixos =
      {
        host,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

        services = {
          getty = {
            autologinUser = lib.mkForce host.primaryUser;
            # The profile's text tells you to set a password before SSH works.
            helpLine = lib.mkForce ''
              SSH takes keys only, and root accepts the image users' keys.
              At the console, root and nixos have empty passwords.

              To set up a wireless connection, run `nmtui`.
            '';
          };
          # nixos-anywhere installs as root; the profile and `security.ssh` only set defaults.
          openssh.settings.PermitRootLogin = "prohibit-password";
        };
        users.users.root.openssh.authorizedKeys.keys = lib.mapAttrsToList (
          _: user: user.identity.sshKey
        ) host.users;

        # The profile turns wpa_supplicant on, which NetworkManager asserts against.
        networking.wireless.enable = lib.mkImageMediaOverride false;

        # The default name carries a channel label that moves on every bump.
        image.baseName = lib.mkForce "nixos-${host.name}";
        isoImage.forceTextMode = true;

        # The image's own root is never a pool; only pools it is asked to import matter.
        boot.zfs.forceImportRoot = false;
      };
  };

  evalTests = {
    iso-autologins-primary-user = perImage (
      host: c: c.services.getty.autologinUser == host.primaryUser
    ) true;
    iso-root-takes-users-keys = perImage (
      host: c:
      lib.all (user: lib.elem user.identity.sshKey c.users.users.root.openssh.authorizedKeys.keys) (
        lib.attrValues host.users
      )
    ) true;
    iso-root-key-only = perImage (
      _: c: c.services.openssh.settings.PermitRootLogin
    ) "prohibit-password";
    iso-no-secrets =
      perImage
        (host: c: {
          sops = c ? sops;
          passwords = lib.any (user: c.users.users.${user.userName}.hashedPasswordFile != null) (
            lib.attrValues host.users
          );
        })
        {
          sops = false;
          passwords = false;
        };
    iso-networkmanager =
      perImage
        (_: c: {
          nm = c.networking.networkmanager.enable;
          wpa = c.networking.wireless.enable;
        })
        {
          nm = true;
          wpa = false;
        };
    iso-passwordless-sudo = perImage (_: c: c.security.sudo.wheelNeedsPassword) false;
    iso-boots-uefi-and-bios =
      perImage
        (_: c: {
          inherit (c.isoImage) makeBiosBootable makeEfiBootable makeUsbBootable;
        })
        {
          makeBiosBootable = true;
          makeEfiBootable = true;
          makeUsbBootable = true;
        };
    iso-file-name = perImage (host: c: c.image.fileName == "nixos-${host.name}.iso") true;
    iso-no-persistence = perImage (_: c: c ? disko || c.environment ? persistence) false;
    iso-help-line-fits-image = perImage (
      _: c: lib.hasInfix "you must set a password" c.services.getty.helpLine
    ) false;
  };
}
