{
  # A user's own `nixos` content stays in the user scope; the account lives on the host.
  den.aspects.security.user-password.provides.to-hosts =
    { user, ... }:
    {
      nixos =
        { config, ... }:
        let
          secret = "user-${user.userName}-password";
        in
        {
          sops.secrets.${secret}.neededForUsers = true;
          users = {
            mutableUsers = false;
            users.${user.userName}.hashedPasswordFile = config.sops.secrets.${secret}.path;
          };
        };
    };
}
