{
  roles = {
    social.enable = true;
  };

  nix-config.user = {
    enable = true;
    name = "deck";
  };

  home.stateVersion = "23.11";
}
