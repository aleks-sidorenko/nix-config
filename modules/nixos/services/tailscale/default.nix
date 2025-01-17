{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.nix-config.tailscale;
in {
  options.services.nix-config.tailscale = {
    enable = mkEnableOption "Enable tailscale";
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;
  };
}
