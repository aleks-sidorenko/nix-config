{ den, ... }:
{
  den.aspects.roles.media-server.includes = [
    den.aspects.services.calibre-web
    den.aspects.services.flaresolverr
    den.aspects.services.jellyfin
    den.aspects.services.minidlna
    den.aspects.services.nginx
    den.aspects.services.prowlarr
    den.aspects.services.qbittorrent
    den.aspects.services.radarr
    den.aspects.services.recyclarr
    den.aspects.services.sonarr
  ];
}
