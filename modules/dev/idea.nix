{ den, ... }:
{
  den.aspects.dev.idea = {
    includes = [ (den.batteries.unfree [ "idea" ]) ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.jetbrains.idea ];
      };
  };
}
