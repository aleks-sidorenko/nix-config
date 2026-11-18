{ den, ... }:
{
  den.aspects.gui.media = {
    includes = [ den.aspects.system.homebrew ];

    # The photo editor has no cask of its own; this suite's app installs it.
    darwin.homebrew.casks = [ "adobe-creative-cloud" ];

    homeManager =
      { config, pkgs, ... }:
      {
        home = {
          packages = [
            pkgs.ffmpeg
            # darwin has no source build of vlc, only the upstream app bundle.
            pkgs.vlc-bin
            (import ./_media-tools.nix { inherit pkgs; })
          ];
          sessionVariables.MEDIA_HOME = "${config.home.homeDirectory}/Media";
        };
      };
  };
}
