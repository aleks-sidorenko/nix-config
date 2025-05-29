{
  inputs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.hyprland;
in
{
  # TODO - refactor desktops, have common with shared addons and move hyprland specific addons to hyprland module
  imports = lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.desktops.hyprland = with types; {
    enable = mkEnableOption "enable hyprland window manager";
    execOnceExtras = mkOpt (listOf str) [ ] "Extra programs to exec once";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      desktops = {
        addons = {
          kanshi.enable = true;
          rofi.enable = true;
          swaync.enable = true;
          waybar.enable = true;
          wlogout.enable = true;
          wlsunset.enable = true;
        };
        hyprland.addons = {
          pyprland.enable = true;
          hyprpaper.enable = true;
          hyprlock.enable = true;
          hypridle.enable = true;
        };
      };
    };
    nix.settings = {
      trusted-substituters = [ "https://hyprland.cachix.org" ];
      trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    };
  };
}
