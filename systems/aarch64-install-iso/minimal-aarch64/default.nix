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

  # -display none is the only way this guest is ever run, so the serial port is
  # the sole channel for install-time output. The installed system sets this
  # itself; the installer image does not, and relying on firmware SPCR
  # autodetection would leave the operator blind if it failed.
  boot.kernelParams = [
    "console=tty1"
    "console=ttyAMA0,115200n8"
  ];

  isoImage.forceTextMode = true;

  # iso-image.nix computes the real ISO filename from image.baseName (plain
  # assignment, "nixos-<edition>-<label>-<system>"); isoImage.isoName only
  # forwards to image.fileName, which this build never reads, so it is not set
  # here. Overriding baseName gives the image a short, stable, self-describing
  # filename — without it both minimal hosts, which share edition "minimal",
  # would produce near-identical names differing only in a trailing platform
  # suffix and a channel label that moves on every bump.
  image.baseName = mkForce "nixos-minimal-aarch64";

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
