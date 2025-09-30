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
in
{
  options.${namespace}.security.ssh = with types; {
    enable = mkBoolOpt false "Enable SSH";
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ (builtins.readFile ../../../home/security/ssh/id_ed25519.pub) ];
      description = "List of SSH public keys to authorize";
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
          path = persistence.path config "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    users.users = {
      ${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };

  };
}
