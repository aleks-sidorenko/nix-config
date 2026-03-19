{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.media.players.vlc;

in
{
  options.${namespace}.media.players.vlc = {
    enable = mkEnableOption "Enable or disable the VLC media player";
    default = mkBoolOpt false "Whether or not to use VLC as the default media player";
  };

  config = mkIf cfg.enable {

    ${namespace}.media.players.default = mkIf cfg.default {
      enable = true;
      name = "vlc";
    };

    home.packages = builtins.attrValues {
      inherit (pkgs)

        ffmpeg
        vlc
        ;
    };

  };

}
