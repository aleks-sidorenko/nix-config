{
  den.aspects.cli.yazi.homeManager =
    { pkgs, ... }:
    {
      programs.yazi = {
        enable = true;
        enableFishIntegration = true;
        shellWrapperName = "y";
      };

      home.packages = builtins.attrValues {
        inherit (pkgs)
          imagemagick
          ffmpegthumbnailer
          unar
          poppler
          ;
      };
    };
}
