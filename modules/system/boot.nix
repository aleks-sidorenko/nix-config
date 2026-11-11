{ config, ... }:
let
  c =
    (config.builders.nixos "x86_64-linux" {
      imports = [ config.flake.modules.nixos.boot ];
      system.stateVersion = "26.05";
    }).config;
in
{
  flake.modules.nixos.boot =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        efibootmgr
        efitools
        efivar
        fwupd
      ];

      boot = {
        loader = {
          efi.canTouchEfiVariables = true;
          systemd-boot = {
            enable = true;
            configurationLimit = 3;
          };
          grub.enable = lib.mkForce false;
        };
        initrd.systemd.enable = true;
      };
    };

  evalTests = {
    boot-systemd-boot = {
      expr = c.boot.loader.systemd-boot.configurationLimit;
      expected = 3;
    };
    boot-systemd-initrd = {
      expr = c.boot.initrd.systemd.enable;
      expected = true;
    };
  };
}
