{
  config,
  lib,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.services.syncthing;
in {
  options.${namespace}.services.syncthing = {
    enable = mkEnableOption "Enable syncthing service";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      tray.enable = true;
      extraOptions = ["--gui-address=127.0.0.1:8384"];
    };
  };
}
