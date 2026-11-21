{ den, ... }:
{
  den.aspects.dev.akeyless = {
    includes = [ den.aspects.system.homebrew ];
    darwin.homebrew = {
      taps = [ "akeylesslabs/tap" ];
      brews = [ "akeyless" ];
    };
  };
}
