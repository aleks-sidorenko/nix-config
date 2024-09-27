{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-gpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    ./hardware.nix

    ../common/global
    ../common/users

     ../common/optional/peripherals.nix

  ];

  environment.systemPackages = with pkgs; [
    hello
  ];
  
  networking = {
    hostName = "zeus";
    useDHCP = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  programs = {
    adb.enable = true;
    dconf.enable = true;
  };

}