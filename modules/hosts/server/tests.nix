{ config, lib, ... }:
let
  s = config.flake.nixosConfigurations.server.config;
  persisted = s.environment.persistence."/persist";
  owner = s.users.users.alexander;
  btrfsContent = s.disko.devices.disk.root.content.partitions.btrfs.content;
in
{
  evalTests = {
    server-blank-snapshot-idempotent = {
      expr = lib.hasInfix ''[ -e "$MNTPOINT/@root-blank" ] ||'' btrfsContent.postCreateHook;
      expected = true;
    };
    server-persisted-dirs = {
      expr = map (d: d.directory) persisted.directories;
      expected = [
        "/.cache/nix/"
        "/var/cache/"
        "/var/db/sudo/"
        "/var/lib/"
        "/etc/NetworkManager/system-connections"
      ];
    };
    server-persisted-files = {
      expr = map (f: f.file) persisted.files;
      expected = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
    server-alexander-groups = {
      expr = {
        inherit (owner) extraGroups group;
      };
      expected = {
        extraGroups = [
          "networkmanager"
          "input"
          "tty"
          "wheel"
        ];
        group = "users";
      };
    };
    server-alexander-password = {
      expr = owner.hashedPasswordFile;
      expected = "/run/secrets-for-users/user-alexander-password";
    };
    server-alexander-key = {
      expr = owner.openssh.authorizedKeys.keys;
      expected = [ (lib.trim (builtins.readFile ../../../identities/alexander/ssh.pub)) ];
    };
    server-root-no-keys = {
      expr = s.users.users.root.openssh.authorizedKeys.keys;
      expected = [ ];
    };
    server-sops-file = {
      expr = lib.hasSuffix "/secrets/server.yaml" (toString s.sops.defaultSopsFile);
      expected = true;
    };
    # A path value copies just this file to the store; a string built from the
    # flake source would put the whole repo in the closure and change it on
    # every commit.
    server-sops-file-alone = {
      expr = builtins.isPath s.sops.defaultSopsFile;
      expected = true;
    };
    deploy-server-users = {
      expr = {
        inherit (config.flake.deploy.nodes.server.profiles.system) user sshUser;
      };
      expected = {
        user = "root";
        sshUser = "alexander";
      };
    };
  };
}
