{ config, inputs, ... }:
{
  flake = {
    modules.nixos.server = {
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

    nixosConfigurations.server = inputs.self.lib.mkNixos "x86_64-linux" "server";

    deploy.nodes.server = {
      hostname = "server";
      profiles.system = {
        user = "root";
        # wheel is passwordless on system-server, so no interactiveSudo.
        sshUser = "alexander";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.server;
      };
    };
  };
}
