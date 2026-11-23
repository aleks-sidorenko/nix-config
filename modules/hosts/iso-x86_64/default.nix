{
  config,
  den,
  lib,
  ...
}:
let
  c = config.flake.nixosConfigurations.iso-x86_64.config;
in
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

  # What every image must be is tested in `system.iso`.
  evalTests.iso-x86_64-core-tools = {
    expr = lib.elem "parted" (map lib.getName c.environment.systemPackages);
    expected = true;
  };
}
