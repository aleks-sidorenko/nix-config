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
  cfg = config.${namespace}.media.players.default;
  mimeTypes = [
    "application/mxf"
    "application/sdp"
    "application/smil"
    "application/streamingmedia"
    "application/vnd.apple.mpegurl"
    "application/vnd.ms-asf"
    "application/vnd.rn-realmedia"
    "application/vnd.rn-realmedia-vbr"
    "application/x-cue"
    "application/x-extension-m4a"
    "application/x-extension-mp4"
    "application/x-matroska"
    "application/x-mpegurl"
    "application/x-ogm"
    "application/x-ogm-video"
    "application/x-shorten"
    "application/x-smil"
    "application/x-streamingmedia"
    "audio/*"
    "video/*"
  ];
in
{
  options.${namespace}.media.players.default = with types; {
    enable = mkEnableOption "Whether or not to enable the default media player.";
    name = mkStringOpt' "The name of the default media player to use.";
  };

  config =
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "Please specify a media player name in ${namespace}.media.players.default.";
        }
      ];
    }
    // withMimeAssociations config cfg.name mimeTypes;
}
