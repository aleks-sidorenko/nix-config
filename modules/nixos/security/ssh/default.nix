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

  # Sops needs acess to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  hasOptinPersistence = config.${namespace}.disks.impermanence.enable;
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
        # Let WAYLAND_DISPLAY be forwarded
        AcceptEnv = "WAYLAND_DISPLAY";
        X11Forwarding = true;
      };

      hostKeys = [
        {
          path = persistentPath "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };

    users.users = {
      ${config.${namespace}.user.name}.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    };
  };
}
