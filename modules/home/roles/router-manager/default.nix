{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.router-manager;
  ips = defaults.network.hosts;
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.networking.router = {
      enable = true;

      hosts = {
        cap1 = {
          ip = ips.cap1;
          mac = "DC:2C:6E:18:C7:69";
          dns = false;
          comment = "cAP floor 1";
        };
        cap2 = {
          ip = ips.cap2;
          mac = "DC:2C:6E:18:C0:AB";
          dns = false;
          comment = "cAP floor 2";
        };
        monitor = {
          ip = ips.monitor;
          mac = "00:12:17:DC:98:99";
          comment = "Monitor";
        };
        ajax = {
          ip = ips.ajax;
          mac = "38:B8:EB:C2:54:53";
          comment = "Ajax";
        };
        doorbell = {
          ip = ips.doorbell;
          mac = "3C:E3:6B:4B:21:94";
          comment = "Doorbell, doesn't use DHCP";
          dns = false;
        };
        server = {
          ip = ips.server;
          mac = "D8:3A:DD:D7:30:67";
          aliases = [
            "radarr"
            "jellyfin"
            "qbittorrent"
            "prowlarr"
            "minidlna"
            "sonarr"
            "home-assistant"
            "zigbee2mqtt"
            "minecraft"
            "restic"
          ];
        };
        tv = {
          ip = ips.tv;
          mac = "0C:CA:FB:0B:47:EE";
          comment = "TV lan";
        };
        tv-wifi = {
          ip = ips.tv-wifi;
          mac = "04:39:26:B6:FB:6C";
          comment = "TV wifi";
          dns = false;
        };
        inverter = {
          ip = ips.inverter;
          mac = "D4:27:87:27:B8:3E";
          comment = "Deye inverter";
        };
        heatpump = {
          ip = ips.heatpump;
          mac = "EC:FA:BC:C2:EC:C6";
          comment = "Heatpump";
        };
      };

      firewallAddressLists = {
        tv = [
          "${ips.tv}/32"
          "${ips.tv-wifi}/32"
        ];
      };
    };
  };
}
