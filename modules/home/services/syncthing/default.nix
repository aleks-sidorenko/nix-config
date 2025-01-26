{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.nix-config.syncthing;
in {
  options.services.nix-config.syncthing = {
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
