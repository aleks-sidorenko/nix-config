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
  cfg = config.${namespace}.services.networking.openvpn;

  # nix-darwin derives each daemon's label from launchd.labelPrefix, and the
  # wrapper needs the full label to address the job in launchd's system domain.
  daemonName = name: "openvpn-${name}";
  labelOf = name: "${config.launchd.labelPrefix}.${daemonName name}";

  # launchctl and sudo are macOS system binaries rather than Nix packages;
  # nix-darwin itself addresses launchctl by absolute path for the same reason.
  launchctl = "/bin/launchctl";
  sudo = "/usr/bin/sudo";

  vpn = pkgs.writeShellApplication {
    name = "vpn";
    text = ''
      declare -A labels=(
        ${concatMapStringsSep "\n  " (name: "[${escapeShellArg name}]=${escapeShellArg (labelOf name)}") (
          attrNames cfg.connections
        )}
      )

      usage() {
        printf 'usage: vpn up|down|status <connection>\nconnections: %s\n' "''${!labels[*]}" >&2
        exit 2
      }

      action=''${1:-}
      name=''${2:-}
      if [ -z "$action" ] || [ -z "$name" ]; then usage; fi

      label=''${labels[$name]:-}
      [ -n "$label" ] || usage

      case "$action" in
      up) ${sudo} ${launchctl} kickstart -k "system/$label" ;;
      down) ${sudo} ${launchctl} kill TERM "system/$label" ;;
      status) ${sudo} ${launchctl} print "system/$label" ;;
      *) usage ;;
      esac
    '';
  };
in
{
  options.${namespace}.services.networking.openvpn = with types; {
    enable = mkBoolOpt false "Whether to enable OpenVPN client connections";
    package = mkPackageOpt pkgs.openvpn "The openvpn package to use";
    connections = mkOpt (attrsOf (
      submodule openvpnConnection
    )) { } "OpenVPN client connections, keyed by name.";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.${namespace}.security.sops.enable;
        message = "${namespace}.services.networking.openvpn needs ${namespace}.security.sops: profiles are stored as SOPS secrets.";
      }
    ];

    environment.systemPackages = [ vpn ];

    # The whole profile is the secret (inlined <key>), so there is nothing
    # public to split out. sops-nix defaults these to root-owned 0400.
    sops.secrets = mapAttrs' (_: conn: nameValuePair conn.profileSecret { }) cfg.connections;

    launchd.daemons = mapAttrs' (
      name: conn:
      nameValuePair (daemonName name) {
        serviceConfig = {
          ProgramArguments = [
            "${cfg.package}/sbin/openvpn"
            "--config"
            config.sops.secrets.${conn.profileSecret}.path
          ]
          ++ openvpnExtraArgs conn;

          RunAtLoad = conn.autoStart;

          # Deliberately not KeepAlive: openvpn reconnects on its own (the
          # profiles carry resolv-retry infinite + persist-tun), and letting
          # launchd resurrect the job would make `vpn down` useless.
          KeepAlive = false;

          StandardOutPath = "/var/log/openvpn-${name}.log";
          StandardErrorPath = "/var/log/openvpn-${name}.log";
        };
      }
    ) cfg.connections;
  };
}
