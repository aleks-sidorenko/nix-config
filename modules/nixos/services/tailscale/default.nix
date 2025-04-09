{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.${namespace}.tailscale;
in {
  options.services.${namespace}.tailscale = {
    enable = mkEnableOption "Enable tailscale";
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;
  };
}
