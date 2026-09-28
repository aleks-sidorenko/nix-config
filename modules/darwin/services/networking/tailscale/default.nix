{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.services.networking.tailscale;

  # Reference the package nix-darwin actually runs, not a hardcoded path:
  # /run/current-system/sw/bin only exists via environment.systemPackages,
  # and tracking cfg.package keeps this correct if that's ever overridden.
  tailscaleExe = lib.getExe' config.services.tailscale.package "tailscale";
in
{
  options.${namespace}.services.networking.tailscale = with types; {
    enable = mkEnableOption "Enable tailscale";
    authKeyFile = mkOption {
      type = nullOr str;
      default = null;
      description = "Path to a file with a Tailscale auth key for non-interactive first-boot join. Null on hosts already joined.";
    };
    extraUpFlags = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra flags for `tailscale up` (escape hatch, e.g. --advertise-exit-node). Note: the activation join only runs when authKeyFile is set, so these flags have no effect unless authKeyFile is configured.";
    };
    tags = mkOption {
      type = listOf str;
      default = [ ];
      description = "ACL tags this host advertises, contributed by the roles it enables.";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;

    # nix-darwin's module runs tailscaled but never joins; the daemon has no
    # equivalent of the NixOS autoconnect unit. Join once, at activation, only
    # when a key is supplied and the node is not already up.
    system.activationScripts.postActivation.text = mkIf (cfg.authKeyFile != null) ''
      if ! ${tailscaleExe} status >/dev/null 2>&1; then
        printf >&2 'joining tailnet...\n'
        # activationScripts runs under `set -e`; tailscaled starts async via
        # RunAtLoad and may not be listening yet, so a transient failure here
        # must not abort the rest of activation. Surface it instead of hiding
        # it: silently swallowing would look identical to a bad auth key.
        ${tailscaleExe} up \
          --auth-key "file:${cfg.authKeyFile}" \
          ${optionalString (cfg.tags != [ ]) "--advertise-tags=${concatStringsSep "," cfg.tags}"} \
          ${escapeShellArgs cfg.extraUpFlags} \
          || printf >&2 'tailscale join failed; run `tailscale up` by hand.\n'
      fi
    '';
  };
}
