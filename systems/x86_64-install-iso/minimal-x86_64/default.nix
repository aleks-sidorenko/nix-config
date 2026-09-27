{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {

    roles.minimal = enabled;

    # SSH is key-based (password auth disabled). The primary user here is the
    # throwaway `nixos` account with no identity, so the ssh module falls back
    # to authorizing the owner identity — the operator can SSH in to bootstrap.
    users.nixos = {
      primary = true;
      admin = true;
    };

    # nixos-anywhere reconnects as root@host to install (it detects the installer
    # and skips kexec), so permit key-based root login and authorize the owner
    # key for root. Installer only — hardened off on every deployed host.
    security.ssh.rootLogin = true;

  };

  # No password is set for `nixos` here: SOPS is disabled on the installer, so
  # the users module leaves the account password-less, and the stock
  # installation-device profile provides a passwordless console autologin.

  # iso-image.nix derives the real filename from image.baseName; isoImage.isoName
  # only feeds image.fileName, which this build never reads. Overriding baseName
  # keeps the name short and stable: the default carries a channel label that
  # moves on every bump, and both minimal hosts share edition "minimal".
  image.baseName = mkForce "nixos-minimal-x86_64";

  isoImage.forceTextMode = true;

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
