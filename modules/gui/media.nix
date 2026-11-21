{ den, ... }:
{
  den.aspects.gui.media = {
    includes = [ den.aspects.system.homebrew ];

    # The photo editor has no cask of its own; this suite's app installs it.
    darwin.homebrew.casks = [ "adobe-creative-cloud" ];

    # darwin has no source build of vlc, only the upstream app bundle.
    homeManager = { pkgs, ... }: { home.packages = [ pkgs.vlc-bin ]; };
  };
}
