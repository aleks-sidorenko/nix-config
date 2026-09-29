{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.networking;
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    knownNetworkServices = mkOpt (listOf str) [ "Wi-Fi" ] "List of macOS network services to configure";
    domains = {
      lan = mkOpt str defaults.network.domains.lan "LAN domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      inherit (cfg) knownNetworkServices;

      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      search = [
        defaults.network.domains.tailnet
        cfg.domains.lan
      ];
    };

    # nix-darwin cannot manage /etc/hosts via environment.etc (symlink) because
    # macOS ships a real /etc/hosts and the resolver expects a regular file
    # (nix-darwin#1035). Docker Desktop, VPN/EDR clients and hand-added entries
    # also write this file, so it is not ours to own; the block below is a
    # one-time migration removing the block an earlier revision of this module
    # rendered, not ongoing management, and self-disables once that block is gone.
    system.activationScripts.postActivation.text = ''
      if [ -r /etc/hosts ] && grep -q '^# Local network hosts (managed by nix-config' /etc/hosts; then
        printf >&2 'removing stale nix-config /etc/hosts entries...\n'
        tmp="$(mktemp /etc/hosts.XXXXXX)"
        # Drop the marker and the contiguous run of registry entries under it,
        # then stop. Deleting through end-of-file would take whatever another
        # writer appended after the block, which is where appends land.
        ${pkgs.gawk}/bin/awk '
          /^# Local network hosts \(managed by nix-config/ { skip = 1; next }
          skip && /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[ \t]/ { next }
          { skip = 0; print }
        ' /etc/hosts > "$tmp"
        chmod 0644 "$tmp"
        mv "$tmp" /etc/hosts
      fi
    '';
  };
}
