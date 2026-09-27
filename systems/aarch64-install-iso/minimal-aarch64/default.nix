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

  isoImage = {
    # Distinct from the x86_64 image's "nixos-minimal": `just iso-write` finds
    # the ISO by globbing this name, and a shared prefix would match both.
    # (Renamed upstream to image.fileName in 25.05 and no longer drives the
    # actual output filename — see image.baseName override below — kept here
    # anyway since it's what the brief's forwarding path still reads.)
    isoName = "nixos-minimal-aarch64";
    forceTextMode = true;
  };

  # iso-image.nix computes the real ISO filename from image.baseName (plain
  # assignment, "nixos-<edition>-<label>-<system>"), not from isoImage.isoName
  # above — that option only forwards to image.fileName, which this build
  # never reads. Both minimal hosts share edition "minimal", so without this
  # override the x86_64 and aarch64 images would differ only in their
  # trailing platform suffix, not in a name `just iso-write` can glob on.
  image.baseName = mkForce "nixos-minimal-aarch64";

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
