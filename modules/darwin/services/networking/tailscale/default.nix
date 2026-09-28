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
    # equivalent of the NixOS autoconnect unit. Two independent contributions
    # (concatenated, since `text` is `types.lines`):
    #  - join once, at activation, only when a key is supplied and the node
    #    is not already up.
    #  - advertise tags on every activation, regardless of how the host
    #    joined: the join block above only fires when authKeyFile is set, so
    #    hosts that joined interactively (the normal case here) would never
    #    render it, and changing tags via `tailscale up` forces re-auth on a
    #    live session anyway. `tailscale set` mutates an already-running node
    #    without either problem.
    system.activationScripts.postActivation.text = concatStrings [
      (optionalString (cfg.authKeyFile != null) ''
        if ! ${tailscaleExe} status >/dev/null 2>&1; then
          printf >&2 'joining tailnet...\n'
          # activationScripts runs under `set -e`; tailscaled starts async via
          # RunAtLoad and may not be listening yet, so a transient failure here
          # must not abort the rest of activation. Surface it instead of hiding
          # it: silently swallowing would look identical to a bad auth key.
          ${tailscaleExe} up \
            --auth-key "file:${cfg.authKeyFile}" \
            ${escapeShellArgs cfg.extraUpFlags} \
            || printf >&2 'tailscale join failed; run `tailscale up` by hand.\n'
        fi
      '')
      (optionalString (cfg.tags != [ ]) ''
        # Only act on an already-up node: before the first join (or while
        # tailscaled is still starting) this is a silent no-op, not an error.
        if ${tailscaleExe} status >/dev/null 2>&1; then
          ${tailscaleExe} set --advertise-tags=${concatStringsSep "," cfg.tags} \
            || printf >&2 'tailscale set --advertise-tags failed; run by hand.\n'
        fi
      '')
    ];
  };
}
