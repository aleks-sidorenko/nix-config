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
    authKeyFromSecret = mkOption {
      type = bool;
      default = false;
      description = "Point authKeyFile at the SOPS secret `system-tailscale-auth-key` (modules/darwin/secrets.yaml). Opt-in because the secret is not provisioned on every host; enabling it before the secret exists breaks activation.";
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
    # Opt-in: sops-nix fails activation if the secret is absent from
    # modules/darwin/secrets.yaml, so this must not be unconditional.
    ${namespace}.services.networking.tailscale.authKeyFile = mkIf cfg.authKeyFromSecret (
      mkDefault config.sops.secrets."system-tailscale-auth-key".path
    );

    sops.secrets."system-tailscale-auth-key" = mkIf (cfg.authKeyFromSecret && sopsEnabled) { };

    services.tailscale.enable = true;

    # nix-darwin's module runs tailscaled but never joins; the daemon has no
    # equivalent of the NixOS autoconnect unit, so activation joins once,
    # at activation, only when a key is supplied and the node is not already
    # up. Tags are a registration-time property — `tailscale set` has no
    # `--advertise-tags` (INVALIDARGUMENT) — so there is no activation-time
    # mechanism to apply them to an already-joined node; that needs a manual
    # `tailscale up --advertise-tags=...` re-auth by the operator.
    system.activationScripts.postActivation.text = concatStrings [
      (optionalString (cfg.authKeyFile != null) ''
        if ! ${tailscaleExe} status >/dev/null 2>&1; then
          printf >&2 'joining tailnet...\n'
          # activationScripts runs under `set -e`; tailscaled starts async via
          # RunAtLoad and may not be listening yet, so a transient failure here
          # must not abort the rest of activation. Surface it instead of hiding
          # it: silently swallowing would look identical to a bad auth key.
          #
          # `--auth-key file:<path>` can't take query params (they'd become
          # part of the path), so the key is read into the shell and
          # `?preauthorized=true` appended to the VALUE instead. An
          # OAuth-issued key requires it to register at all; a plain,
          # already-approved key ignores it. Tags must also ride along here:
          # OAuth registration needs them at `up` time, and this is the only
          # point they can ever be applied.
          ${tailscaleExe} up \
            --auth-key "$(cat ${cfg.authKeyFile})?preauthorized=true" \
            ${
              optionalString (cfg.tags != [ ]) "--advertise-tags=${concatStringsSep "," cfg.tags} "
            }${escapeShellArgs cfg.extraUpFlags} \
            || printf >&2 'tailscale join failed; run `tailscale up` by hand.\n'
        fi
      '')
    ];
  };
}
