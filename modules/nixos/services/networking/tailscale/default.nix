{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.networking.tailscale;
  sopsEnabled = config.${namespace}.security.sops.enable;
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
    authKeyFromSecret = mkOption {
      type = bool;
      default = false;
      description = "Point authKeyFile at the SOPS secret `system-tailscale-auth-key` (modules/nixos/secrets.yaml). Opt-in because the secret is not provisioned on every host; enabling it before the secret exists breaks activation.";
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
    # Opt-in: sops-nix fails activation if the secret is absent from
    # modules/nixos/secrets.yaml, so this must not be unconditional.
    ${namespace}.services.networking.tailscale.authKeyFile = mkIf cfg.authKeyFromSecret (
      mkDefault config.sops.secrets."system-tailscale-auth-key".path
    );

    sops.secrets."system-tailscale-auth-key" = mkIf (cfg.authKeyFromSecret && sopsEnabled) {
      sopsFile = ../../../secrets.yaml;
    };

    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile;
      # `--ssh` MUST go through extraSetFlags (drives tailscaled-set):
      # upstream applies extraUpFlags only via tailscaled-autoconnect, which
      # is gated on authKeyFile != null. Our always-on hosts join
      # interactively (no auth key), so routing it through extraUpFlags
      # would silently no-op.
      #
      # Tags are a registration-time property, not a runtime one: `tailscale
      # set` has no `--advertise-tags` (INVALIDARGUMENT), only `tailscale up`
      # does. So they can only ride extraUpFlags, and only take effect when
      # authKeyFile != null (a fresh OAuth-key registration, which Tailscale
      # requires tags on at `up` time). An already-joined host with no auth
      # key needs a manual `tailscale up --advertise-tags=...` re-auth to
      # pick up tags — nothing in activation can do it for them.
      extraUpFlags =
        cfg.extraUpFlags
        ++ optional (
          cfg.authKeyFile != null && cfg.tags != [ ]
        ) "--advertise-tags=${concatStringsSep "," cfg.tags}";
      extraSetFlags = optional cfg.ssh "--ssh";
      # OAuth client secrets used as auth keys require preauthorized=true
      # (https://tailscale.com/kb/1215/oauth-clients#registering-new-nodes-using-oauth-credentials);
      # a plain, already-approved auth key ignores the flag, so only setting
      # it when a key is present costs nothing.
      authKeyParameters = mkIf (cfg.authKeyFile != null) {
        preauthorized = true;
      };
    };
  };
}
