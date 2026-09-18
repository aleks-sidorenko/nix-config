{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.media.qbittorrent;
in
{
  options.${namespace}.media.qbittorrent = {
    enable = mkEnableOption "Enable the standalone qBittorrent desktop client";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      qbittorrent
    ];
  };
}
