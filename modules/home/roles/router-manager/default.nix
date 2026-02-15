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
in
{
  options.${namespace}.roles.router-manager = {
    enable = mkEnableOption "Enable router manager configuration";

    # Connection
    sshAlias = mkStringOpt "router" "SSH config alias";

    # Network
    subnet = mkStringOpt defaults.network.subnet "Network subnet (CIDR)";
    gateway = mkStringOpt defaults.network.gateway "Gateway IP";
    dhcpRange = mkStringOpt defaults.network.dhcpRange "DHCP pool range";

    # WiFi
    wifi = {
      ssid = mkStringOpt defaults.network.wifi.ssid "WiFi SSID";
    };

    # DNS
    dns = {
      upstream = mkOpt (types.listOf types.str) defaults.network.dns.upstream "Upstream DNS servers";
    };

    # Hardware
    bridge = {
      adminMac = mkStringOpt "08:55:31:E9:21:73" "Bridge admin MAC address";
    };

    lte = {
      apn = mkStringOpt "ks" "LTE APN";
      name = mkStringOpt "Kyivstar" "LTE provider name";
    };

    ovpn = {
      macAddress = mkStringOpt "FE:24:A6:AA:80:85" "OpenVPN server MAC address";
    };

    # System
    timezone = mkStringOpt defaults.locale.timeZone "Router timezone";

    # Network hosts
    hosts = mkOpt (types.attrsOf
      config.${namespace}.system.networking.router.options.hosts.type.nestedTypes.elemType
    ) { } "Network hosts - generates DHCP leases and DNS records";

    # Firewall
    firewallAddressLists = mkOpt (types.attrsOf (
      types.listOf types.str
    )) { } "Firewall address lists (e.g. { TV = [ \"10.0.0.50/32\" ]; })";

    # Extra
    extraSections = mkOpt types.attrs { } "Additional RouterOS sections";
  };

  config = mkIf cfg.enable {
    ${namespace}.system.networking.router = {
      enable = true;
      sshAlias = cfg.sshAlias;
      subnet = cfg.subnet;
      gateway = cfg.gateway;
      dhcpRange = cfg.dhcpRange;
      wifi.ssid = cfg.wifi.ssid;
      dns.upstream = cfg.dns.upstream;
      bridge.adminMac = cfg.bridge.adminMac;
      lte = {
        apn = cfg.lte.apn;
        name = cfg.lte.name;
      };
      ovpn.macAddress = cfg.ovpn.macAddress;
      timezone = cfg.timezone;
      hosts = cfg.hosts;
      firewallAddressLists = cfg.firewallAddressLists;
      extraSections = cfg.extraSections;
    };
  };
}
