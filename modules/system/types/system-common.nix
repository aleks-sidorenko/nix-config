{ config, ... }:
let
  persistRoot = config.constants.persistence.root;
in
{
  flake.modules.nixos.system-common =
    { lib, ... }:
    {
      imports = with config.flake.modules.nixos; [
        system-minimal
        boot
        fs
        impermanence
        sops
        nix-github-auth
        tailscale
        nh
        nix-ld
      ];

      # Accounts and passwords come only from this config (users from the
      # factory, passwords from SOPS).
      users.mutableUsers = false;

      # State of system-minimal's features. Listed here, not in ssh or
      # networking, because the installer imports those without impermanence.
      nix-config.impermanence = {
        directories = [ "/etc/NetworkManager/system-connections" ];
        files = [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };

      # sshd reads the key before impermanence bind-mounts it into /etc.
      services.openssh.hostKeys = lib.mkForce [
        {
          path = "${persistRoot}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
}
