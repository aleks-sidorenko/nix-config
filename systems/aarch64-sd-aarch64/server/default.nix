{
  lib,
  modulesPath,
  inputs,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; {
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});
    })
  ];

  imports = with inputs.nixos-hardware.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    raspberry-pi-4
  ];

  ${namespace} = {
    roles = {
      server = enabled;
    };

    hardware.raspberry-pi-4 = enabled;

    system.boot.enable = lib.mkForce false;
  };
  

  sdImage.compressImage = false;
  
  

  system.stateVersion = "24.11";
}
