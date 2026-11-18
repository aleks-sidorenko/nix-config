{ lib, ... }:
{
  den.aspects.services.openvpn = {
    settings.connections = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            profileSecret = lib.mkOption {
              type = lib.types.str;
              description = "Name of the SOPS secret holding the whole .ovpn profile.";
            };
            autoStart = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Connect at boot rather than on demand.";
            };
          };
        }
      );
      default = { };
      description = "OpenVPN client connections, keyed by name.";
    };

    darwin =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (host.settings.services.openvpn) connections;
        labelOf = name: "${config.launchd.labelPrefix}.openvpn-${name}";
        launchctl = "/bin/launchctl";
        sudo = "/usr/bin/sudo";

        vpn = pkgs.writeShellApplication {
          name = "vpn";
          text = ''
            declare -A labels=(
              ${lib.concatMapStringsSep "\n  " (
                name: "[${lib.escapeShellArg name}]=${lib.escapeShellArg (labelOf name)}"
              ) (lib.attrNames connections)}
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
        environment.systemPackages = [ vpn ];

        sops.secrets = lib.mapAttrs' (_: conn: lib.nameValuePair conn.profileSecret { }) connections;

        launchd.daemons = lib.mapAttrs' (
          name: conn:
          lib.nameValuePair "openvpn-${name}" {
            serviceConfig = {
              ProgramArguments = [
                "${pkgs.openvpn}/sbin/openvpn"
                "--config"
                config.sops.secrets.${conn.profileSecret}.path
                # The host resolver (and tailnet DNS) must keep winning.
                "--pull-filter"
                "ignore"
                "dhcp-option DNS"
              ];
              RunAtLoad = conn.autoStart;
              # openvpn reconnects on its own; launchd restarting it would defeat `vpn down`.
              KeepAlive = false;
              StandardOutPath = "/var/log/openvpn-${name}.log";
              StandardErrorPath = "/var/log/openvpn-${name}.log";
            };
          }
        ) connections;
      };
  };
}
