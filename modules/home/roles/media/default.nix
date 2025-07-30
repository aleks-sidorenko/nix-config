{
  inputs,
  config,
  pkgs,
  lib,
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
    enable = mkEnableOption "Whether or not to enable media applications.";
  };

  config = mkIf cfg.enable {
    ${namespace}.media = {
      players.vlc = enabled;
      shotwell = enabled;
    };
  };
}
