{
  roles = {
    desktop.enable = true;
    gaming.enable = true;
  };

  nix-config.user = {
    enable = true;
    name = "haseeb";
  };

  home.stateVersion = "23.11";
}
