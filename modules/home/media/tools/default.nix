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
    mediaHome = mkOpt types.str "${config.home.homeDirectory}/Pictures/Photo" "Root directory for media library";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.${namespace}.media-tools ];
    home.sessionVariables.MEDIA_HOME = cfg.mediaHome;
  };
}
