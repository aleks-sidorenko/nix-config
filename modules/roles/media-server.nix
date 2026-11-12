{ config, ... }:
{
  flake.modules.nixos.media-server.imports = with config.flake.modules.nixos; [
    calibre
    flaresolverr
    jellyfin
    minidlna
    prowlarr
    qbittorrent
    radarr
    recyclarr
    sonarr
  ];
}
