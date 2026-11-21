{ den, ... }:
{
  den.aspects.dev.xcode = {
    includes = [ den.aspects.system.homebrew ];
    darwin.homebrew = {
      brews = [ "mas" ];
      # Licence-bound and not in nixpkgs; needs a one-time App Store sign-in.
      masApps.Xcode = 497799835;
    };
  };
}
