{
  pkgs,
  config,
  lib,
  ...
}: let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  users.mutableUsers = false;
  users.users.alexander = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ifTheyExist [
      "audio"
      "deluge"
      "docker"
      "git"
      "i2c"
      "libvirtd"
      "lxd"
      "minecraft"
      "mysql"
      "network"
      "plugdev"
      "podman"
      "video"
      "wheel"
      "wireshark"
    ];

    openssh.authorizedKeys.keys = lib.splitString "\n" (builtins.readFile ../../../../users/alexander/ssh.pub);
    
    # TODO - replace
    # hashedPasswordFile = config.sops.secrets.alexander-password.path;
    initialPassword = "123qweasd";

    packages = [pkgs.home-manager];
  };

  
  home-manager.users.alexander = import ../../../../users/alexander/${config.networking.hostName}.nix;

  security.pam.services = {
    swaylock = {};
  };
}