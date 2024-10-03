{
  pkgs,
  ...
}: {
  imports = [
    ./global
    ./features/desktop/hyprland
    #./features/desktop/wireless
    ./features/rgb
    ./features/productivity
    ./features/pass
  ];

  # Green
  wallpaper = pkgs.wallpapers.aenami-northern-lights;
  colorscheme.type = "rainbow";


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