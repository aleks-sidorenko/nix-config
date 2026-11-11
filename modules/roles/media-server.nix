{ config, ... }:
{
  flake.modules.nixos.media-server.imports = with config.flake.modules.nixos; [
    calibre
    jellyfin
    minidlna
    prowlarr
    qbittorrent
    radarr
    recyclarr
    sonarr
  ];
}
