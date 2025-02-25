{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.apps.tuis;
in {
  options.${namespace}.apps.tuis = {
    enable = mkEnableOption "Enable TUI applications";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
    with pkgs.nix-config; [
      # s-tui
      # lazysql
    ];
  };
}
