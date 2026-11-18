{
  den.aspects.cli.media.homeManager =
    { config, pkgs, ... }:
    {
      home = {
        packages = [
          pkgs.ffmpeg
          (import ./_media-tools.nix { inherit pkgs; })
        ];
        sessionVariables.MEDIA_HOME = "${config.home.homeDirectory}/Media";
      };
    };
}
