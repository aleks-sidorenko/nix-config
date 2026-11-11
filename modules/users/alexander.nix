{ config, lib, ... }:
let
  user = config.factory.user {
    name = "alexander";
    admin = true;
  };

  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        alexander
        sops
      ];
    }).config;
in
{
  flake.modules.nixos.alexander = user.nixos;
  flake.modules.darwin.alexander = user.darwin;

  evalTests.alexander-ssh-key = {
    expr = c.users.users.alexander.openssh.authorizedKeys.keys;
    expected = [ (lib.trim (builtins.readFile ../../identities/alexander/ssh.pub)) ];
  };
}
