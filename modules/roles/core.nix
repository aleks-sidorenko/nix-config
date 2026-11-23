{ den, ... }:
{
  den.aspects.roles.core.includes = [
    den.aspects.security.sudo
    den.aspects.cli.core
  ];
}
