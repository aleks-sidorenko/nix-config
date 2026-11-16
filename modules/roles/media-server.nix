{ den, lib, ... }:
{
  # Read by every media aspect, all of which this role includes.
  den.schema.conf.options.mediaRoot = lib.mkOption {
    type = lib.types.str;
    default = "/data";
    description = "Directory holding the download and media trees.";
  };

  den.aspects.roles.media-server.includes = [
    den.aspects.services.calibre-web
    den.aspects.services.jellyfin
    den.aspects.services.minidlna
    den.aspects.services.nginx
    den.aspects.services.qbittorrent
    den.aspects.services.sonarr
  ];
}
