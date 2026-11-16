{ den, ... }:
{
  den.aspects.roles.home-server.includes = [
    den.aspects.roles.server
    den.aspects.roles.media-server
    den.aspects.services.restic
  ];
}
