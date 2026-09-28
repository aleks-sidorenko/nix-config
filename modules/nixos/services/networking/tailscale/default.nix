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
      description = "Extra flags for `tailscale up` (escape hatch, e.g. --advertise-exit-node). NOTE: upstream applies these only when authKeyFile is set; for flags that must apply without an auth key, prefer `tailscale set`.";
    };
    tags = mkOption {
      type = listOf str;
      default = [ ];
      description = "ACL tags this host advertises, contributed by the roles it enables.";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile extraUpFlags;
      # `--ssh` and `--advertise-tags` MUST go through extraSetFlags (drives
      # tailscaled-set): upstream applies extraUpFlags only via
      # tailscaled-autoconnect, which is gated on authKeyFile != null. Our
      # always-on hosts join interactively (no auth key), so routing either
      # flag through extraUpFlags would silently no-op.
      extraSetFlags =
        optional cfg.ssh "--ssh"
        ++ optional (cfg.tags != [ ]) "--advertise-tags=${concatStringsSep "," cfg.tags}";
    };
  };
}
