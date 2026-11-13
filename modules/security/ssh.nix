{ den, lib, ... }:
let
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
in
{
  den.schema.user =
    { config, ... }:
    {
      options.identity = lib.mkOption {
        type = lib.types.str;
        default = config.userName;
        description = "Folder under identities/ holding the user's public keys.";
      };
    };

  den.aspects.security.ssh = {
    includes = [ den.aspects.security.ssh.authorized-keys ];

    nixos.services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        # Hosts that must accept root (installer images) override this.
        PermitRootLogin = lib.mkDefault "no";
        StreamLocalBindUnlink = "yes";
        GatewayPorts = "clientspecified";
        PermitUserEnvironment = "no";
      };
      hostKeys = [
        {
          path = hostKey;
          type = "ed25519";
        }
      ];
    };

    persist.files = [
      hostKey
      "${hostKey}.pub"
    ];

    authorized-keys =
      { user, ... }:
      {
        os.users.users.${user.userName}.openssh.authorizedKeys.keys = [
          (lib.trim (builtins.readFile ../../identities/${user.identity}/ssh.pub))
        ];
      };
  };
}
