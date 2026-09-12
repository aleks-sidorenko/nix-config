{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.media.tools;
in
{
  options.${namespace}.media.tools = {
    enable = mkBoolOpt false "Media management CLI tools (media-normalize, media-import)";
    mediaHome =
      mkOpt types.str "${config.home.homeDirectory}/Media"
        "Default media library root (holds photos and videos); used as MEDIA_HOME and media-import's default DEST";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.${namespace}.media-tools ];
    home.sessionVariables.MEDIA_HOME = cfg.mediaHome;
  };
}
