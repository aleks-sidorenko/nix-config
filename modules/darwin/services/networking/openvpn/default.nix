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

  daemonName = name: "openvpn-${name}";
  labelOf = name: "${config.launchd.labelPrefix}.${daemonName name}";

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

          # openvpn reconnects on its own; launchd restarting it would defeat `vpn down`.
          KeepAlive = false;

          StandardOutPath = "/var/log/openvpn-${name}.log";
          StandardErrorPath = "/var/log/openvpn-${name}.log";
        };
      }
    ) cfg.connections;
  };
}
