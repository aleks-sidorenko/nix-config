{ den, ... }:
{
  # A bootable live image: the host's users on a stick, ready to rescue or install a machine.
  den.aspects.system.iso = {
    includes = [
      den.aspects.system.networkmanager
      den.aspects.security.sudo.passwordless
    ];

    nixos =
      {
        host,
        lib,
        modulesPath,
        ...
      }:
      {
        imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

        services.getty.autologinUser = lib.mkForce host.primaryUser;

        # nixos-anywhere installs as root; the profile and `security.ssh` only set defaults.
        services.openssh.settings.PermitRootLogin = "prohibit-password";
        users.users.root.openssh.authorizedKeys.keys = lib.mapAttrsToList (
          _: user: user.identity.sshKey
        ) host.users;

        # NetworkManager drives Wi-Fi; the two daemons assert against each other.
        networking.wireless.enable = lib.mkImageMediaOverride false;

        # The default name carries a channel label that moves on every bump.
        image.baseName = lib.mkForce "nixos-${host.name}";
        isoImage.forceTextMode = true;

        # The image's own root is never a pool; only pools it is asked to import matter.
        boot.zfs.forceImportRoot = false;
      };
  };
}
