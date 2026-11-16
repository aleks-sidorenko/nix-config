{ den, ... }:
{
  den.aspects.roles.media-server.includes = [ den.aspects.services.nginx ];
}
