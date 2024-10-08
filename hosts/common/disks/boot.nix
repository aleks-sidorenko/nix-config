# This file (and the global directory) holds config that i use on all hosts
{
  inputs,
  outputs,
  ...
}: {
  
  boot = {
    initrd.systemd.enable = true;

    loader = {
      # systemd-boot fails https://github.com/NixOS/nixpkgs/issues/45032
      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  
}