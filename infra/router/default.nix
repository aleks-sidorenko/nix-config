{
  lib,
  pkgs,
  inputs,
  system,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  hosts = import ./hosts.nix { inherit defaults; };

  # Strip non-hostType attrs (bridge.mac, ovpn.mac) from router entry
  routerosHosts = hosts // {
    router = removeAttrs hosts.router [
      "bridge"
      "ovpn"
    ];
  };

  base = inputs.nix-routeros.lib.mkRouterDerivation {
    inherit pkgs system;
    modules = [
      ./imports.nix
      {
        routeros = {
          connection = {
            inherit (defaults.network) gateway;
            username = defaults.user;
          };

          system.timezone = defaults.locale.timeZone;

          network = {
            inherit (defaults.network) subnet;
            dhcp.server.range = defaults.network.dhcpRange;
          };

          bridge = {
            ports = [
              "ether2"
              "ether3"
              "ether4"
              "ether5"
              "ether6"
              "ether7"
              "ether8"
              "ether9"
              "ether10"
              "sfp1"
            ];
            adminMac = hosts.router.bridge.mac;
          };

          dns = {
            inherit (defaults.network.dns) upstream;
            localDomain = defaults.network.domains.local;
          };

          wifi = {
            enable = true;
            inherit (defaults.network.wifi) ssid;
            country = "ukraine";
          };

          interfaces.lte = {
            enable = true;
            apn = "ks";
            provider = "Kyivstar";
          };

          firewall = {
            addressLists.banned = [
              defaults.network.hosts.tv
              defaults.network.hosts.tv-wifi
              defaults.network.hosts.homebook
              defaults.network.hosts.ipad
            ];
            filterRules = [
              {
                name = "forward_drop_banned_external";
                action = "drop";
                chain = "forward";
                comment = "drop banned hosts external traffic";
                out_interface_list = "WAN";
                src_address_list = "banned";
              }
            ];
          };

          hosts = routerosHosts;
        };
      }
    ];
    stateDir = "infra/router";
    secretsFile = "infra/router/secrets.yaml";
    secrets = {
      TF_VAR_routeros_password = "router-api-password";
      TF_VAR_wifi_password = "wifi-password";
      TF_VAR_state_passphrase = "state-passphrase";
    };
  };

  # SSH-based backup script
  sshAlias = "router";
  configDir = "\${XDG_CONFIG_HOME:-$HOME/.config}/mikrotik";

  backup = pkgs.writeShellScriptBin "backup" ''
    set -euo pipefail

    ROUTER="${sshAlias}"
    BACKUP_DIR="${configDir}"

    usage() {
      echo "Usage: router-backup [OPTIONS]"
      echo ""
      echo "Create a backup of the MikroTik router and download it"
      echo ""
      echo "Options:"
      echo "  -o, --output DIR  Backup directory (default: \$XDG_CONFIG_HOME/mikrotik)"
      echo "  -h, --help        Show this help"
      exit 0
    }

    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) BACKUP_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done

    mkdir -p "$BACKUP_DIR"

    BACKUP_NAME="nix-$(date +%Y%m%d-%H%M%S)"

    echo "Creating backup on router..."
    ssh "$ROUTER" "/system backup save name=$BACKUP_NAME" || {
      echo "Error: Backup failed"
      exit 1
    }

    echo "Downloading backup to $BACKUP_DIR/$BACKUP_NAME.backup..."
    scp "$ROUTER:/$BACKUP_NAME.backup" "$BACKUP_DIR/$BACKUP_NAME.backup" || {
      echo "Error: Failed to download backup file"
      exit 1
    }

    echo "Backup saved to: $BACKUP_DIR/$BACKUP_NAME.backup"
  '';
in
base // { inherit backup; }
