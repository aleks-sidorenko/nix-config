{ den, ... }:
{
  den.aspects.roles.workstation.includes = [
    den.aspects.security.sops
    den.aspects.security.nix-access-tokens
    den.aspects.services.tailscale
  ];
}
