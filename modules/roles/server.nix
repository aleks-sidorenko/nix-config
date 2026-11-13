{ den, ... }:
{
  den.aspects.roles.server.includes = [
    den.aspects.roles.base
    den.aspects.system.headless
    den.aspects.services.tailscale
  ];
}
