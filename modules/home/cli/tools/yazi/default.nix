{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.tools.yazi;
in
{
  options.${namespace}.cli.tools.yazi = with types; {
    enable = mkBoolOpt false "Whether or not to enable yazi";
  };

  config = mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
    };

    home.packages =
      with pkgs;
      [
        imagemagick
        ffmpegthumbnailer
        unar
        poppler
      ]
      ++ optionals stdenv.isLinux [
        # fontpreview depends on xdotool which is Linux-only
        fontpreview
      ];
  };
}
