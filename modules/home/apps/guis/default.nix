{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.apps.guis;
in
{
  options.${namespace}.apps.guis = {
    enable = mkEnableOption "Enable gnome adwaita GUI applications";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [

      foliate

      sushi
      totem
      gvfs
      loupe

      ffmpegthumbnailer # thumbnails
      gst_all_1.gst-libav # thumbnails
      keymapp

    ];

    xdg.configFile."com.github.johnfactotum.Foliate/themes/mocha.json".text = ''
      {
          "label": "Mocha",
          "light": {
          	"fg": "#999999",
          	"bg": "#cccccc",
          	"link": "#666666"
          },
          "dark": {
          	"fg": "#cdd6f4",
          	"bg": "#1e1e2e",
          	"link": "#E0DCF5"
          }
      }
    '';
  };
}
