{
  inputs,
  lib,
  host,
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

  };

  config = mkIf cfg.enable {

    home = {
      packages = with pkgs; [
        prismlauncher
      ];
    };
  };

}
