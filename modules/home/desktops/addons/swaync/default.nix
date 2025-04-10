{
  config,
  lib,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.desktops.addons.swaync;
in {
  options.${namespace}.desktops.addons.swaync = {
    enable = mkEnableOption "Enable sway notification center";
  };

  config = mkIf cfg.enable {
    services.swaync = {
      enable = true;
      settings = {};
      style = builtins.readFile ./swaync.css;
    };
  };
}
