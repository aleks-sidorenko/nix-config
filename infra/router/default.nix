{
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  system = pkgs.stdenv.hostPlatform.system;
  hosts = import ./hosts.nix { inherit defaults; };

  routerConfig = {
    # User
    username = defaults.user;

    # Network (from lib/defaults)
    subnet = defaults.network.subnet;
    gateway = defaults.network.gateway;
    dhcpRange = defaults.network.dhcpRange;
    networkAddress = lib.${namespace}.networkAddress defaults.network.gateway;
    prefixLength = lib.${namespace}.prefixLength defaults.network.subnet;
    localDomain = defaults.network.domains.local;

    # WiFi
    wifi = {
      ssid = defaults.network.wifi.ssid;
    };

    # DNS
    dns = {
      upstream = defaults.network.dns.upstream;
    };

    # Hardware
    bridge = {
      adminMac = hosts.router.bridge.mac;
    };

    lte = {
      apn = "ks";
      name = "Kyivstar";
    };

    ovpn = {
      macAddress = hosts.router.ovpn.mac;
    };

    # System
    timezone = defaults.locale.timeZone;

    # Hosts
    inherit hosts;

    # Firewall address lists
    firewallAddressLists = {
      tv = [
        defaults.network.hosts.tv
        defaults.network.hosts.tv-wifi
      ];
    };
  };

  base = mkTerranixDerivation {
    inherit pkgs system;
    name = "router";
    extraArgs = {
      inherit routerConfig;
    };
    terraformModulesPath = ./modules;
    modules = [ ];
    stateDir = "infra/router";
    secretsFile = "infra/router/secrets.yaml";
    secrets = {
      TF_VAR_routeros_password = "router-api-password";
      TF_VAR_wifi_password = "wifi-password";
      TF_VAR_state_passphrase = "state-passphrase";
    };
  };

  # SSH-based backup script (preserved from old module)
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
