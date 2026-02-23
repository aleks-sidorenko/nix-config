{
  lib,
  pkgs,
  system,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  routerConfig = {
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
      adminMac = "08:55:31:E9:21:73";
    };

    lte = {
      apn = "ks";
      name = "Kyivstar";
    };

    ovpn = {
      macAddress = "FE:24:A6:AA:80:85";
    };

    # System
    timezone = defaults.locale.timeZone;

    # Hosts
    hosts = import ./hosts.nix { inherit defaults; };

    # Firewall address lists
    firewallAddressLists = {
      tv = [
        "${defaults.network.hosts.tv}/32"
        "${defaults.network.hosts.tv-wifi}/32"
      ];
    };
  };

  base = mkTerranixDerivation {
    inherit pkgs system;
    extraArgs = {
      inherit routerConfig;
    };
    terraformModulesPath = ../../modules/terraform/routeros;
    modules = [ ];
    stateDir = toString ./.;
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
