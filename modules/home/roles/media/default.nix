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
  cfg = config.${namespace}.roles.media;
in
{
  options.${namespace}.roles.media = with types; {
    enable = mkEnableOption "Whether or not to enable media applications";
  };

  config = mkIf cfg.enable {
    ${namespace}.media = {
      players.vlc = enabled;

      # GTK-only organizer, with no portable equivalent.
      shotwell = mkIf pkgs.stdenv.isLinux enabled;
      tools = enabled;
    };
  };
}
