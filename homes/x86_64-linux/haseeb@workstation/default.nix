{pkgs, ...}: {
  cli.programs.git.allowedSigners = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINP5gqbEEj+pykK58djSI1vtMtFiaYcygqhHd3mzPbSt hello@haseebmajid.dev";

  desktops = {
    hyprland = {
      enable = true;
      execOnceExtras = [
        "${pkgs.trayscale}/bin/trayscale"
      ];
    };
  };

  services.nix-config = {
    syncthing.enable = true;
  };

  roles = {
    desktop.enable = true;
    social.enable = true;
    gaming.enable = true;
    gamedev.enable = true;
    video.enable = true;
  };

  nix-config.user = {
    enable = true;
    name = "haseeb";
  };

  home.stateVersion = "23.11";
}
