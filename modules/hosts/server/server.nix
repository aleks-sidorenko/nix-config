{ config, ... }:
{
  hosts.server = {
    system = "x86_64-linux";
    deploy.sshUser = "alexander";
  };

  flake.modules.nixos.server = {
    imports = with config.flake.modules.nixos; [
      home-server
      alexander
      disko
      ./_hardware.nix
      ./_disks.nix
    ];

    sops.defaultSopsFile = ../../../secrets/server.yaml;

    # Do not change: tracks when NixOS was first installed on this machine.
    system.stateVersion = "26.05";
    home-manager.users.alexander.home.stateVersion = "26.05";
  };
}
