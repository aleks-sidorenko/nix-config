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
  options.${namespace}.services.networking.tailscale = with types; {
    enable = mkEnableOption "Enable tailscale";
    ssh = mkEnableOption "Bring the node up with Tailscale SSH (--ssh), ACL-gated";
    authKeyFile = mkOption {
      type = nullOr str;
      default = null;
      description = "Path to a file with a Tailscale auth key for non-interactive first-boot join (e.g. a SOPS secret path). Null on hosts already joined.";
    };
    extraUpFlags = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra flags for `tailscale up` (escape hatch, e.g. --advertise-exit-node).";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
      extraUpFlags = optional cfg.ssh "--ssh" ++ cfg.extraUpFlags;
    };
  };
}
