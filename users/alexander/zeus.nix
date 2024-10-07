{
  pkgs,
  nix-colors,
  ...
}: {
  imports = [
    ./global
    ./optional/desktop/hyprland
    ./optional/rgb
    ./optional/pass

     nix-colors.homeManagerModules.default
  ];

  wallpaper = pkgs.wallpapers.aenami-top-of-the-world;
  colorScheme = nix-colors.colorSchemes.dracula;


  #  -----   ------
  # | DVI-I-1 | | HDMI-A-1 |
  #  -----   ------
  monitors = [
    {
      name = "DVI-I-1";
      width = 1920;
      height = 1080;
      workspace = "1";
      primary = true;
    }
    {
      name = "HDMI-A-1";
      width = 1920;
      height = 1080;
      position = "auto-right";
      workspace = "2";
    }
  ];
}