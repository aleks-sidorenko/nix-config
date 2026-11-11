{ config, ... }:
{
  # Order matters: radarr and sonarr both declare /data/media, and the first
  # tmpfiles rule decides who owns it on a fresh disk. Later imports' rules
  # come first, so this keeps master's order, where sonarr owns it.
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
