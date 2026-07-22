{ defaults }:
let
  ips = defaults.network.hosts;
in
{

  router = {
    ip = ips.router;
    mac = "08:55:31:E9:21:7A";
    bridge.mac = "08:55:31:E9:21:73";
    ovpn.mac = "FE:24:A6:AA:80:85";
    comment = "Router";
    dhcp = false;
    dns = true;
    aliases = [ "gateway" ];
  };

  cap1 = {
    ip = ips.cap1;
    mac = "DC:2C:6E:18:C7:69";
    comment = "cAP floor 1";
    dns = true;
    aliases = [ ];
  };
  cap2 = {
    ip = ips.cap2;
    mac = "DC:2C:6E:18:C0:AB";
    comment = "cAP floor 2";
    dns = true;
    aliases = [ ];
  };
  monitor = {
    ip = ips.monitor;
    mac = "00:12:17:DC:98:99";
    comment = "Monitor";
    dns = true;
    aliases = [ ];
  };
  ajax = {
    ip = ips.ajax;
    mac = "38:B8:EB:C2:54:53";
    comment = "Ajax";
    dns = true;
    aliases = [ ];
  };
  doorbell = {
    ip = ips.doorbell;
    mac = "3C:E3:6B:4B:21:94";
    comment = "Doorbell";
    dns = false;
    aliases = [ ];
  };
  server = {
    ip = ips.server;
    mac = "D8:3A:DD:D7:30:67";
    comment = "Server";
    dns = true;
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
    dns = true;
    aliases = [ ];
  };
  tv-wifi = {
    ip = ips.tv-wifi;
    mac = "04:39:26:B6:FB:6C";
    comment = "TV wifi";
    dns = false;
    aliases = [ ];
  };
  ps5 = {
    ip = ips.ps5;
    mac = "68:28:6C:7C:24:E9";
    comment = "PS5";
    dns = false;
    aliases = [ ];
  };
  inverter = {
    ip = ips.inverter;
    mac = "D4:27:87:27:B8:3E";
    comment = "Deye inverter";
    dns = true;
    aliases = [ ];
  };
  heatpump = {
    ip = ips.heatpump;
    mac = "EC:FA:BC:C2:EC:C6";
    comment = "Heatpump";
    dns = true;
    aliases = [ ];
  };
  homebook = {
    ip = ips.homebook;
    mac = "68:EC:C5:C2:36:1B";
    comment = "Ruslana, Dima, Windows";
    dns = false;
    aliases = [ ];
  };
  workbook = {
    ip = ips.workbook;
    mac = "A0:CE:C8:C1:23:A1";
    comment = "Work Macbook";
    dns = false;
    aliases = [ ];
  };
  desktop = {
    ip = ips.desktop;
    mac = "F4:6D:04:25:80:5F";
    comment = "Desktop";
    dns = false;
    aliases = [ ];
  };
  ipad = {
    ip = ips.ipad;
    # iOS private/per-network Wi-Fi MAC (randomization left on; stable for this
    # SSID). Hardware MAC is D2:DD:9C:EC:E6:E8 if randomization is ever disabled.
    mac = "0A:99:AE:77:3C:1B";
    comment = "iPad";
    dns = false;
    aliases = [ ];
  };
  "1c-key" = {
    ip = ips."1c-key";
    mac = "08:00:27:98:89:98";
    comment = "1C HASP Licence Manager";
    dns = false;
    aliases = [ ];
  };
}
