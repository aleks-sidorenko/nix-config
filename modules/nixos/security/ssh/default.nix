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
    rootLogin = mkBoolOpt false ''
      Permit key-based root SSH login and authorize the same keys for root.
      Disabled (PermitRootLogin = "no") everywhere by default; enable it only on
      installer images, where nixos-anywhere reconnects as root@host to perform
      the install (it detects the installer, skips kexec, and needs a root SSH
      login it can reach).
    '';
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
        # Key-only root login when explicitly enabled (installer images); "no"
        # otherwise. See the `rootLogin` option.
        PermitRootLogin = if cfg.rootLogin then "prohibit-password" else "no";

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
    }
    # nixos-anywhere copies the connecting user's authorized_keys to /root, but
    # NixOS keeps them under /etc/ssh/authorized_keys.d/, so that runtime copy
    # fails silently — authorize root here directly when root login is enabled.
    // optionalAttrs cfg.rootLogin {
      root.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

  };
}
