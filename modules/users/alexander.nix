{
  config,
  den,
  lib,
  ...
}:
let
  c = config.flake.nixosConfigurations.base-vm.config;
in
{
  den.aspects.alexander.includes = [
    den.batteries.primary-user
    (den.batteries.user-shell "fish")
  ];

  evalTests = {
    alexander-wheel = {
      expr = lib.elem "wheel" c.users.users.alexander.extraGroups;
      expected = true;
    };
    alexander-shell = {
      expr = lib.getName c.users.users.alexander.shell;
      expected = "fish";
    };
    alexander-ssh-key = {
      expr = c.users.users.alexander.openssh.authorizedKeys.keys;
      expected = [ (lib.trim (builtins.readFile ../../identities/alexander/ssh.pub)) ];
    };
  };
}
