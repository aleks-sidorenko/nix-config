{
  den.aspects.security.authorized-keys =
    { user, ... }:
    {
      os.users.users.${user.userName}.openssh.authorizedKeys.keys = [ user.identity.sshKey ];
    };
}
