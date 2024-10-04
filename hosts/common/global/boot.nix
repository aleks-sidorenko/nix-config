{
  boot.initrd = {
    systemd.enable = true;

    loader = {
      # systemd-boot fails https://github.com/NixOS/nixpkgs/issues/45032
      grub = {
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
      };
      efi.canTouchEfiVariables = true;
    };
  }
}
