{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security.ssh;

  # Authorize the primary user's identity key (see identities/README.md),
  # falling back to the default owner identity when the primary has none —
  # e.g. the installer's throwaway `nixos` user, so the owner can still SSH in
  # to run bootstrap.
  primaryKey = (resolveIdentity config).sshPublicKey;
  ownerKey = (resolveIdentityByName defaults.user).sshPublicKey;
  authorizedKey = if primaryKey != null then primaryKey else ownerKey;
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Enable SSH";
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = lib.optional (authorizedKey != null) authorizedKey;
      description = "List of SSH public keys to authorize (defaults to the primary identity's, or the owner identity when the primary has none).";
    };
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      disks.impermanence.files = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };

    services.openssh = {
      enable = true;

      settings = {
        # Harden
        PasswordAuthentication = false;
        PermitRootLogin = "no";

        # Automatically remove stale sockets
        StreamLocalBindUnlink = "yes";
        # Allow forwarding ports to everywhere
        GatewayPorts = "clientspecified";

        # Accept following environment variables
        # AcceptEnv = "";

        # Disable all client-sent environment variables
        PermitUserEnvironment = "no";
      };

      hostKeys = [
        {
          path = persistence.resolve config "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    users.users = {
      ${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

  };
}
