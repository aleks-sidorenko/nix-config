{ den, ... }:
{
  den.aspects.security.sops.impermanent = {
    includes = [ den.aspects.storage.impermanence ];

    nixos =
      {
        config,
        host,
        lib,
        ...
      }:
      {
        # Secrets decrypt before the bind mounts exist, so read the key where it really lives.
        sops.age.sshKeyPaths = map (key: host.settings.storage.impermanence.root + key.path) (
          lib.filter (key: key.type == "ed25519") config.services.openssh.hostKeys
        );
      };
  };
}
