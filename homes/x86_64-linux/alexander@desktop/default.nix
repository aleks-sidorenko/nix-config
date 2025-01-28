{pkgs, namespace,...}: {
  # FIXME
  cli.programs.git.allowedSigners = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINP5gqbEEj+pykK58djSI1vtMtFiaYcygqhHd3mzPbSt hello@haseebmajid.dev";

  networking.hostName = "desktop";

  desktops = {
    hyprland = {
      enable = true;
      execOnceExtras = [
        "${pkgs.trayscale}/bin/trayscale"
      ];
    };
  };

  services.${namespace} = {
    syncthing.enable = true;
  };

  roles = {
    desktop.enable = true;
    social.enable = true;    
    video.enable = true;
  };

  ${namespace}.user = {
    enable = true;
    name = "alexander";
  };


  home.stateVersion = "24.11";
}
