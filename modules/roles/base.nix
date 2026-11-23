{ den, ... }:
{
  den.aspects.roles.base.includes = [
    den.aspects.roles.core
    den.aspects.system.boot
    den.aspects.storage.disko
    den.aspects.storage.impermanence
    den.aspects.security.sops
    den.aspects.security.nix-access-tokens
  ];
}
