{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.games.minecraft;

in
{
  options.${namespace}.games.minecraft = {
    enable = mkEnableOption "Enable or disable Minecraft";

    desktopId =
      mkOpt types.str "org.prismlauncher.PrismLauncher"
        "Desktop file id (without .desktop) of the launcher this module installs. Consumed by launcher allow-lists.";
  };

  config = mkIf cfg.enable {

    home = {
      packages = with pkgs; [
        prismlauncher
      ];
    };
  };

}
