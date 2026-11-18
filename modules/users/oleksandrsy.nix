{ den, ... }:
{
  den.aspects.oleksandrsy = {
    includes = [
      # The host's roles carry the home config; host-scope `homeManager` reaches no one otherwise.
      den.batteries.host-aspects
      den.batteries.primary-user
      (den.batteries.user-shell "fish")
    ];

    homeManager = {
      # Manages the home on its own; harmless beside the system integration.
      programs.home-manager.enable = true;
      home.sessionPath = [ "$HOME/.local/bin" ];
    };

    # The account is org-managed: darwin cannot create it, only manage it,
    # and needs its uid to know which one it is.
    provides.to-hosts =
      { user, ... }:
      {
        darwin.users = {
          knownUsers = [ user.userName ];
          users.${user.userName} = {
            uid = 501;
            # nix-darwin hides the users it manages; this one logs in at the window.
            isHidden = false;
          };
        };
      };
  };
}
