{ den, ... }:
{
  den.aspects.gui.raycast = {
    includes = [ den.aspects.system.homebrew ];
    darwin.homebrew.casks = [ "raycast" ];
  };
}
