{
  pkgs,
  lib,
  options,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.hardware.logitechMouse;
in {
  options.${namespace}.hardware.logitechMouse = with types; {
    enable = mkBoolOpt false "Enable logitech mouse hardware for their mice";
  };

  config = mkIf cfg.enable {
    hardware = {
      logitech.wireless.enable = true;
      logitech.wireless.enableGraphical = true; # Solaar.
    };

    environment.systemPackages = with pkgs; [
      solaar
    ];

    services.udev.packages = with pkgs; [
      logitech-udev-rules
      solaar
    ];
  };
}
