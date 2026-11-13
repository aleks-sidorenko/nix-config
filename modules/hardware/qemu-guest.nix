{
  den.aspects.hardware.qemu-guest.nixos =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    };
}
