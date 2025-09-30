{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.networking.tailscale;
in
{
  options.${namespace}.services.networking.tailscale = {
    enable = mkEnableOption "Enable tailscale";
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;
  };
}
