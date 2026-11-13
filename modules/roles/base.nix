{ den, ... }:
{
  den.aspects.roles.base.includes = [
    den.aspects.system.boot
    den.aspects.storage.disko
    den.aspects.storage.impermanence
    den.aspects.security.sops
  ];
}
