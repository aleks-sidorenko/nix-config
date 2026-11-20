{ config, ... }:
{
  den.aspects.cli.media = {
    os.nixpkgs.overlays = [ config.flake.overlays.default ];

    homeManager =
      { config, pkgs, ... }:
      {
        home = {
          packages = [
            pkgs.ffmpeg
            pkgs.media-tools
          ];
          sessionVariables.MEDIA_HOME = "${config.home.homeDirectory}/Media";
        };
      };
  };
}
