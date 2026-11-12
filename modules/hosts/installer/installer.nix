{
  config,
  inputs,
  lib,
  ...
}:
let
  ownerKey = (config.flake.lib.identity config.constants.owner).sshPublicKey;
  inst = config.flake.nixosConfigurations.installer.config;
  key = lib.trim (builtins.readFile ../../../identities/alexander/ssh.pub);
in
{
  flake.modules.nixos.installer = {
    imports = [
      config.flake.modules.nixos.system-minimal
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ];

    # nixos-anywhere reconnects as root@host to install (it detects the installer
    # and skips kexec), so permit key-based root login. Installer only: every
    # other host keeps the hardened default.
    services.openssh.settings.PermitRootLogin = "prohibit-password";

    # nixos-anywhere copies the connecting user's authorized_keys to /root, but
    # NixOS keeps them under /etc/ssh/authorized_keys.d/, so that runtime copy
    # fails silently. Authorize root directly.
    #
    # `nixos` is left without a password: the installation-device profile gives
    # it a passwordless console autologin, and SSH is key-only.
    users.users.root.openssh.authorizedKeys.keys = [ ownerKey ];
    users.users.nixos.openssh.authorizedKeys.keys = [ ownerKey ];

    isoImage.forceTextMode = true;

    # iso-image.nix derives the real filename from image.baseName; isoImage.isoName
    # only feeds image.fileName, which this build never reads. Overriding baseName
    # keeps the name short and stable: the default carries a channel label that
    # moves on every bump.
    image.baseName = lib.mkForce "nixos-minimal-x86_64";

    system.stateVersion = "25.05";
  };

  hosts.installer.system = "x86_64-linux";

  perSystem =
    { system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        installer-iso = config.flake.nixosConfigurations.installer.config.system.build.isoImage;
      };
    };

  evalTests = {
    installer-host-keys-etc = {
      expr = map (k: k.path) inst.services.openssh.hostKeys;
      expected = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
    installer-root-login = {
      expr = inst.services.openssh.settings.PermitRootLogin;
      expected = "prohibit-password";
    };
    installer-no-passwords = {
      expr = inst.services.openssh.settings.PasswordAuthentication;
      expected = false;
    };
    installer-root-key = {
      expr = inst.users.users.root.openssh.authorizedKeys.keys;
      expected = [ key ];
    };
    installer-nixos-key = {
      expr = inst.users.users.nixos.openssh.authorizedKeys.keys;
      expected = [ key ];
    };
    installer-hostname = {
      expr = inst.networking.hostName;
      expected = "installer";
    };
    installer-iso-name = {
      expr = inst.system.build.isoImage.name;
      expected = "nixos-minimal-x86_64.iso";
    };
    installer-timezone = {
      expr = inst.time.timeZone;
      expected = "Europe/Kyiv";
    };
  };
}
