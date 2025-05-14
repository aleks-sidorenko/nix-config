{
  inputs,
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.video;
in
{
  options.${namespace}.roles.video = with types; {
    enable = mkBoolOpt false "Whether or not to manage video editting and recording";
  };

  config = mkIf cfg.enable {
    xdg.configFile."obs-studio/themes".source = "${inputs.catppuccin-obs}/themes";

    programs.obs-studio = {
      enable = true;
    };

    home.packages = with pkgs; [
      audacity
      kdePackages.kdenlive
    ];
  };
}
