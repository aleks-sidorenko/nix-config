{ den, ... }:
{
  den.aspects.roles.server.includes = [
    den.aspects.roles.base
    den.aspects.system.headless
    den.aspects.services.tailscale
    den.aspects.system.networkmanager
    den.aspects.system.nix-ld
    den.aspects.security.sudo.passwordless
  ];
}
