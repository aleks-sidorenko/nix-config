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

  # nixpkgs' `vlc` is the Linux Qt build; darwin has no source build, only the
  # upstream binary app bundle.
  vlc = if pkgs.stdenv.isDarwin then pkgs.vlc-bin else pkgs.vlc;
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

    home.packages = [
      pkgs.ffmpeg
      vlc
    ];

  };

}
