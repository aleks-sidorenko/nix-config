{
  config,
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

  };

  # No password is set for `nixos` here: SOPS is disabled on the installer, so
  # the users module leaves the account password-less, and the stock
  # installation-device profile provides a passwordless console autologin.

  # nixos-anywhere installs as root: on a host it detects as an installer it
  # copies your authorized_keys to /root and reconnects as root@host (see
  # nixos-anywhere.sh, the `isInstaller && sshUser != root` switch). The ssh role
  # hardens sshd to PermitRootLogin = "no", so re-enable key-based root login for
  # the installer and give root the same owner key. NixOS keeps authorized_keys
  # under /etc/ssh/authorized_keys.d/, so nixos-anywhere's runtime `cp` of them
  # fails silently — root must already hold the key. You still connect as `nixos`
  # (non-root + sudo); nixos-anywhere performs the root switch itself. Ephemeral
  # installer only — never a deployed host.
  services.openssh.settings.PermitRootLogin = mkForce "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = config.${namespace}.security.ssh.authorizedKeys;

  isoImage = {
    isoName = "nixos-minimal";
    forceTextMode = true;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
