{ lib, ... }:
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

  den.aspects.security.authorized-keys =
    { user, ... }:
    {
      os.users.users.${user.userName}.openssh.authorizedKeys.keys = [
        (lib.trim (builtins.readFile ../../identities/${user.identity}/ssh.pub))
      ];
    };
}
