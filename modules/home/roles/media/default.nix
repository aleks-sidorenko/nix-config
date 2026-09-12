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
      # GUI players/organizers are Linux/GTK only; on darwin only the
      # management CLI tools are portable (macOS gets GUI apps elsewhere).
      players.vlc = mkIf pkgs.stdenv.isLinux enabled;
      shotwell = mkIf pkgs.stdenv.isLinux enabled;
      tools = enabled;
    };
  };
}
