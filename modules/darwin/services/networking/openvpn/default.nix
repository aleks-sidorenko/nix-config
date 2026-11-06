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
  logOf = name: "/var/log/openvpn-${name}.log";

  # Covers openvpn's default 60s TLS handshake window.
  upTimeout = 90;

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
      declare -A logs=(
        ${concatMapStringsSep "\n  " (name: "[${escapeShellArg name}]=${escapeShellArg (logOf name)}") (
          attrNames cfg.connections
        )}
      )

      log_size() {
        if [ -f "$1" ]; then wc -c <"$1"; else echo 0; fi
      }

      # kickstart returns immediately and openvpn retries forever, so follow the
      # log to turn the outcome into an exit status.
      wait_up() {
        local log=$1 offset=$2 new failure
        for _ in $(seq ${toString upTimeout}); do
          new=$(tail -c +"$((offset + 1))" "$log" 2>/dev/null || true)
          if grep -q 'Initialization Sequence Completed' <<<"$new"; then
            echo "vpn: $name connected"
            return 0
          fi
          if failure=$(grep -m1 -E 'TLS Error|AUTH_FAILED|Exiting due to fatal error|Options error' <<<"$new"); then
            printf 'vpn: %s failed: %s\n' "$name" "$failure" >&2
            return 1
          fi
          sleep 1
        done
        printf 'vpn: %s not connected after %ss\n' "$name" ${toString upTimeout} >&2
        return 1
      }

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
      up)
        log=''${logs[$name]}
        offset=$(log_size "$log")
        ${sudo} ${launchctl} kickstart -k "system/$label"
        if ! wait_up "$log" "$offset"; then
          ${sudo} ${launchctl} kill TERM "system/$label"
          printf 'log: %s\n' "$log" >&2
          exit 1
        fi
        ;;
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

          StandardOutPath = logOf name;
          StandardErrorPath = logOf name;
        };
      }
    ) cfg.connections;
  };
}
