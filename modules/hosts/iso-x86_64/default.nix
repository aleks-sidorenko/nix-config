{ den, ... }:
{
  den.hosts.x86_64-linux.iso-x86_64 = {
    users.alexander = { };
    stateVersion = "26.05";
  };

  den.aspects.iso-x86_64 = {
    includes = [
      den.aspects.roles.core
      den.aspects.system.iso
    ];
  };
}
