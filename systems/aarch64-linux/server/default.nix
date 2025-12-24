{
  lib,
  modulesPath,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    ./disks.nix
  ];
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # Example: https://github.com/Stunkymonkey/nixos/tree/master/machines/serverless

  ${namespace} = {
    roles = {
      home-server = enabled;
    };

    hardware.raspberry-pi-4 = enabled;

  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
