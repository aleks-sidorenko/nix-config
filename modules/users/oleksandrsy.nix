{ den, ... }:
{
  den.aspects.oleksandrsy = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
    ];

    # The account is org-managed: darwin cannot create it, only manage it,
    # and needs its uid to know which one it is.
    provides.to-hosts =
      { user, ... }:
      {
        darwin.users = {
          knownUsers = [ user.userName ];
          users.${user.userName}.uid = 501;
        };
      };
  };
}
